import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jamboplus/models/playback_source.dart';
import 'package:jamboplus/player/embed_api_resolver.dart';

/// Opens the Washa full-screen player (native landscape activity) on Android.
class NativeWashaPlayer {
  NativeWashaPlayer._();

  static const _channel = MethodChannel('com.jamboplus/washa_player');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> open(PlaybackSource source) async {
    if (!supported) return;
    final originalUrl = source.url.trim();
    final prepared = await preparePlaybackSource(source);
    // If Flutter already resolved embed→MPD, keep the original gateway URL
    // so native can WebView-failover like Washa when Exo fails.
    final fallbackJson = (prepared.url != originalUrl && originalUrl.isNotEmpty)
        ? jsonEncode([
            {'url': originalUrl},
          ])
        : '';
    await _channel.invokeMethod<void>('open', <String, dynamic>{
      'url': prepared.url,
      'channelName': prepared.title,
      'licenseUrl': prepared.licenseUrl,
      'drmType': _drmLabel(prepared.drm),
      'clearKeyHex': prepared.clearKey,
      'drmClearKey': prepared.clearKey,
      'headersJson':
          prepared.headers.isEmpty ? '' : jsonEncode(prepared.headers),
      'audioLanguage': 'sw',
      'defaultQuality': '360p',
      'videoZoomMode': 'contain',
      'fallbackStreamsJson': fallbackJson,
    });
  }

  static String _drmLabel(ChannelDrm drm) {
    return switch (drm) {
      ChannelDrm.clearkey => 'CLEARKEY',
      ChannelDrm.widevine => 'WIDEVINE',
      ChannelDrm.none => 'NONE',
    };
  }
}
