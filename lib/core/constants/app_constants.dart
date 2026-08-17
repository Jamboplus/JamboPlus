import 'package:jamboplus/core/constants/api_config.dart';

abstract final class AppConstants {
  static const appName = 'JamboPlus';
  static const appVersion = '1.0.2';
  static const whatsappNumber = '255712345678';
  static const whatsappMessage = 'Habari, ninahitaji msaada kutoka JamboPlus.';

  static const supportHours = 'Jumatatu - Jumapili: 08:00 - 22:00';
  static const supportInfo =
      'Timu yetu iko tayari kukusaidia kuhusu usajili, malipo na matatizo ya kutazama chaneli.';

  static String get apiBaseUrl => ApiConfig.baseUrl;

  /// Must match `app_config.app_api_secret` on the server.
  /// Override with `--dart-define=JAMBO_APP_SECRET=...` when rotating secrets.
  static const appApiSecret = String.fromEnvironment(
    'JAMBO_APP_SECRET',
    defaultValue: '4171c2b5b245db2214a79136496e224447a5514aea09ea4ff5f6b6af3c79235f',
  );

  static const carouselAutoPlayInterval = Duration(seconds: 3);
  static const animationDuration = Duration(milliseconds: 300);
  static const carouselHeight = 430.0;
}
