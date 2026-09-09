import 'package:jamboplus/core/constants/app_constants.dart';
import 'package:jamboplus/models/app_config_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Support / WhatsApp helpers driven by admin bootstrap config.
abstract final class SupportContact {
  static String whatsappNumber(AppConfigModel? config) {
    final fromServer = (config?.whatsappNumber ?? '').replaceAll(RegExp(r'\D'), '');
    if (fromServer.length >= 9) return _normalizeWa(fromServer);
    return _normalizeWa(AppConstants.whatsappNumber);
  }

  static String whatsappMessage(AppConfigModel? config) {
    final fromServer = (config?.whatsappMessage ?? '').trim();
    if (fromServer.isNotEmpty) return fromServer;
    return AppConstants.whatsappMessage;
  }

  static String supportHours(AppConfigModel? config) {
    final fromServer = (config?.supportHours ?? '').trim();
    if (fromServer.isNotEmpty) return fromServer;
    return AppConstants.supportHours;
  }

  static String displayPhone(AppConfigModel? config) {
    final digits = whatsappNumber(config);
    if (digits.startsWith('255') && digits.length >= 12) {
      return '0${digits.substring(3)}';
    }
    return digits;
  }

  static Future<bool> openWhatsApp(AppConfigModel? config) async {
    final uri = Uri.parse(
      'https://wa.me/${whatsappNumber(config)}'
      '?text=${Uri.encodeComponent(whatsappMessage(config))}',
    );
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static String _normalizeWa(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0') && d.length == 10) return '255${d.substring(1)}';
    return d;
  }
}
