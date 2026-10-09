import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/constants/app_constants.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
import 'package:jamboplus/core/theme/app_theme.dart';
import 'package:jamboplus/providers/app_config_provider.dart';
import 'package:jamboplus/screens/main_shell.dart';
import 'package:jamboplus/screens/maintenance/maintenance_screen.dart';

String _gateErrorMessage(Object error) {
  final text = error.toString();
  if (error is DioException &&
      (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout)) {
    return 'Haijaweza kuunganishwa na seva.\n\n'
        'Inajaribu tena kiotomatiki…\n'
        'Angalia mtandao wako.';
  }
  if (text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('SocketException')) {
    return 'Haijaweza kuunganishwa na seva.\n\n'
        'Inajaribu tena kiotomatiki…';
  }
  if (text.contains('401') ||
      text.contains('Invalid signature') ||
      text.contains('Missing X-Jambo')) {
    return 'Imeshindwa kuthibitisha programu.\n\n'
        'Wasiliana na admin au jaribu tena.';
  }
  return 'Imeshindwa kupakia maudhui kutoka seva.\n\n'
      'Inajaribu tena…';
}

/// Loads all signed content from JamboAd before showing the main app.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> {
  Timer? _autoRetry;
  int _autoAttempts = 0;

  @override
  void dispose() {
    _autoRetry?.cancel();
    super.dispose();
  }

  void _scheduleAutoRetry() {
    if (_autoAttempts >= 4) return;
    if (_autoRetry?.isActive ?? false) return;
    _autoRetry = Timer(Duration(seconds: 2 + _autoAttempts), () {
      if (!mounted) return;
      _autoAttempts += 1;
      invalidateRemoteContent(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(remoteContentProvider, (prev, next) {
      next.when(
        data: (_) {
          _autoRetry?.cancel();
          _autoAttempts = 0;
        },
        error: (_, _) => _scheduleAutoRetry(),
        loading: () {},
      );
    });

    final remote = ref.watch(remoteContentProvider);
    final bootstrap = ref.watch(bootstrapProvider);

    return remote.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    _gateErrorMessage(e),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppConstants.apiBaseUrl,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      _autoRetry?.cancel();
                      _autoAttempts = 0;
                      invalidateRemoteContent(ref);
                    },
                    child: const Text('Jaribu tena'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      data: (_) {
        final b = bootstrap.valueOrNull;
        if (b != null && b.maintenanceMode) {
          return const MaintenanceScreen();
        }
        return const MainShell();
      },
    );
  }
}
