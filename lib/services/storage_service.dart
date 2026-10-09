import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:jamboplus/models/app_config_model.dart';
import 'package:jamboplus/models/carousel_model.dart';
import 'package:jamboplus/models/channel_model.dart';
import 'package:jamboplus/models/pricing_model.dart';
import 'package:jamboplus/models/user_model.dart';

class StorageService {
  static const _userKey = 'user_profile';
  static const _deviceIdKey = 'device_id';
  static const _bootstrapKey = 'cache_bootstrap_v1';
  static const _channelsKey = 'cache_channels_v1';
  static const _carouselKey = 'cache_carousel_v1';
  static const _pricingKey = 'cache_pricing_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await _instance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.length >= 8) return existing;

    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final id = List.generate(24, (_) => chars[random.nextInt(chars.length)]).join();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<UserModel?> getUser() async {
    final prefs = await _instance();
    final json = prefs.getString(_userKey);
    if (json == null) return null;
    return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveUser(UserModel user) async {
    final prefs = await _instance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> clearUser() async {
    final prefs = await _instance();
    await prefs.remove(_userKey);
  }

  Future<void> saveBootstrapCache(BootstrapModel bootstrap) async {
    final prefs = await _instance();
    await prefs.setString(_bootstrapKey, jsonEncode(bootstrap.toJson()));
  }

  Future<BootstrapModel?> loadBootstrapCache() async {
    final prefs = await _instance();
    final raw = prefs.getString(_bootstrapKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return BootstrapModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveChannelsCache(List<ChannelModel> channels) async {
    final prefs = await _instance();
    await prefs.setString(
      _channelsKey,
      jsonEncode(channels.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<ChannelModel>?> loadChannelsCache() async {
    final prefs = await _instance();
    final raw = prefs.getString(_channelsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChannelModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCarouselCache(List<CarouselModel> items) async {
    final prefs = await _instance();
    await prefs.setString(
      _carouselKey,
      jsonEncode(items.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<CarouselModel>?> loadCarouselCache() async {
    final prefs = await _instance();
    final raw = prefs.getString(_carouselKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CarouselModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> savePricingCache(List<PricingPlanModel> plans) async {
    final prefs = await _instance();
    await prefs.setString(
      _pricingKey,
      jsonEncode(plans.map((p) => p.toJson()).toList()),
    );
  }

  Future<List<PricingPlanModel>?> loadPricingCache() async {
    final prefs = await _instance();
    final raw = prefs.getString(_pricingKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PricingPlanModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
