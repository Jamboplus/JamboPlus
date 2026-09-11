import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/constants/app_constants.dart';
import 'package:jamboplus/models/app_config_model.dart';
import 'package:jamboplus/models/pricing_model.dart';
import 'package:jamboplus/providers/carousel_provider.dart';
import 'package:jamboplus/providers/channel_provider.dart';
import 'package:jamboplus/providers/service_providers.dart';
import 'package:jamboplus/providers/user_provider.dart';
import 'package:jamboplus/services/push_notification_service.dart';

final bootstrapProvider = FutureProvider<BootstrapModel>((ref) async {
  return ref.read(apiServiceProvider).fetchBootstrap();
});

final appConfigProvider = Provider<AppConfigModel?>((ref) {
  return ref.watch(bootstrapProvider).valueOrNull?.config;
});

final pricingProvider = FutureProvider<List<PricingPlanModel>>((ref) async {
  return ref.read(apiServiceProvider).fetchPricing();
});

/// Preloads channels, carousel, pricing, player config, and syncs subscription.
final remoteContentProvider = FutureProvider<void>((ref) async {
  await Future.wait([
    ref.watch(bootstrapProvider.future),
    ref.watch(channelsProvider.future),
    ref.watch(carouselProvider.future),
    ref.watch(pricingProvider.future),
  ]);

  final storage = ref.read(storageServiceProvider);
  final api = ref.read(apiServiceProvider);
  final idAndToken = await Future.wait<String?>([
    storage.getOrCreateDeviceId(),
    PushNotificationService.currentToken(),
  ]);
  final deviceId = idAndToken[0]!;
  final fcmToken = idAndToken[1];
  try {
    final heartbeatUser = await api.sendDeviceHeartbeat(
      deviceId: deviceId,
      fcmToken: fcmToken,
      platform: defaultTargetPlatform.name,
      appVersion: AppConstants.appVersion,
    );
    await ref.read(userProvider.notifier).seedFromDevice(heartbeatUser);
  } catch (_) {
    // Offline — keep cache; still try a light subscription sync.
    await ref.read(userProvider.notifier).syncFromServer();
  }

  final user = ref.read(userProvider);
  // ignore: unawaited_futures
  PushNotificationService.syncAudienceTopics(
    isPremium: user.hasActiveSubscription,
  );
});

/// Hard invalidate used by the gate retry button (may remount shell).
void invalidateRemoteContent(WidgetRef ref) {
  ref.invalidate(bootstrapProvider);
  ref.invalidate(rawChannelsProvider);
  ref.invalidate(channelsProvider);
  ref.invalidate(carouselProvider);
  ref.invalidate(pricingProvider);
  ref.invalidate(remoteContentProvider);
}

/// Soft refresh: refetch content + subscription without tearing down MainShell.
Future<void> softRefreshRemoteContent(WidgetRef ref) async {
  ref.invalidate(bootstrapProvider);
  ref.invalidate(rawChannelsProvider);
  ref.invalidate(channelsProvider);
  ref.invalidate(carouselProvider);
  ref.invalidate(pricingProvider);

  await Future.wait([
    ref.read(bootstrapProvider.future),
    ref.read(channelsProvider.future),
    ref.read(carouselProvider.future),
    ref.read(pricingProvider.future),
    ref.read(userProvider.notifier).refresh(),
  ]);
}
