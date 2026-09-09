import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api/admin_api.dart';
import '../models/admin_models.dart';

class AdminState extends ChangeNotifier {
  final AdminApi _api = AdminApi();

  bool _loggedIn = false;
  bool _booting = true;
  String? _authError;
  String _section = 'dashboard';
  String _userQuery = '';
  String _channelQuery = '';

  Map<String, dynamic> _dashboard = {};
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _carousel = [];
  List<Map<String, dynamic>> _pricing = [];
  Map<String, dynamic>? _appConfig;

  bool loading = false;
  String? loadError;

  bool get loggedIn => _loggedIn;
  bool get booting => _booting;
  String? get authError => _authError;
  String get section => _section;
  String get userQuery => _userQuery;
  String get channelQuery => _channelQuery;
  String get adminEmail => _api.adminEmail ?? 'jamboplus@gmail.com';

  int get userCount => (_dashboard['userCount'] as num?)?.toInt() ?? _users.length;
  int get premiumCount => (_dashboard['premiumCount'] as num?)?.toInt() ?? 0;
  int get channelCount => (_dashboard['channelCount'] as num?)?.toInt() ?? _channels.length;
  double get todayRevenue => (_dashboard['todayRevenue'] as num?)?.toDouble() ?? 0;
  int get todayTransactions => (_dashboard['todayTransactionCount'] as num?)?.toInt() ?? 0;
  int get liveChannelCount => _channels.where((c) => c['isLive'] == true).length;

  String get revenueLabel {
    final fmt = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
    return fmt.format(todayRevenue);
  }

  List<Map<String, dynamic>> get users => List.unmodifiable(_users);
  List<Map<String, dynamic>> get channels => List.unmodifiable(
        _channels.where((c) => c['id'] != _msaadaChannelId && c['category'] != '__system__'),
      );

