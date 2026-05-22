import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'background_sync.dart';
import 'message_listener_service.dart';
import 'notification_preferences.dart';
import 'server_endpoints.dart';

/// Keeps chat WebSocket + auth "online" while logged in (Android).
class BackgroundMessaging {
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<bool> _shouldRun() async {
    if (!isSupported) return false;
    if (!NotificationPreferences.isMobilePlatform) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notifications_enabled') == false) return false;
    if (!await ServerEndpoints.isConfigured) return false;
    final token = prefs.getString('session_token');
    return token != null && token.isNotEmpty;
  }

  /// Starts (or keeps) the foreground listener while notifications are enabled.
  static Future<void> ensureRunning() async {
    if (!await _shouldRun()) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token')!;
    await prefs.setBool('listener_wanted', true);
    await _markAuthOnline(prefs, token);

    if (Platform.isAndroid) {
      await MessageListenerService.configure();
      await MessageListenerService.start();
    }

    if (BackgroundSync.isSupported) {
      await BackgroundSync.register();
      await BackgroundSync.scheduleSoon();
    }
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    if (Platform.isAndroid) {
      await MessageListenerService.stop();
    }
    if (BackgroundSync.isSupported) {
      await BackgroundSync.cancel();
    }
  }

  static Future<void> _markAuthOnline(
    SharedPreferences prefs,
    String token,
  ) async {
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
}
