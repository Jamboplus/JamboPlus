import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/constants/app_constants.dart';
import 'package:jamboplus/models/user_model.dart';
import 'package:jamboplus/providers/service_providers.dart';
import 'package:jamboplus/services/api_service.dart';
import 'package:jamboplus/services/push_notification_service.dart';
import 'package:jamboplus/services/storage_service.dart';

final userProvider = StateNotifierProvider<UserNotifier, UserModel>((ref) {
  return UserNotifier(
    ref.read(storageServiceProvider),
    ref.read(apiServiceProvider),
  );
});

class UserNotifier extends StateNotifier<UserModel> {
  UserNotifier(this._storage, this._api) : super(UserModel.defaultUser) {
    _bootstrap();
  }

  final StorageService _storage;
  final ApiService _api;
  Future<void>? _bootstrapFuture;
  Future<void>? _refreshInFlight;

  Future<void> _bootstrap() {
    return _bootstrapFuture ??= _loadCachedProfile();
  }

  /// Load local profile only — network sync is owned by remoteContent / refresh.
  Future<void> _loadCachedProfile() async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final cached = await _storage.getUser();
    if (cached != null) {
      state = cached.deviceId.isEmpty
          ? cached.copyWith(deviceId: deviceId)
          : cached;
      if (cached.deviceId.isEmpty) {
        await _storage.saveUser(state);
      }
    } else {
      state = UserModel.defaultUser.copyWith(deviceId: deviceId);
    }
  }

  /// Sync subscription from server. Prefer heartbeat so admin grants appear fast.
  Future<void> refresh({bool heartbeat = true}) {
    return _refreshInFlight ??= _refreshBody(heartbeat: heartbeat)
        .whenComplete(() => _refreshInFlight = null);
  }

  Future<void> _refreshBody({required bool heartbeat}) async {
    await _bootstrap();
    if (heartbeat) {
      try {
        final deviceId = state.deviceId.isNotEmpty
            ? state.deviceId
            : await _storage.getOrCreateDeviceId();
        final fcmToken = await PushNotificationService.currentToken();
        final remote = await _api.sendDeviceHeartbeat(
          deviceId: deviceId,
          fcmToken: fcmToken,
          platform: defaultTargetPlatform.name,
          appVersion: AppConstants.appVersion,
        );
        await seedFromDevice(remote);
        return;
      } catch (_) {
        // Fall through to /users/me.
      }
    }
    await syncFromServer();
  }

  /// Persist a server user payload and refresh push topics.
  Future<void> applyRemoteUser(UserModel remote) async {
    await _bootstrap();
    final deviceId = remote.deviceId.isNotEmpty
        ? remote.deviceId
        : (state.deviceId.isNotEmpty
            ? state.deviceId
            : await _storage.getOrCreateDeviceId());
    final merged = remote.copyWith(deviceId: deviceId);
    state = merged;
    await _storage.saveUser(merged);
    await PushNotificationService.syncAudienceTopics(
      isPremium: merged.hasActiveSubscription,
    );
  }

  /// Seed / refresh from device heartbeat without wiping a registered phone.
  Future<void> seedFromDevice(UserModel remote) async {
    await _bootstrap();
    final localDeviceId = await _storage.getOrCreateDeviceId();
    final deviceId = remote.deviceId.isNotEmpty ? remote.deviceId : localDeviceId;

    if (state.phone.trim().isNotEmpty) {
      // Keep phone-bound account; only attach device id if missing.
      if (state.deviceId.isEmpty) {
        final updated = state.copyWith(deviceId: deviceId);
        state = updated;
        await _storage.saveUser(updated);
      }
      await syncFromServer();
      return;
    }

    await applyRemoteUser(remote.copyWith(deviceId: deviceId));
  }

  /// Pull package/expiry from server by phone, then device id.
  Future<void> syncFromServer() async {
    final phone = state.phone.trim();
    try {
      UserModel? remote;
      if (phone.isNotEmpty) {
        remote = await _api.fetchUserByPhone(phone);
        if (remote == null) {
          // Admin deleted the account — drop local premium, keep device id.
          final deviceId = state.deviceId.isNotEmpty
              ? state.deviceId
              : await _storage.getOrCreateDeviceId();
          final cleared = state.copyWith(
            id: '',
            packageType: PackageType.free,
            clearExpiry: true,
            deviceId: deviceId,
          );
          state = cleared;
          await _storage.saveUser(cleared);
          await PushNotificationService.syncAudienceTopics(isPremium: false);
          return;
        }
      } else {
        final deviceId = state.deviceId.isNotEmpty
            ? state.deviceId
            : await _storage.getOrCreateDeviceId();
        remote = await _api.fetchUserByDeviceId(deviceId);
        if (remote == null) return;
      }
      await applyRemoteUser(remote);
    } catch (_) {
      // Keep cached profile offline.
    }
  }

  /// Bind name + phone to this device before / after payment.
  Future<UserModel> submitAccessRequest({
    required String name,
    required String phone,
  }) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final remote = await _api.registerUser(
      name: name,
      phone: phone,
      deviceId: deviceId,
    );
    await applyRemoteUser(remote);
    return state;
  }

  /// After SonicPesa success: unlock from the payment payload immediately.
  /// A follow-up sync runs in the background so the success screen is not held
  /// for another register round-trip.
  Future<UserModel> activateAfterPayment({
    required String name,
    required String phone,
    Map<String, dynamic>? userJson,
  }) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    var applied = false;

    if (userJson != null) {
      try {
        final fromStatus = UserModel.fromJson(userJson);
        await applyRemoteUser(
          fromStatus.copyWith(
            name: fromStatus.name.isNotEmpty ? fromStatus.name : name,
            phone: fromStatus.phone.isNotEmpty ? fromStatus.phone : phone,
            deviceId: fromStatus.deviceId.isNotEmpty
                ? fromStatus.deviceId
                : deviceId,
          ),
        );
        applied = true;
      } catch (_) {}
    }

    if (!applied) {
      state = state.copyWith(name: name, phone: phone, deviceId: deviceId);
      await _storage.saveUser(state);
    }

    unawaited(syncFromServer());
    return state;
  }
}
