import 'package:shelf/shelf.dart';

import '../db/database.dart';
import '../middleware/app_signature.dart';
import '../util/http.dart';
import '../util/serializers.dart';

Future<Response> appBootstrapHandler(Request request, AppDatabase db) async {
  final row = loadAppConfigRow(db);
  return jsonResponse({
    'config': appConfigForBootstrap(row),
    'maintenanceMode': (row['maintenance_mode'] as int) == 1,
  });
}

Future<Response> appChannelsHandler(Request request, AppDatabase db) async {
  final rows = db.raw.select(
    '''
    SELECT * FROM channels
    WHERE enabled = 1
    ORDER BY sort_order ASC, name ASC
    ''',
  );
  return jsonResponse(rows.map(channelToAppJson).toList());
}

Future<Response> appCarouselHandler(Request request, AppDatabase db) async {
  final rows = db.raw.select(
    '''
    SELECT * FROM carousel
    WHERE enabled = 1
    ORDER BY sort_order ASC
    ''',
  );
  return jsonResponse(rows.map(carouselToAppJson).toList());
}

Future<Response> appPricingHandler(Request request, AppDatabase db) async {
  final rows = db.raw.select(
    '''
    SELECT * FROM pricing
    WHERE enabled = 1
    ORDER BY sort_order ASC
    ''',
  );
  return jsonResponse(rows.map(pricingToAppJson).toList());
}

Future<Response> healthHandler(Request request) async {
  return jsonResponse({'status': 'ok', 'service': 'jamboad_server'});
}
