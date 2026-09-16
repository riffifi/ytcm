import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'background_state.dart';
import 'chat_socket_runner.dart';
import 'conversation_store.dart';
import 'notification_preferences.dart';
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

/// Short inbox checks scheduled by Android/iOS background task APIs.
class BackgroundSync {
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool _registered = false;
  static bool _initialized = false;

  static Future<void> register() async {
    if (!isSupported || _registered) return;
    if (!await ServerEndpoints.isConfigured) return;
    if (!_initialized) {
      await Workmanager().initialize(backgroundSyncDispatcher);
      _initialized = true;
    }
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

    final prefs = await BackgroundState.freshPreferences();
    final endpoints = await ServerEndpoints.fromPrefs();
    final chatUrl = endpoints.chatUrl;
    if (chatUrl == null) return;

    if (prefs.getBool(NotificationPreferences.keyEnabled) == false) return;
    if (prefs.getBool(BackgroundState.appInForegroundKey) == true) return;

    final token = prefs.getString('session_token');
    if (token == null || token.isEmpty) return;

    final myUuid = prefs.getString('user_uuid');

    await NotificationService.instance.init();
    NotificationService.instance.setAppForeground(false);
    if (!await NotificationService.instance.areNotificationsEnabled()) return;

    final store = ConversationStore();
    if (myUuid != null && myUuid.isNotEmpty) {
      await store.setUserScope(myUuid);
    } else {
      await store.load();
    }

    Future<void> notify({
      required String messageId,
      required String notificationPeerId,
      required String title,
      required String body,
    }) async {
      await prefs.reload();
      if (prefs.getBool(BackgroundState.appInForegroundKey) == true) return;
      if (BackgroundState.alreadyNotified(prefs, messageId)) return;
      final shown = await NotificationService.instance.showIncomingMessage(
        peerId: notificationPeerId,
        title: title,
        body: body,
        force: true,
      );
      if (shown) {
        await BackgroundState.markNotified(prefs, messageId);
      }
    }

    await ChatSocketRunner.listen(
      chatUrl: chatUrl,
      sessionToken: token,
      maxDuration: const Duration(seconds: 12),
      stopAfterIdle: const Duration(seconds: 2),
      shouldStop: () => false,
      onLiveMessage: (msg) async {
        if (myUuid != null && msg.senderId == myUuid) return;
        final title =
            store.nameFor(msg.senderId) ?? 'User ${_shortId(msg.senderId)}';
        await notify(
          messageId: msg.uuid,
          notificationPeerId: msg.senderId,
          title: title,
          body: msg.previewText.isNotEmpty ? msg.previewText : 'New message',
        );
      },
      onGroupMessage: (msg) async {
        if (myUuid != null && msg.senderId == myUuid) return;
        final sender =
            store.nameFor(msg.senderId) ?? 'User ${_shortId(msg.senderId)}';
        final preview =
            msg.previewText.isNotEmpty ? msg.previewText : 'New message';
        await notify(
          messageId: msg.uuid,
          notificationPeerId: 'group:${msg.groupId}',
          title: 'Group message',
          body: '$sender: $preview',
        );
      },
    );
  }

  static String _shortId(String value) =>
      value.length > 8 ? value.substring(0, 8) : value;
}