  /// Hidden Msaada WhatsApp payload dual-written as a system channel.
  Map<String, dynamic>? get msaadaWhatsAppMeta {
    Map<String, dynamic>? row;
    for (final c in _channels) {
      if (c['id'] == _msaadaChannelId || c['category'] == '__system__') {
        row = c;
        break;
      }
    }
    if (row == null) return null;
    try {
      final raw = row['description'];
      if (raw is String && raw.trim().startsWith('{')) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return {
            ...decoded,
            'name': row['name'],
          };
        }
        if (decoded is Map) {
          return {
            ...Map<String, dynamic>.from(decoded),
            'name': row['name'],
          };
        }
      }
    } catch (_) {}
    return {
      'phone': row['name'],
      'name': row['name'],
      'message': '',
      'hours': '',
    };
  }
  List<Map<String, dynamic>> get carousel => List.unmodifiable(_carousel);
  List<Map<String, dynamic>> get pricing => List.unmodifiable(_pricing);
  Map<String, dynamic>? get appConfig => _appConfig;

  AdminNavItem? sectionMeta(List<AdminNavItem> items) {
    for (final item in items) {
      if (item.id == _section) return item;
    }
    return null;
  }

  Future<void> tryRestoreSession() async {
    _booting = true;
    notifyListeners();
    await _api.loadToken();
    if (_api.isAuthenticated) {
      try {
        await refreshAll(rethrowErrors: true);
        _loggedIn = true;
      } on ApiException catch (e) {
        await _api.clearToken();
        _loggedIn = false;
        _authError = e.isUnauthorized
            ? 'Ingia tena — tokeni imeisha'
            : e.message;
      } catch (_) {
        await _api.clearToken();
        _loggedIn = false;
      }
    }
    _booting = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _authError = null;
    try {
      await _api.login(email.trim(), password);
      await refreshAll(rethrowErrors: true);
      _loggedIn = true;
      loadError = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _authError = e.isUnauthorized
          ? 'Barua pepe au nenosiri si sahihi'
          : e.message;
      if (e.isUnauthorized) await _api.clearToken();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    _loggedIn = false;
    _section = 'dashboard';
    loadError = null;
    notifyListeners();
  }

  void setSection(String id) {
    _section = id;
    notifyListeners();
  }

  void setUserQuery(String q) {
    _userQuery = q;
    notifyListeners();
  }

  void setChannelQuery(String q) {
    _channelQuery = q;
    notifyListeners();
  }

  Future<void> refreshAll({bool rethrowErrors = false}) async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.dashboard(),
        _api.listUsers(),
        _api.listChannels(),
        _api.listCarousel(),
        _api.listPricing(),
        _api.getAppConfig(),
      ]);
      _dashboard = results[0] as Map<String, dynamic>;
      _users = (results[1] as List).cast<Map<String, dynamic>>();
      _channels = (results[2] as List).cast<Map<String, dynamic>>()
        ..sort((a, b) => ((a['sortOrder'] as num?)?.toInt() ?? 0)
            .compareTo((b['sortOrder'] as num?)?.toInt() ?? 0));
      _carousel = (results[3] as List).cast<Map<String, dynamic>>()
        ..sort((a, b) => ((a['sortOrder'] as num?)?.toInt() ?? 0)
            .compareTo((b['sortOrder'] as num?)?.toInt() ?? 0));
      _pricing = (results[4] as List).cast<Map<String, dynamic>>();
      _appConfig = results[5] as Map<String, dynamic>;
      loadError = null;
    } on ApiException catch (e) {
      loadError = e.message;
      if (e.isUnauthorized) {
        await _api.clearToken();
        _loggedIn = false;
        _authError = 'Ingia tena — tokeni imeisha';
      }
      if (rethrowErrors) rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshDashboard() async {
    try {
      _dashboard = await _api.dashboard();
      notifyListeners();
    } catch (_) {}
  }

  // ── App config ──
  Future<void> saveAppConfig(Map<String, dynamic> body) async {
    _appConfig = await _api.updateAppConfig(body);
    // Dual-write Msaada WhatsApp into a hidden system channel so the live
    // production API (without whatsapp_* columns yet) still serves updates.
    final phone = (body['whatsappNumber'] as String? ?? '').trim();
    final message = (body['whatsappMessage'] as String? ?? '').trim();
    final hours = (body['supportHours'] as String? ?? '').trim();
    if (phone.isNotEmpty || message.isNotEmpty || hours.isNotEmpty) {
      await _syncMsaadaWhatsAppChannel(
        phone: phone.isNotEmpty
            ? phone
            : (_appConfig?['whatsappNumber'] as String? ?? ''),
        message: message,
        hours: hours,
      );
    }
    notifyListeners();
  }

  static const _msaadaChannelId = 'system-msaada-whatsapp';

  Future<void> _syncMsaadaWhatsAppChannel({
    required String phone,
    required String message,
    required String hours,
  }) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final normalized = digits.startsWith('0') && digits.length == 10
        ? '255${digits.substring(1)}'
        : digits;
    final display = normalized.startsWith('255') && normalized.length >= 12
        ? '0${normalized.substring(3)}'
        : (phone.isNotEmpty ? phone : normalized);
    final payload = <String, dynamic>{
      'id': _msaadaChannelId,
      'name': display.isNotEmpty ? display : 'Msaada WhatsApp',
      'image': 'https://cdn-icons-png.flaticon.com/512/733/733585.png',
      'category': '__system__',
      'description': jsonEncode({
        'v': 1,
        'phone': normalized.isNotEmpty ? normalized : phone,
        'message': message.isNotEmpty
            ? message
            : 'Habari, ninahitaji msaada kutoka JamboPlus.',
        'hours': hours.isNotEmpty
            ? hours
            : 'Jumatatu - Jumapili: 08:00 - 22:00',
      }),
      'isPremium': false,
      'isLive': false,
      'streamUrl': '',
      'sortOrder': 9999,
      'enabled': true,
    };

    Map<String, dynamic> saved;
    try {
      saved = await _api.updateChannel(_msaadaChannelId, payload);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        saved = await _api.createChannel(payload);
      } else {
        // Insert may be needed when update fails for other reasons.
        try {
          saved = await _api.createChannel(payload);
        } catch (_) {
          rethrow;
        }
      }
    }

    final i = _channels.indexWhere((c) => c['id'] == _msaadaChannelId);
    if (i >= 0) {
      _channels[i] = saved;
    } else {
      _channels.add(saved);
    }
  }

  // ── Users ──
  Future<Map<String, dynamic>> addUser(Map<String, dynamic> body) async {
    final created = await _api.createUser(body);
    _users.insert(0, created);
    await _refreshDashboard();
    notifyListeners();
    return created;
  }

  Future<void> updateUserRecord(String id, Map<String, dynamic> body) async {
    final updated = await _api.updateUser(id, body);
    final i = _users.indexWhere((u) => u['id'] == id);
    if (i >= 0) _users[i] = updated;
    await _refreshDashboard();
    notifyListeners();
  }

  Future<void> removeUser(String id) async {
    await _api.deleteUser(id);
    _users.removeWhere((u) => u['id'] == id);
    await _refreshDashboard();
    notifyListeners();
  }

  Future<int> removeAllUsers() async {
    final n = await _api.deleteAllUsers();
    _users.clear();
    await _refreshDashboard();
    notifyListeners();
    return n;
  }

  // ── Channels ──
  Future<Map<String, dynamic>> addChannel(Map<String, dynamic> body) async {
    final created = await _api.createChannel(body);
    _channels.add(created);
    await _refreshDashboard();
    notifyListeners();
    return created;
  }

  Future<void> saveChannel(String id, Map<String, dynamic> body) async {
    final updated = await _api.updateChannel(id, body);
    final i = _channels.indexWhere((c) => c['id'] == id);
    if (i >= 0) _channels[i] = updated;
    notifyListeners();
  }

  Future<void> removeChannel(String id) async {
    await _api.deleteChannel(id);
    _channels.removeWhere((c) => c['id'] == id);
    await _refreshDashboard();
    notifyListeners();
  }

  Future<void> reorderChannel(int oldIndex, int newIndex) async {
    // onReorderItem already adjusts newIndex for the removed item
    final item = _channels.removeAt(oldIndex);
    _channels.insert(newIndex, item);
    notifyListeners();
    for (var i = 0; i < _channels.length; i++) {
      final id = _channels[i]['id'] as String;
      final updated = await _api.updateChannel(id, {'sortOrder': i});
      _channels[i] = updated;
    }
    notifyListeners();
  }

  // ── Premium access helpers ──
  void _upsertUserLocal(Map<String, dynamic> updated) {
    final id = updated['id'] as String?;
    if (id == null) return;
    final i = _users.indexWhere((u) => u['id'] == id);
    if (i >= 0) {
      _users[i] = updated;
    } else {
      _users.insert(0, updated);
    }
  }

  Future<void> grantPremium(String id, int amount, String unit) async {
    final updated = await _api.setUserPremium({
      'action': 'grant',
      'userId': id,
      'amount': amount,
      'unit': unit,
    });
    _upsertUserLocal(updated);
    await _refreshDashboard();
    notifyListeners();
  }

  /// Upgrade / extend premium using the user's unique device id from Mtumiaji.
  Future<Map<String, dynamic>> grantPremiumByDeviceId(
    String deviceId,
    int amount,
    String unit,
  ) async {
    final updated = await _api.setUserPremium({
      'action': 'grant',
      'deviceId': deviceId.trim(),
      'amount': amount,
      'unit': unit,
    });
    _upsertUserLocal(updated);
    await _refreshDashboard();
    notifyListeners();
    return updated;
  }

  Future<Map<String, dynamic>> grantPremiumByPhone(
    String phone,
    int amount,
    String unit,
  ) async {
    final updated = await _api.setUserPremium({
      'action': 'grant',
      'phone': phone.trim(),
      'amount': amount,
      'unit': unit,
    });
    _upsertUserLocal(updated);
    await _refreshDashboard();
    notifyListeners();
    return updated;
  }

  Future<void> revokePremium(String id) async {
    final updated = await _api.setUserPremium({
      'action': 'revoke',
      'userId': id,
    });
    _upsertUserLocal(updated);
    await _refreshDashboard();
    notifyListeners();
  }

  Future<Map<String, dynamic>> revokePremiumByDeviceId(String deviceId) async {
    final updated = await _api.setUserPremium({
      'action': 'revoke',
      'deviceId': deviceId.trim(),
    });
    _upsertUserLocal(updated);
    await _refreshDashboard();
    notifyListeners();
    return updated;
  }

  Future<Map<String, dynamic>> revokePremiumByPhone(String phone) async {
    final updated = await _api.setUserPremium({
      'action': 'revoke',
      'phone': phone.trim(),
    });
    _upsertUserLocal(updated);
    await _refreshDashboard();
    notifyListeners();
    return updated;
  }

  // ── Carousel ──
  Future<Map<String, dynamic>> addCarousel(Map<String, dynamic> body) async {
    final created = await _api.createCarousel(body);
    _carousel.add(created);
    notifyListeners();
    return created;
  }

  Future<void> saveCarousel(String id, Map<String, dynamic> body) async {
    final updated = await _api.updateCarousel(id, body);
    final i = _carousel.indexWhere((c) => c['id'] == id);
    if (i >= 0) _carousel[i] = updated;
    notifyListeners();
  }

  Future<void> removeCarousel(String id) async {
    await _api.deleteCarousel(id);
    _carousel.removeWhere((c) => c['id'] == id);
    notifyListeners();
  }

  // ── Pricing ──
  Future<Map<String, dynamic>> addPricing(Map<String, dynamic> body) async {
    final created = await _api.createPricing(body);
    _pricing.add(created);
    notifyListeners();
    return created;
  }

  Future<void> savePricing(String id, Map<String, dynamic> body) async {
    final updated = await _api.updatePricing(id, body);
    final i = _pricing.indexWhere((c) => c['id'] == id);
    if (i >= 0) _pricing[i] = updated;
    notifyListeners();
  }

  Future<void> removePricing(String id) async {
    await _api.deletePricing(id);
    _pricing.removeWhere((c) => c['id'] == id);
    notifyListeners();
  }

  Future<void> togglePricingEnabled(String id, bool enabled) async {
    await savePricing(id, {'enabled': enabled});
  }
}
