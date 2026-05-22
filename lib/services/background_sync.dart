import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'chat_socket_runner.dart';
import 'conversation_store.dart';
import 'message_listener_service.dart';
import 'notification_service.dart';
import 'server_endpoints.dart';

const _taskName = 'messengerBackgroundSync';
const _periodicUniqueName = 'ytcm-background-sync';
const _oneOffUniqueName = 'ytcm-background-sync-once';

@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _taskName) return true;
    try {
      await BackgroundSync.runOnce();
      return true;
    } catch (_) {
      return false;
    }
  });
}

/// Fallback sync when the foreground listener is not running.
class BackgroundSync {
  static bool get isSupported => !kIsWeb && Platform.isAndroid;
  static bool _registered = false;

  static Future<void> register() async {
    if (!isSupported || _registered) return;
    if (!await ServerEndpoints.isConfigured) return;
    await Workmanager().initialize(backgroundSyncDispatcher);
    await Workmanager().registerPeriodicTask(
      _periodicUniqueName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    _registered = true;
  }

  static Future<void> scheduleSoon() async {
    if (!isSupported) return;
    if (!await ServerEndpoints.isConfigured) return;
    await Workmanager().registerOneOffTask(
      _oneOffUniqueName,
      _taskName,
      initialDelay: const Duration(seconds: 10),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> cancel() async {
    if (!isSupported) return;
    await Workmanager().cancelByUniqueName(_periodicUniqueName);
    await Workmanager().cancelByUniqueName(_oneOffUniqueName);
    _registered = false;
  }

  static Future<void> runOnce() async {
    if (!isSupported) return;
    if (await FlutterBackgroundService().isRunning()) return;

    final endpoints = await ServerEndpoints.fromPrefs();
    final chatUrl = endpoints.chatUrl;
    if (chatUrl == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token');
    if (token == null || token.isEmpty) return;

    final myUuid = prefs.getString('user_uuid');

    await NotificationService.instance.init();
    NotificationService.instance.setAppForeground(false);

    final store = ConversationStore();

    await ChatSocketRunner.listen(
      chatUrl: chatUrl,
      sessionToken: token,
      historyPeerIds: const [],
      maxDuration: const Duration(seconds: 40),
      shouldStop: () => false,
      onLiveMessage: (msg) async {
        if (myUuid != null && msg.senderId == myUuid) return;
        if (await MessageListenerService.alreadyNotified(msg.uuid)) return;

        final p = await SharedPreferences.getInstance();
        if (p.getBool('app_in_foreground') == true) {
          final active = p.getString('active_chat_peer');
          if (active == msg.senderId) return;
        }

        await MessageListenerService.markNotified(msg.uuid);

        final title = store.nameFor(msg.senderId) ??
            'User ${msg.senderId.substring(0, 8)}';
        await NotificationService.instance.showIncomingMessage(
          peerId: msg.uuid,
          title: title,
          body: msg.previewText.isNotEmpty ? msg.previewText : 'New message',
          force: true,
        );
      },
    );
  }
}
