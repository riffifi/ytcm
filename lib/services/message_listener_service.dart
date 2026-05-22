import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;

import 'chat_socket_runner.dart';
import 'conversation_store.dart';
import 'notification_service.dart';
import 'server_endpoints.dart';

const _listenerChannelId = 'messenger_listener';
const _listenerNotificationId = 888;
const _prefListenerWanted = 'listener_wanted';
const _prefNotifiedIds = 'notified_message_ids';

/// Android foreground service: holds the chat WebSocket while the app is backgrounded.
class MessageListenerService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _configured = false;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<void> configure() async {
    if (!isSupported || _configured) return;

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _listenerChannelId,
        'Messenger connection',
        description: 'Required while listening for messages in the background',
        importance: Importance.low,
      );
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await _service.configure(
      iosConfiguration: IosConfiguration(autoStart: false),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceTypes: [AndroidForegroundType.remoteMessaging],
        notificationChannelId: _listenerChannelId,
        initialNotificationTitle: 'Messenger',
        initialNotificationContent: 'Listening for messages',
        foregroundServiceNotificationId: _listenerNotificationId,
      ),
    );
    _configured = true;
  }

  static Future<bool> start() async {
    if (!isSupported) return false;
    if (!await ServerEndpoints.isConfigured) return false;
    await configure();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefListenerWanted, true);
    if (await _service.isRunning()) return true;
    return _service.startService();
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefListenerWanted, false);
    if (await _service.isRunning()) {
      _service.invoke('stop');
    }
  }

  static Future<void> updateAppState({
    required bool inForeground,
    String? activeChatPeerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_in_foreground', inForeground);
    if (activeChatPeerId != null && activeChatPeerId.isNotEmpty) {
      await prefs.setString('active_chat_peer', activeChatPeerId);
    } else {
      await prefs.remove('active_chat_peer');
    }
  }

  static Future<bool> alreadyNotified(String messageUuid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefNotifiedIds) ?? [];
    return raw.contains(messageUuid);
  }

  static Future<void> markNotified(String messageUuid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefNotifiedIds) ?? [];
    if (raw.contains(messageUuid)) return;
    final next = [...raw, messageUuid];
    if (next.length > 300) {
      next.removeRange(0, next.length - 300);
    }
    await prefs.setStringList(_prefNotifiedIds, next);
  }
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  var stopping = false;
  service.on('stop').listen((_) => stopping = true);

  final android = service is AndroidServiceInstance ? service : null;

  await NotificationService.instance.init();
  NotificationService.instance.setAppForeground(false);

  final endpoints = await ServerEndpoints.fromPrefs();
  final chatUrl = endpoints.chatUrl;
  if (chatUrl == null) {
    service.stopSelf();
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('session_token');
  if (token == null || token.isEmpty) {
    service.stopSelf();
    return;
  }

  final myUuid = prefs.getString('user_uuid');
  final store = ConversationStore();
  await store.load();
  final historyPeerIds = ChatSocketRunner.peerIdsFromStore(store, max: 30);

  await _markAuthOnline(prefs, token);

  Timer? heartbeat;
  heartbeat = Timer.periodic(const Duration(seconds: 30), (_) async {
    if (stopping) return;
    await android?.setForegroundNotificationInfo(
      title: 'Messenger',
      content: 'Listening for messages',
    );
  });

  var reconnectDelay = const Duration(seconds: 3);
  final sessionNotified = <String>{};

  try {
    while (!stopping) {
      final wanted = prefs.getBool(_prefListenerWanted) ?? false;
      if (!wanted) break;

      try {
        await ChatSocketRunner.listen(
          chatUrl: chatUrl,
          sessionToken: token,
          historyPeerIds: historyPeerIds,
          maxDuration: const Duration(hours: 12),
          shouldStop: () => stopping,
          onLiveMessage: (msg) async {
            if (stopping) return;
            if (myUuid != null && msg.senderId == myUuid) return;
            if (sessionNotified.contains(msg.uuid)) return;
            if (await MessageListenerService.alreadyNotified(msg.uuid)) return;

            final p = await SharedPreferences.getInstance();
            if (p.getBool('app_in_foreground') == true) {
              final active = p.getString('active_chat_peer');
              if (active != null &&
                  active == msg.senderId) {
                return;
              }
            }

            sessionNotified.add(msg.uuid);
            await MessageListenerService.markNotified(msg.uuid);

            final peerId = msg.senderId;
            final title = store.nameFor(peerId) ??
                'User ${peerId.length >= 8 ? peerId.substring(0, 8) : peerId}';
            await NotificationService.instance.showIncomingMessage(
              peerId: peerId,
              title: title,
              body:
                  msg.previewText.isNotEmpty ? msg.previewText : 'New message',
              force: true,
            );
          },
        );
      } catch (e, st) {
        debugPrint('MessageListenerService: $e\n$st');
      }

      if (stopping) break;
      if (!(prefs.getBool(_prefListenerWanted) ?? false)) break;

      await Future.delayed(reconnectDelay);
      reconnectDelay = Duration(
        seconds: (reconnectDelay.inSeconds * 2).clamp(3, 60),
      );
      await _markAuthOnline(prefs, token);
    }
  } finally {
    heartbeat.cancel();
    service.stopSelf();
  }
}

Future<void> _markAuthOnline(SharedPreferences prefs, String token) async {
  final authUrl = prefs.getString(ServerEndpoints.prefsKeyAuth)?.trim();
  if (authUrl == null || authUrl.isEmpty) return;
  try {
    await http
        .get(Uri.parse('$authUrl/online').replace(
          queryParameters: {'session_tocken': token},
        ))
        .timeout(const Duration(seconds: 10));
  } catch (_) {}
}
