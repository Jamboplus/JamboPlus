import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jamboplus/core/constants/app_constants.dart';
import 'package:jamboplus/models/app_config_model.dart';
import 'package:jamboplus/models/carousel_model.dart';
import 'package:jamboplus/models/channel_model.dart';
import 'package:jamboplus/models/pricing_model.dart';
import 'package:jamboplus/models/user_model.dart';
import 'package:jamboplus/services/jambo_hmac.dart';

/// Signed client for public app endpoints (`/v1/app/*`).
/// All content is managed in JamboAd and served from Railway.
class ApiService {
  ApiService({Dio? dio, String? appSecret})
      : _secret = appSecret ?? AppConstants.appApiSecret,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.apiBaseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
                headers: {'Accept': 'application/json'},
              ),
            ) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('JamboPlus API → ${AppConstants.apiBaseUrl}');
    }
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Sign the exact path Railway will see (no query string).
          final path = _signedPath(options);
          final ts = jamboTimestampSeconds();
          final sig = jamboAppSignature(
            secret: _secret,
            timestampSeconds: ts,
            method: options.method,
            path: path,
          );
          options.headers['X-Jambo-Timestamp'] = ts.toString();
          options.headers['X-Jambo-Signature'] = sig;
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final String _secret;

  static String _signedPath(RequestOptions options) {
    final raw = options.path;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Uri.parse(raw).path;
    }
    final basePath = Uri.parse(options.baseUrl).path;
    final requestPath = raw.startsWith('/') ? raw : '/$raw';
    if (basePath.isEmpty || basePath == '/') return requestPath;
    final normalizedBase =
        basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath;
    return '$normalizedBase$requestPath';
  }

  Future<BootstrapModel> fetchBootstrap() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/app/bootstrap');
    return BootstrapModel.fromJson(response.data!);
  }

  Future<List<CarouselModel>> fetchCarousel() async {
    final response = await _dio.get<List<dynamic>>('/v1/app/carousel');
    final list = response.data ?? [];
    return list
        .map((e) => CarouselModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChannelModel>> fetchChannels() async {
    final response = await _dio.get<List<dynamic>>('/v1/app/channels');
    final list = response.data ?? [];
    return list
        .map((e) => ChannelModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PricingPlanModel>> fetchPricing() async {
    final response = await _dio.get<List<dynamic>>('/v1/app/pricing');
    final list = response.data ?? [];
    return list
        .map((e) => PricingPlanModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Register / refresh profile. Does not grant premium (admin controls that).
  Future<UserModel> registerUser({
    required String name,
    required String phone,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/app/users/register',
      data: {'name': name.trim(), 'phone': phone.trim()},
    );
    return UserModel.fromJson(response.data!);
  }

  /// Fetch subscription status by phone. Returns null if not found.
  Future<UserModel?> fetchUserByPhone(String phone) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/app/users/me',
        queryParameters: {'phone': phone.trim()},
      );
      return UserModel.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Start SonicPesa Push USSD for a pricing plan.
  Future<Map<String, dynamic>> startPayment({
    required String name,
    required String phone,
    required String planId,
    int? amount,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/app/payments/start',
      data: {
        'name': name.trim(),
        'phone': phone.trim(),
        'planId': planId,
        if (amount != null) 'amount': amount,
      },
    );
    return response.data ?? {};
  }

  /// Poll SonicPesa order until paid / failed / still pending.
  Future<Map<String, dynamic>> checkPaymentStatus(String orderId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/app/payments/status',
      queryParameters: {'orderId': orderId},
    );
    return response.data ?? {};
  }
}
