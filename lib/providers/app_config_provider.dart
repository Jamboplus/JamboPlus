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
  final deviceId = await storage.getOrCreateDeviceId();
  final fcmToken = await PushNotificationService.currentToken();
  try {
    await api.sendDeviceHeartbeat(
      deviceId: deviceId,
      fcmToken: fcmToken,
      platform: defaultTargetPlatform.name,
      appVersion: AppConstants.appVersion,
    );
  } catch (_) {
    // Offline — admin list updates on next open.
  }

  await ref.read(userProvider.notifier).syncFromServer();
  final user = ref.read(userProvider);
  // ignore: unawaited_futures
  PushNotificationService.syncAudienceTopics(
    isPremium: user.hasActiveSubscription,
  );
});

/// Invalidate everything the user app shows from admin.
void invalidateRemoteContent(WidgetRef ref) {
  ref.invalidate(bootstrapProvider);
  ref.invalidate(channelsProvider);
  ref.invalidate(carouselProvider);
  ref.invalidate(pricingProvider);
  ref.invalidate(remoteContentProvider);
}
