import 'dart:convert';

import 'package:jamboplus/core/constants/app_constants.dart';
import 'package:jamboplus/models/app_config_model.dart';
import 'package:jamboplus/models/channel_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Support / WhatsApp helpers.
///
/// Prefers bootstrap `app_config` fields. Falls back to the hidden system
/// channel (`system-msaada-whatsapp`) so admin updates work even before the
/// production API has WhatsApp columns deployed.
abstract final class SupportContact {
  static const systemChannelId = 'system-msaada-whatsapp';
  static const systemCategory = '__system__';

  static bool isSystemMeta(ChannelModel channel) =>
      channel.id == systemChannelId || channel.category == systemCategory;

  static String whatsappNumber(
    AppConfigModel? config, {
    List<ChannelModel> channels = const [],
  }) {
    final fromServer =
        (config?.whatsappNumber ?? '').replaceAll(RegExp(r'\D'), '');
    if (fromServer.length >= 9) return _normalizeWa(fromServer);

    final meta = _metaFromChannels(channels);
    final fromMeta = (meta?['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
    if (fromMeta.length >= 9) return _normalizeWa(fromMeta);

    final fromName = (metaChannel(channels)?.name ?? '').replaceAll(RegExp(r'\D'), '');
    if (fromName.length >= 9) return _normalizeWa(fromName);

    return _normalizeWa(AppConstants.whatsappNumber);
  }

  static String whatsappMessage(
    AppConfigModel? config, {
    List<ChannelModel> channels = const [],
  }) {
    final fromServer = (config?.whatsappMessage ?? '').trim();
    if (fromServer.isNotEmpty) return fromServer;
    final meta = _metaFromChannels(channels);
    final fromMeta = (meta?['message'] as String? ?? '').trim();
    if (fromMeta.isNotEmpty) return fromMeta;
    return AppConstants.whatsappMessage;
  }

  static String supportHours(
    AppConfigModel? config, {
    List<ChannelModel> channels = const [],
  }) {
    final fromServer = (config?.supportHours ?? '').trim();
    if (fromServer.isNotEmpty) return fromServer;
    final meta = _metaFromChannels(channels);
    final fromMeta = (meta?['hours'] as String? ?? '').trim();
    if (fromMeta.isNotEmpty) return fromMeta;
    return AppConstants.supportHours;
  }

  static String displayPhone(
    AppConfigModel? config, {
    List<ChannelModel> channels = const [],
  }) {
    final digits = whatsappNumber(config, channels: channels);
    if (digits.startsWith('255') && digits.length >= 12) {
      return '0${digits.substring(3)}';
    }
    return digits;
  }

  static Future<bool> openWhatsApp(
    AppConfigModel? config, {
    List<ChannelModel> channels = const [],
  }) async {
    final uri = Uri.parse(
      'https://wa.me/${whatsappNumber(config, channels: channels)}'
      '?text=${Uri.encodeComponent(whatsappMessage(config, channels: channels))}',
    );
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static ChannelModel? metaChannel(List<ChannelModel> channels) {
    for (final c in channels) {
      if (c.id == systemChannelId) return c;
    }
    for (final c in channels) {
      if (c.category == systemCategory) return c;
    }
    return null;
  }

  /// Payload stored in the system channel description.
  static String encodeMeta({
    required String phone,
    required String message,
    required String hours,
  }) {
    return jsonEncode({
      'v': 1,
      'phone': phone,
      'message': message,
      'hours': hours,
    });
  }

  static Map<String, dynamic>? _metaFromChannels(List<ChannelModel> channels) {
    final channel = metaChannel(channels);
    if (channel == null) return null;
    final raw = channel.description.trim();
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static String _normalizeWa(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0') && d.length == 10) return '255${d.substring(1)}';
    return d;
  }
}
