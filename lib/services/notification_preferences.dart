import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preference for push-style local notifications (mobile).
class NotificationPreferences extends ChangeNotifier {
  static const keyEnabled = 'notifications_enabled';

  bool _enabled = true;
  bool _loaded = false;

  static bool get isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  bool get enabled => _enabled;
  bool get isLoaded => _loaded;

  NotificationPreferences() {
    _load();
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(keyEnabled) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyEnabled, value);
    notifyListeners();
  }
}
