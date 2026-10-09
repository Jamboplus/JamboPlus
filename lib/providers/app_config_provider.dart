import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/models/app_config_model.dart';
import 'package:jamboplus/models/pricing_model.dart';
import 'package:jamboplus/providers/cache_first.dart';
import 'package:jamboplus/providers/carousel_provider.dart';
import 'package:jamboplus/providers/channel_provider.dart';
import 'package:jamboplus/providers/service_providers.dart';
import 'package:jamboplus/providers/user_provider.dart';

final bootstrapProvider = FutureProvider<BootstrapModel>((ref) async {
  final api = ref.read(apiServiceProvider);
  final storage = ref.read(storageServiceProvider);
  return cacheFirstThenRefresh<BootstrapModel>(
    ref: ref,
    loadCache: storage.loadBootstrapCache,
    fetchRemote: api.fetchBootstrap,
    saveCache: storage.saveBootstrapCache,
    isUsable: (_) => true,
    didChange: (cached, remote) =>
        cached.maintenanceMode != remote.maintenanceMode ||
        cached.config.toJson().toString() != remote.config.toJson().toString(),
  );
});

final appConfigProvider = Provider<AppConfigModel?>((ref) {
  return ref.watch(bootstrapProvider).valueOrNull?.config;
});

final pricingProvider = FutureProvider<List<PricingPlanModel>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final storage = ref.read(storageServiceProvider);
  return cacheFirstThenRefresh<List<PricingPlanModel>>(
    ref: ref,
    loadCache: storage.loadPricingCache,
    fetchRemote: api.fetchPricing,
    saveCache: storage.savePricingCache,
    isUsable: (v) => v.isNotEmpty,
    didChange: (a, b) => listJsonChanged(a, b, (p) => p.toJson()),
  );
});

/// Preloads content fast (cache-first). Subscription sync runs in background.
final remoteContentProvider = FutureProvider<void>((ref) async {
  await Future.wait([
    ref.watch(bootstrapProvider.future),
    ref.watch(channelsProvider.future),
    ref.watch(carouselProvider.future),
    ref.watch(pricingProvider.future),
  ]);

  // Do not block opening on heartbeat / FCM — MainShell live-sync covers it.
  // ignore: unawaited_futures
  ref.read(userProvider.notifier).refresh(heartbeat: true);
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
    ref.read(userProvider.notifier).refresh(heartbeat: true),
  ]);
}

/// Lightweight live tick used while the app stays open.
Future<void> liveSyncTick(WidgetRef ref, {bool fullContent = false}) async {
  await ref.read(userProvider.notifier).refresh(heartbeat: true);
  if (fullContent) {
    await softRefreshRemoteContent(ref);
  }
}
