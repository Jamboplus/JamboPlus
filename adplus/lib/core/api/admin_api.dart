import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/admin_api_config.dart';
import '../../models/admin_models.dart';

const _tokenKey = 'jamboad_admin_token_v2';

class AdminApi {
  AdminApi()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AdminApiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Accept': 'application/json'},
          ),
        ) {
    // ignore: avoid_print
    print('JamboAd API → ${AdminApiConfig.baseUrl}');
  }

  final Dio _dio;
  String? _token;
  String? adminEmail;

  String get baseUrl => AdminApiConfig.baseUrl;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      // Drop legacy tokens from older local/dev servers
      await prefs.remove('jamboad_admin_token');
    } catch (_) {
      _token = null;
    }
  }

  Future<void> saveToken(String token) async {
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (_) {}
  }

  Future<void> clearToken() async {
    _token = null;
    adminEmail = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove('jamboad_admin_token');
    } catch (_) {}
  }

  Options get _auth => Options(
        headers: _token != null ? {'Authorization': 'Bearer $_token'} : null,
      );

  Never _throw(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (status == 401) {
      final serverMsg =
          data is Map ? data['error']?.toString().toLowerCase() ?? '' : '';
      if (serverMsg.contains('credential')) {
        throw ApiException(
          'Barua pepe au nenosiri si sahihi',
          statusCode: 401,
        );
      }
      throw ApiException('Session imeisha. Ingia tena.', statusCode: 401);
    }

    if (data is Map && data['error'] != null) {
      throw ApiException(data['error'].toString(), statusCode: status);
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ApiException(
        'Haijaweza kuunganishwa na server. Jaribu tena.',
        statusCode: null,
      );
    }

    throw ApiException('Hitilafu ya mtandao', statusCode: status);
  }

  Future<T> _wrap<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    return _wrap(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/admin/login',
        data: {'email': email, 'password': password},
      );
      final data = res.data!;
      await saveToken(data['token'] as String);
      final admin = data['admin'] as Map<String, dynamic>?;
      adminEmail = admin?['email'] as String? ?? email;
      return data;
    });
  }

  Future<Map<String, dynamic>> dashboard() async {
    return _wrap(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/admin/dashboard',
        options: _auth,
      );
      return res.data!;
    });
  }

  Future<List<dynamic>> listUsers() async {
    return _wrap(() async {
      final res = await _dio.get<List<dynamic>>('/v1/admin/users', options: _auth);
      return res.data ?? [];
    });
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> body) async {
    return _wrap(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/admin/users',
        data: body,
        options: _auth,
      );
      return res.data!;
    });
  }

  Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> body) async {
    return _wrap(() async {
      final res = await _dio.put<Map<String, dynamic>>(
        '/v1/admin/users/$id',
        data: body,
        options: _auth,
      );
      return res.data!;
    });
  }

  Future<void> deleteUser(String id) async {
    return _wrap(() async {
      await _dio.delete('/v1/admin/users/$id', options: _auth);
    });
  }

  Future<int> deleteAllUsers() async {
    return _wrap(() async {
      final res = await _dio.delete<Map<String, dynamic>>(
        '/v1/admin/users',
        options: _auth,
      );
      return (res.data?['deleted'] as num?)?.toInt() ?? 0;
    });
  }

  Future<List<dynamic>> listChannels() async {
    return _wrap(() async {
      final res = await _dio.get<List<dynamic>>('/v1/admin/channels', options: _auth);
      return res.data ?? [];
    });
  }

  Future<Map<String, dynamic>> createChannel(Map<String, dynamic> body) async {
    return _wrap(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/admin/channels',
        data: body,
        options: _auth,
      );
      return res.data!;
    });
  }

  Future<Map<String, dynamic>> updateChannel(String id, Map<String, dynamic> body) async {
    return _wrap(() async {
      final res = await _dio.put<Map<String, dynamic>>(
        '/v1/admin/channels/$id',
        data: body,
        options: _auth,
      );
      return res.data!;
    });
  }

  Future<void> deleteChannel(String id) async {
    return _wrap(() async {
      await _dio.delete('/v1/admin/channels/$id', options: _auth);
    });
  }

  Future<List<dynamic>> listCarousel() async {
    return _wrap(() async {
      final res = await _dio.get<List<dynamic>>('/v1/admin/carousel', options: _auth);
      return res.data ?? [];
    });
  }

  Future<Map<String, dynamic>> createCarousel(Map<String, dynamic> body) async {
    return _wrap(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/admin/carousel',
        data: body,
        options: _auth,
      );
      return res.data!;
    });
  }

  Future<Map<String, dynamic>> updateCarousel(String id, Map<String, dynamic> body) async {
    return _wrap(() async {
      final res = await _dio.put<Map<String, dynamic>>(
        '/v1/admin/carousel/$id',
        data: body,
        options: _auth,
      );
      return res.data!;
    });
  }

  Future<void> deleteCarousel(String id) async {
    return _wrap(() async {
      await _dio.delete('/v1/admin/carousel/$id', options: _auth);
    });
  }

  Future<List<dynamic>> listPricing() async {
    return _wrap(() async {
      final res = await _dio.get<List<dynamic>>('/v1/admin/pricing', options: _auth);
      return res.data ?? [];
    });
  }

  Future<Map<String, dynamic>> createPricing(Map<String, dynamic> body) async {
    return _wrap(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/admin/pricing',
        data: body,
        options: _auth,
      );
      return res.data!;
    });
  }

  Future<Map<String, dynamic>> updatePricing(String id, Map<String, dynamic> body) async {
    return _wrap(() async {
      final res = await _dio.put<Map<String, dynamic>>(
        '/v1/admin/pricing/$id',
        data: body,
        options: _auth,
      );
      return res.data!;
    });
  }

  Future<void> deletePricing(String id) async {
    return _wrap(() async {
      await _dio.delete('/v1/admin/pricing/$id', options: _auth);
    });
  }

  Future<Map<String, dynamic>> getAppConfig() async {
    return _wrap(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/admin/app-config',
        options: _auth,
      );
      return res.data!;
    });
  }

  Future<Map<String, dynamic>> updateAppConfig(Map<String, dynamic> body) async {
    return _wrap(() async {
      final res = await _dio.put<Map<String, dynamic>>(
        '/v1/admin/app-config',
        data: body,
        options: _auth,
      );
      return res.data!;
    });
  }
}
