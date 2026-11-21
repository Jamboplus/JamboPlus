import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jamboplus/player/gateway_stream_extractor.dart';
import 'package:jamboplus/player/playback_http_headers.dart';

/// Resolves PHP/embed gateway pages (Sokamax-style) into a direct DASH/HLS stream.
/// Mirrors Washa [GatewayEmbedResolver]: warm embed page → player.php?api=1 → MPD + DRM.
class EmbedApiResolved {
  const EmbedApiResolved({
    required this.streamUrl,
    required this.streamType,
    required this.licenseUrl,
    required this.headers,
    this.authToken = '',
  });

  final String streamUrl;
  final String streamType;
  final String licenseUrl;
  final String authToken;
  final Map<String, String> headers;
}

class EmbedApiResolver {
  EmbedApiResolver._();

  static const _package = playbackAppPackageMarker;
  static const _cacheTtl = Duration(seconds: 60);
  static final Map<String, ({EmbedApiResolved value, DateTime at})> _cache = {};
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: true,
      validateStatus: (code) => code != null && code < 500,
    ),
  );

  static bool isEmbedApiPlayer(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    if (path.contains('embed.php') || path.contains('player.php')) {
      return (uri.queryParameters['app'] ?? '').trim().isNotEmpty &&
          (uri.queryParameters['key'] ?? '').trim().isNotEmpty;
    }
    return false;
  }

  static bool isGatewayUrl(String rawUrl) {
    if (isEmbedApiPlayer(rawUrl)) return true;
    return isGatewayPlaybackUrl(rawUrl);
  }

  static Future<EmbedApiResolved?> resolve(
    String rawUrl, {
    String packageName = playbackAppPackageMarker,
  }) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return null;

    final cached = _cache[url];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.value;
    }

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final resolved = await _resolveOnce(url, packageName);
        if (resolved != null) {
          _cache[url] = (value: resolved, at: DateTime.now());
          return resolved;
        }
      } catch (e) {
        lastError = e;
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
    }
    debugPrint('EmbedApiResolver failed: $lastError');
    return null;
  }

  static Future<EmbedApiResolved?> _resolveOnce(
    String url,
    String packageName,
  ) async {
    final headers = Map<String, String>.from(mergePlaybackHeaders(url));
    headers['X-Requested-With'] = packageName;

    // Warm cookies / app gate on the embed page (same as Washa).
    final pageResp = await _dio.get<String>(
      url,
      options: Options(
        headers: headers,
        responseType: ResponseType.plain,
      ),
    );
    final pageHtml = pageResp.data ?? '';
    if (pageHtml.contains('App Haijatambuliwa')) {
      debugPrint('EmbedApiResolver: app not recognized');
      return null;
    }

    // Encrypted PHP HTML fields (XOR) — Washa gateway_stream_extractor.
    final extracted = GatewayStreamExtractor.extract(pageHtml);
    if (extracted != null && extracted.streamUrl.startsWith('http')) {
      return _fromExtracted(extracted, url);
    }

    final apiUrl = _findApiUrl(url, pageHtml);
    if (apiUrl == null) return null;

    final apiHeaders = Map<String, String>.from(headers)
      ..['Accept'] = 'application/json'
      ..['X-Requested-With'] = packageName;

    final apiResp = await _dio.get<dynamic>(
      apiUrl,
      options: Options(
        headers: apiHeaders,
        responseType: ResponseType.json,
      ),
    );
    final data = apiResp.data is Map
        ? Map<String, dynamic>.from(apiResp.data as Map)
        : (apiResp.data is String
            ? Map<String, dynamic>.from(jsonDecode(apiResp.data as String) as Map)
            : null);
    if (data == null) return null;

    final mpdPath = (data['mpdPath'] as String?)?.trim().isNotEmpty == true
        ? (data['mpdPath'] as String).trim()
        : ((data['streamUrl'] as String?)?.trim().isNotEmpty == true
            ? (data['streamUrl'] as String).trim()
            : ((data['url'] as String?)?.trim() ?? ''));
    if (mpdPath.isEmpty || !mpdPath.startsWith('http')) {
      if (data['success'] == false) {
        debugPrint('EmbedApiResolver api error=${data['error'] ?? data['message']}');
      }
      return null;
    }

    final licenseUrl = (data['licenseUrl'] as String?)?.trim() ?? '';
    final authToken = ((data['authXmlToken'] as String?)?.trim().isNotEmpty == true
            ? (data['authXmlToken'] as String).trim()
            : ((data['authToken'] as String?)?.trim() ?? ''));

    final originUri = Uri.parse(url);
    final origin = '${originUri.scheme}://${originUri.authority}';
    final outHeaders = <String, String>{
      'User-Agent': playbackChromeUserAgent,
      'Referer': '$origin/',
      'Origin': origin,
      'X-Requested-With': packageName,
    };
    if (authToken.isNotEmpty) {
      outHeaders['nv-authorizations'] = authToken;
    }

    return EmbedApiResolved(
      streamUrl: mpdPath,
      streamType: mpdPath.toLowerCase().contains('.mpd') ? 'DASH' : 'HLS',
      licenseUrl: licenseUrl,
      authToken: authToken,
      headers: outHeaders,
    );
  }

  static EmbedApiResolved _fromExtracted(GatewayExtracted extracted, String gatewayUrl) {
    final originUri = Uri.parse(gatewayUrl);
    final origin = '${originUri.scheme}://${originUri.authority}';
    final headers = <String, String>{
      'User-Agent': playbackChromeUserAgent,
      'Referer': '$origin/',
      'Origin': origin,
      'X-Requested-With': _package,
    };
    if (extracted.authToken.isNotEmpty) {
      headers['nv-authorizations'] = extracted.authToken;
    }
    return EmbedApiResolved(
      streamUrl: extracted.streamUrl,
      streamType: extracted.isHls ? 'HLS' : 'DASH',
      licenseUrl: extracted.licenseUrl,
      authToken: extracted.authToken,
      headers: headers,
    );
  }

  static String? _findApiUrl(String gatewayUrl, String html) {
    final inline = RegExp(
      r'''API_URL\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html)?.group(1)?.trim();
    if (inline != null && inline.isNotEmpty) {
      return _absolutize(gatewayUrl, _unescape(inline));
    }

    final base = Uri.parse(gatewayUrl);
    final path = base.path.toLowerCase();
    if (path.contains('embed.php') || path.contains('player.php')) {
      final app = base.queryParameters['app'] ?? '';
      final key = base.queryParameters['key'] ?? '';
      if (app.isNotEmpty && key.isNotEmpty) {
        final playerPath = base.path.replaceFirst(
          RegExp(r'embed\.php', caseSensitive: false),
          'player.php',
        );
        return base.replace(
          path: playerPath,
          queryParameters: {
            'app': app,
            'key': key,
            'api': '1',
            't': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        ).toString();
      }
    }

    final href = RegExp(
      r'''(?:href|src)=["']([^"']*player\.php\?[^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html)?.group(1)?.trim();
    if (href != null && href.isNotEmpty) {
      final abs = _absolutize(gatewayUrl, href);
      if (abs.contains('api=')) return abs;
      final u = Uri.parse(abs);
      return u.replace(
        queryParameters: {
          ...u.queryParameters,
          'api': '1',
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ).toString();
    }
    return null;
  }

  static String _unescape(String raw) =>
      raw.replaceAll(r'\u0026', '&').replaceAll(r'\/', '/');

  static String _absolutize(String baseUrl, String maybeRelative) {
    final t = maybeRelative.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    final base = Uri.parse(baseUrl);
    if (t.startsWith('/')) return '${base.scheme}://${base.authority}$t';
    final parent = base.path.contains('/')
        ? base.path.substring(0, base.path.lastIndexOf('/'))
        : '';
    return '${base.scheme}://${base.authority}$parent/$t';
  }
}
