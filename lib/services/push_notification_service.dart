import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// JamboPlus-only FCM topics (never Supasoka shared `all_users`).
const kTopicAllUsers = 'jamboplus_all_users';
const kTopicPremiumUsers = 'jamboplus_premium_users';
const kTopicFreeUsers = 'jamboplus_free_users';

/// Legacy Supasoka topics — unsubscribe on every init.
const _legacyTopics = ['all_users', 'premium_users', 'free_users'];

const kPushChannelId = 'jamboplus_notifications';
const kPushChannelName = 'JamboPlus Notifications';
const kPushChannelDescription = 'Habari na arifa kutoka JamboPlus';

final _localNotifications = FlutterLocalNotificationsPlugin();

bool _firebaseReady = false;

bool get _pushSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

const _expiredReminderMarkers = [
  'kifurushi chako kimeisha',
  'kifurushi chako kimeisha muda wake',
];

/// True for Supasoka payment/expired reminders that must never surface in JamboPlus.
bool isSupasokaReminderMessage(RemoteMessage message) {
  final data = message.data;
  final kind = (data['kind'] ?? data['type'] ?? '').toString().toLowerCase();
  final scope = (data['scope'] ?? '').toString().toLowerCase();
  final source = (data['source'] ?? '').toString().toLowerCase();
  final target = (data['target'] ?? '').toString().toLowerCase();

  if (scope == 'user') return true;
  if (target.startsWith('user:')) return true;
  if (source == 'supaadmin' && kind != 'broadcast') return true;
  if (kind == 'reminder' ||
      kind == 'payment_reminder' ||
      kind == 'expired_reminder') {
    return true;
  }

  final title = (message.notification?.title ?? data['title'] ?? '')
      .toString()
      .toLowerCase();
  final body = (message.notification?.body ?? data['body'] ?? data['message'] ?? '')
      .toString()
      .toLowerCase();
  final haystack = '$title $body';
  return _expiredReminderMarkers.any(haystack.contains);
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!_pushSupported) return;
  if (isSupasokaReminderMessage(message)) return;
  await Firebase.initializeApp();
}

/// Receives JamboPlus broadcasts on dedicated FCM topics only.
class PushNotificationService {
  PushNotificationService._();

  static bool get isReady => _firebaseReady;

  static Future<void> initialize() async {
    if (!_pushSupported) return;

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e, st) {
      _firebaseReady = false;
      if (kDebugMode) {
        debugPrint('Firebase.initializeApp failed: $e\n$st');
      }
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      kPushChannelId,
      kPushChannelName,
      description: kPushChannelDescription,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('FCM permission: ${settings.authorizationStatus}');
      debugPrint('FCM token: ${await messaging.getToken()}');
    }

    await _leaveLegacySupasokaTopics();
    await syncAudienceTopics(isPremium: false);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_logOpened);

    final initial = await messaging.getInitialMessage();
    if (initial != null) _logOpened(initial);
  }

  static Future<String?> currentToken() async {
    if (!_firebaseReady) return null;
    try {
      return FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _leaveLegacySupasokaTopics() async {
    if (!_firebaseReady) return;
    final messaging = FirebaseMessaging.instance;
    for (final topic in _legacyTopics) {
      try {
        await messaging.unsubscribeFromTopic(topic);
      } catch (_) {}
    }
  }

  /// Keep JamboPlus audience topics in sync with subscription.
  static Future<void> syncAudienceTopics({required bool isPremium}) async {
    if (!_firebaseReady) return;
    final messaging = FirebaseMessaging.instance;
    try {
      await _leaveLegacySupasokaTopics();
      await messaging.subscribeToTopic(kTopicAllUsers);
      if (isPremium) {
        await messaging.subscribeToTopic(kTopicPremiumUsers);
        await messaging.unsubscribeFromTopic(kTopicFreeUsers);
      } else {
        await messaging.subscribeToTopic(kTopicFreeUsers);
        await messaging.unsubscribeFromTopic(kTopicPremiumUsers);
      }
      if (kDebugMode) {
        debugPrint('FCM topics synced (premium=$isPremium, jamboplus-only)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM topic sync failed: $e');
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (isSupasokaReminderMessage(message)) {
      if (kDebugMode) {
        debugPrint('Ignoring Supasoka reminder (not for JamboPlus)');
      }
      return;
    }

    final n = message.notification;
    if (n == null) return;

    const android = AndroidNotificationDetails(
      kPushChannelId,
      kPushChannelName,
      channelDescription: kPushChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _localNotifications.show(
      message.hashCode,
      n.title ?? 'JamboPlus',
      n.body ?? '',
      const NotificationDetails(android: android),
      payload: jsonEncode(message.data),
    );
  }

  static void _logOpened(RemoteMessage message) {
    if (kDebugMode) debugPrint('Notification opened: ${message.data}');
  }
}
