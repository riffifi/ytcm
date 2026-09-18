import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_preferences.dart';

/// Local notifications for incoming messages (Android-focused).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'yechat_messages_v2';
  static const _channelName = 'YeChat messages';
  static const androidSmallIcon = 'ic_stat_chat';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _inForeground = true;
  String? _activePeerId;

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  void setAppForeground(bool inForeground) => _inForeground = inForeground;

  void setActiveChat(String? peerId) => _activePeerId = peerId;

  Future<void> init() async {
    if (!isSupported || _initialized) return;

    try {
      // flutter_local_notifications expects a drawable resource *name*, not
      // an Android resource reference such as "@drawable/ic_stat_chat".
      const android = AndroidInitializationSettings(androidSmallIcon);
      const ios = DarwinInitializationSettings();
      final initialized = await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      if (initialized != true) {
        debugPrint('NotificationService: plugin initialization failed');
        return;
      }

      if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }

      if (Platform.isAndroid) {
        await _android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'New chat messages',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
          ),
        );
      }

      _initialized = true;
    } catch (error, stackTrace) {
      // Notifications must not prevent the main application from starting.
      debugPrint('NotificationService.init failed: $error\n$stackTrace');
    }
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    if (!_initialized) await init();
    if (!_initialized) return false;
    if (!Platform.isAndroid) return true;
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? await areNotificationsEnabled();
  }

  Future<bool> areNotificationsEnabled() async {
    if (!isSupported) return false;
    if (!_initialized) await init();
    if (!_initialized) return false;
    if (!Platform.isAndroid) return true;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  Future<bool> showIncomingMessage({
    required String peerId,
    required String title,
    required String body,
    bool force = false,
  }) async {
    if (body.trim().isEmpty) return false;
    if (NotificationPreferences.isMobilePlatform) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (prefs.getBool(NotificationPreferences.keyEnabled) == false) {
        return false;
      }
    }
    if (!await areNotificationsEnabled()) return false;

    if (!force && _inForeground && _activePeerId == peerId) return false;

    final id = peerId.hashCode.abs() % 2147483647;
    if (id == 0) return false;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'New chat messages',
      importance: Importance.max,
      priority: Priority.high,
      icon: androidSmallIcon,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
      ticker: 'New message',
    );

    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
      );
      return true;
    } catch (e, st) {
      debugPrint('NotificationService.show failed: $e\n$st');
      return false;
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
