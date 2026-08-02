import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> _bootstrap() async {
    final cached = await _storage.getUser();
    if (cached != null) {
      state = cached;
    }
    await syncFromServer();
  }

  Future<void> refresh() async {
    await syncFromServer();
  }

  /// Pull package/expiry from admin-managed server record.
  Future<void> syncFromServer() async {
    final phone = state.phone.trim();
    if (phone.isEmpty) return;
    try {
      final remote = await _api.fetchUserByPhone(phone);
      if (remote == null) {
        // Admin deleted the account — drop local premium.
        final cleared = state.copyWith(
          id: '',
          packageType: PackageType.free,
          clearExpiry: true,
        );
        state = cleared;
        await _storage.saveUser(cleared);
        return;
      }
      state = remote;
      await _storage.saveUser(remote);
      await PushNotificationService.syncAudienceTopics(
        isPremium: remote.hasActiveSubscription,
      );
    } catch (_) {
      // Keep cached profile offline.
    }
  }

  /// Payment / signup: create or update free account. Premium only via admin.
  Future<UserModel> submitAccessRequest({
    required String name,
    required String phone,
  }) async {
    final remote = await _api.registerUser(name: name, phone: phone);
    state = remote;
    await _storage.saveUser(remote);
    await PushNotificationService.syncAudienceTopics(
      isPremium: remote.hasActiveSubscription,
    );
    return remote;
  }
}
