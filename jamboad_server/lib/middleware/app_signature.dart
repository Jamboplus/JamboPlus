import 'package:shelf/shelf.dart';

import '../db/database.dart';
import '../util/hmac.dart';
import '../util/http.dart';

const _maxSkewSeconds = 300;

typedef AppHandler = Future<Response> Function(Request request);

Middleware appSignature(AppDatabase db) {
  return (Handler inner) {
    return (Request request) async {
      final timestamp = request.headers['X-Jambo-Timestamp'] ??
          request.headers['x-jambo-timestamp'];
      final signature = request.headers['X-Jambo-Signature'] ??
          request.headers['x-jambo-signature'];

      if (timestamp == null || signature == null) {
        return errorResponse(401, 'Missing X-Jambo-Timestamp or X-Jambo-Signature');
      }

      final secret = _appApiSecret(db);
      if (secret.isEmpty) {
        return errorResponse(503, 'App API not configured');
      }

      final tsSeconds = int.tryParse(timestamp);
      if (tsSeconds == null) {
        return errorResponse(401, 'Invalid timestamp');
      }
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if ((now - tsSeconds).abs() > _maxSkewSeconds) {
        return errorResponse(401, 'Timestamp expired');
      }

      final method = request.method.toUpperCase();
      final path = request.requestedUri.path;
      final payload = '$timestamp$method$path';
      final expected = hmacSha256Hex(secret, payload);

      if (!_constantTimeEquals(expected.toLowerCase(), signature.toLowerCase())) {
        return errorResponse(401, 'Invalid signature');
      }

      return inner(request);
    };
  };
}

Handler withAppAuth(AppDatabase db, AppHandler handler) {
  return appSignature(db)(handler);
}

String _appApiSecret(AppDatabase db) {
  final rows = db.raw.select('SELECT app_api_secret FROM app_config WHERE id = 1');
  if (rows.isEmpty) return '';
  return rows.first['app_api_secret'] as String? ?? '';
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

Map<String, dynamic> loadAppConfigRow(AppDatabase db) {
  final rows = db.raw.select('SELECT * FROM app_config WHERE id = 1');
  if (rows.isEmpty) {
    throw StateError('app_config missing');
  }
  return Map<String, dynamic>.from(rows.first);
}

Map<String, dynamic> appConfigForBootstrap(Map<String, dynamic> row) {
  return {
    'playerEngine': row['player_engine'],
    'drmType': row['drm_type'],
    'streamOrigin': row['stream_origin'],
    'streamReferer': row['stream_referer'],
    'userAgent': row['user_agent'],
    'tokenRefreshUrl': row['token_refresh_url'],
    'streamUserId': row['stream_user_id'],
    'appApiKey': row['app_api_key'],
    'maintenanceMode': (row['maintenance_mode'] as int) == 1,
  };
}

Map<String, dynamic> appConfigForAdmin(Map<String, dynamic> row) {
  return {
    'playerEngine': row['player_engine'],
    'drmType': row['drm_type'],
    'streamOrigin': row['stream_origin'],
    'streamReferer': row['stream_referer'],
    'userAgent': row['user_agent'],
    'tokenRefreshUrl': row['token_refresh_url'],
    'streamUserId': row['stream_user_id'],
    'appApiKey': row['app_api_key'],
    'appApiSecret': row['app_api_secret'],
    'maintenanceMode': (row['maintenance_mode'] as int) == 1,
  };
}
