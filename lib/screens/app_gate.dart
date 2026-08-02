import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/constants/app_constants.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
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
        '${AppConstants.apiBaseUrl}\n\n'
        'Angalia mtandao wako, kisha jaribu tena.';
  }
  if (text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('SocketException')) {
    return 'Haijaweza kuunganishwa na seva.\n\n'
        '${AppConstants.apiBaseUrl}';
  }
  if (text.contains('401') ||
      text.contains('Invalid signature') ||
      text.contains('Missing X-Jambo')) {
    return 'Imeshindwa kuthibitisha programu.\n\n'
        'Wasiliana na admin au jaribu tena.';
  }
  return 'Imeshindwa kupakia maudhui kutoka seva.\n\n'
      '${AppConstants.apiBaseUrl}';
}

/// Loads all signed content from JamboAd before showing the main app.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.watch(remoteContentProvider);
    final bootstrap = ref.watch(bootstrapProvider);

    return remote.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
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
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => invalidateRemoteContent(ref),
                  child: const Text('Jaribu tena'),
                ),
              ],
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
