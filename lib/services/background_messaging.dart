import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_sync.dart';
import 'notification_preferences.dart';
import 'server_endpoints.dart';

/// Schedules short background inbox checks without keeping the user online.
class BackgroundMessaging {
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<bool> _shouldRun() async {
    if (!isSupported) return false;
    if (!NotificationPreferences.isMobilePlatform) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool(NotificationPreferences.keyEnabled) == false) {
      return false;
    }
    if (!await ServerEndpoints.isConfigured) return false;
    final token = prefs.getString('session_token');
    return token != null && token.isNotEmpty;
  }

  /// Registers periodic work and queues an early inbox check.
  static Future<void> ensureRunning() async {
    if (!await _shouldRun()) return;

    if (BackgroundSync.isSupported) {
      await BackgroundSync.register();
      await BackgroundSync.scheduleSoon();
    }
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    if (BackgroundSync.isSupported) {
      await BackgroundSync.cancel();
    }
  }
}
