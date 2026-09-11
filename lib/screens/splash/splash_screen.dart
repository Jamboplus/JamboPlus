import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
import 'package:jamboplus/providers/app_config_provider.dart';
import 'package:jamboplus/screens/app_gate.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _minSplash = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmupAndGo();
    });
  }

  Future<void> _warmupAndGo() async {
    // Prefetch while the splash animates so AppGate rarely blocks.
    final warmup = ref.read(remoteContentProvider.future);
    await Future.wait<void>([
      Future<void>.delayed(_minSplash),
      warmup.then<void>((_) {}, onError: (_) {}),
    ]);
    if (!mounted) return;
    _goHome();
  }

  void _goHome() {
    if (!mounted) return;
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const AppGate(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).shortestSide;
    final iconSize = (size * 0.42).clamp(148.0, 220.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Image.asset(
          'assets/icon/app_icon.png',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        )
            .animate()
            .fadeIn(duration: 500.ms, curve: Curves.easeOut)
            .scale(
              begin: const Offset(0.88, 0.88),
              end: const Offset(1, 1),
              duration: 700.ms,
              curve: Curves.easeOutBack,
            ),
      ),
    );
  }
}
