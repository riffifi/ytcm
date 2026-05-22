import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_preferences.dart';

/// Local notifications for incoming messages (Android-focused).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'messenger_messages';
  static const _channelName = 'Messages';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _inForeground = true;
  String? _activePeerId;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  void setAppForeground(bool inForeground) => _inForeground = inForeground;

  void setActiveChat(String? peerId) => _activePeerId = peerId;

  Future<void> init() async {
    if (!isSupported || _initialized) return;

    const android = AndroidInitializationSettings('@drawable/ic_stat_chat');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

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
      await _android?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  Future<bool> _canPost() async {
    if (!isSupported) return false;
    if (!_initialized) await init();
    if (!Platform.isAndroid) return true;

    var enabled = await _android?.areNotificationsEnabled() ?? false;
    if (!enabled) {
      await _android?.requestNotificationsPermission();
      enabled = await _android?.areNotificationsEnabled() ?? false;
    }
    return enabled;
  }

  Future<void> showIncomingMessage({
    required String peerId,
    required String title,
    required String body,
    bool force = false,
  }) async {
    if (body.trim().isEmpty) return;
    if (NotificationPreferences.isMobilePlatform) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notifications_enabled') == false) return;
    }
    if (!await _canPost()) return;

    if (!force && _inForeground && _activePeerId == peerId) return;

    final id = peerId.hashCode.abs() % 2147483647;
    if (id == 0) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'New chat messages',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_stat_chat',
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
    } catch (e, st) {
      debugPrint('NotificationService.show failed: $e\n$st');
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
