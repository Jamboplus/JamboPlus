import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Same channel id as Supasoka / SupaAdmin FCM Android config.
const kPushChannelId = 'supasoka_high_importance';
const kPushChannelName = 'JamboPlus Notifications';
const kPushChannelDescription = 'Habari na arifa kutoka SupaAdmin';

final _localNotifications = FlutterLocalNotificationsPlugin();

bool _firebaseReady = false;

bool get _pushSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!_pushSupported) return;
  await Firebase.initializeApp();
}

/// Receives SupaAdmin pushes (mirrored onto JamboPlus FCM topics).
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

    // Request permission (Android 13+ / iOS).
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('FCM permission: ${settings.authorizationStatus}');
      debugPrint('FCM token: ${await messaging.getToken()}');
    }

    await messaging.subscribeToTopic('all_users');
    await syncAudienceTopics(isPremium: false);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_logOpened);

    final initial = await messaging.getInitialMessage();
    if (initial != null) _logOpened(initial);
  }

  /// Keep premium/free topics in sync with JamboPlus subscription.
  static Future<void> syncAudienceTopics({required bool isPremium}) async {
    if (!_firebaseReady) return;
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.subscribeToTopic('all_users');
      if (isPremium) {
        await messaging.subscribeToTopic('premium_users');
        await messaging.unsubscribeFromTopic('free_users');
      } else {
        await messaging.subscribeToTopic('free_users');
        await messaging.unsubscribeFromTopic('premium_users');
      }
      if (kDebugMode) {
        debugPrint('FCM topics synced (premium=$isPremium)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM topic sync failed: $e');
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
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
