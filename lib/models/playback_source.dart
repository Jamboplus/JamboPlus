import 'package:flutter/material.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
import 'package:jamboplus/models/channel_model.dart';

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
  });

  factory PlaybackSource.fromChannel(ChannelModel c) => PlaybackSource(
        title: c.name,
        subtitle: c.description.isNotEmpty ? c.description : c.category,
        gradient: const [AppColors.primaryIndigo, AppColors.primaryCyan],
        isChannel: true,
        channelId: c.id,
        imageUrl: c.image,
        url: c.streamUrl,
        drm: channelDrmFromString(c.drmType),
        clearKey: c.drmClearKey,
      );
}
