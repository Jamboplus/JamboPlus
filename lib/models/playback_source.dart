import 'package:flutter/material.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
import 'package:jamboplus/models/app_config_model.dart';
import 'package:jamboplus/models/channel_model.dart';
import 'package:jamboplus/player/embed_api_resolver.dart';
import 'package:jamboplus/player/playback_http_headers.dart';

/// DRM protection applied to a channel stream.
enum ChannelDrm { none, widevine, clearkey }

ChannelDrm channelDrmFromString(String? value) {
  final v = (value ?? 'none').trim().toLowerCase();
  return switch (v) {
    'widevine' => ChannelDrm.widevine,
    'clearkey' || 'clear_key' => ChannelDrm.clearkey,
    _ => ChannelDrm.none,
  };
}

/// What is currently loaded into the player.
class PlaybackSource {
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final bool isChannel;
  final String? channelId;
  final String? imageUrl;
  final String url;
  final ChannelDrm drm;
  final String clearKey;
  final String licenseUrl;
  final Map<String, String> headers;

  const PlaybackSource({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.isChannel,
    this.channelId,
    this.imageUrl,
    this.url = '',
    this.drm = ChannelDrm.none,
    this.clearKey = '',
    this.licenseUrl = '',
    this.headers = const {},
  });

  PlaybackSource copyWith({
    String? title,
    String? subtitle,
    List<Color>? gradient,
    bool? isChannel,
    String? channelId,
    String? imageUrl,
    String? url,
    ChannelDrm? drm,
    String? clearKey,
    String? licenseUrl,
    Map<String, String>? headers,
  }) {
    return PlaybackSource(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      gradient: gradient ?? this.gradient,
      isChannel: isChannel ?? this.isChannel,
      channelId: channelId ?? this.channelId,
      imageUrl: imageUrl ?? this.imageUrl,
      url: url ?? this.url,
      drm: drm ?? this.drm,
      clearKey: clearKey ?? this.clearKey,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      headers: headers ?? this.headers,
    );
  }

  factory PlaybackSource.fromChannel(ChannelModel c, {AppConfigModel? config}) {
    final fromApi = <String, String>{};
    final origin = config?.streamOrigin.trim() ?? '';
    final referer = config?.streamReferer.trim() ?? '';
    final userAgent = config?.userAgent.trim() ?? '';
    if (origin.isNotEmpty) fromApi['Origin'] = origin;
    if (referer.isNotEmpty) fromApi['Referer'] = referer;
    if (userAgent.isNotEmpty) fromApi['User-Agent'] = userAgent;
    return PlaybackSource(
      title: c.name,
      subtitle: c.description.isNotEmpty ? c.description : c.category,
      gradient: const [AppColors.primaryIndigo, AppColors.primaryCyan],
      isChannel: true,
      channelId: c.id,
      imageUrl: c.image,
      url: c.streamUrl,
      drm: channelDrmFromString(c.drmType),
      clearKey: c.drmClearKey,
      licenseUrl: c.drmLicenseUrl,
      headers: mergePlaybackHeaders(c.streamUrl, fromApi.isEmpty ? null : fromApi),
    );
  }
}

/// Resolves gateway/embed URLs the same way Washa does (page warm + API + DRM).
/// On Android the native player also resolves; this helps Flutter/WebView fallback.
Future<PlaybackSource> preparePlaybackSource(PlaybackSource source) async {
  if (!EmbedApiResolver.isGatewayUrl(source.url)) return source;
  final resolved = await EmbedApiResolver.resolve(source.url);
  if (resolved == null) return source;
  final merged = <String, String>{
    ...source.headers,
    ...resolved.headers,
  };
  return source.copyWith(
    url: resolved.streamUrl,
    licenseUrl:
        resolved.licenseUrl.isNotEmpty ? resolved.licenseUrl : source.licenseUrl,
    drm: resolved.licenseUrl.isNotEmpty ? ChannelDrm.widevine : source.drm,
    headers: mergePlaybackHeaders(resolved.streamUrl, merged),
  );
}
