import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/register_platform_plugins.dart';
import 'package:jamboplus/core/constants/app_constants.dart';
import 'package:jamboplus/core/theme/app_theme.dart';
import 'package:jamboplus/screens/splash/splash_screen.dart';
import 'package:jamboplus/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerPlatformPlugins();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF00040C),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // FCM after first frame so splash is not blocked; safe on desktop (no-op).
  // ignore: unawaited_futures
  PushNotificationService.initialize();
  runApp(const ProviderScope(child: JamboPlusApp()));
}

class JamboPlusApp extends StatelessWidget {
  const JamboPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}
