import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for incoming DM / group messages.
class MessengerNotifications {
  MessengerNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'ytcm_messages';
  static const _androidChannelName = 'Messages';

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          importance: Importance.high,
        ));
  }

  static Future<void> requestPermissionsIfNeeded() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static int _hashId(String a, [String? b]) {
    var h = 0;
    for (final c in a.codeUnits) {
      h = 0x1fffffff & (h + c);
      h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));
      h ^= h >> 6;
    }
    if (b != null) {
      for (final c in b.codeUnits) {
        h = 0x1fffffff & (h + c);
      }
    }
    return h.abs() % 0x3fffffff;
  }

  static Future<void> showDm({
    required String peerId,
    required String title,
    required String body,
  }) async {
    final android = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    await _plugin.show(
      _hashId('dm', peerId),
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }

  static Future<void> showGroup({
    required String groupId,
    required String title,
    required String body,
  }) async {
    final android = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    await _plugin.show(
      _hashId('g', groupId),
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }
}
