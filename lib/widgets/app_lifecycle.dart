import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_state.dart';
import '../services/message_listener_service.dart';
import '../services/notification_preferences.dart';
import '../services/notification_service.dart';
import '../services/server_settings.dart';

/// Tracks foreground/background for notifications and the message listener service.
class AppLifecycleBridge extends StatefulWidget {
  final Widget child;

  const AppLifecycleBridge({super.key, required this.child});

  @override
  State<AppLifecycleBridge> createState() => _AppLifecycleBridgeState();
}

class _AppLifecycleBridgeState extends State<AppLifecycleBridge>
    with WidgetsBindingObserver {
  Timer? _backgroundDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncForegroundState(resumed: true);
  }

  @override
  void dispose() {
    _backgroundDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _syncForegroundState({required bool resumed}) async {
    NotificationService.instance.setAppForeground(resumed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_in_foreground', resumed);
    await MessageListenerService.updateAppState(inForeground: resumed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _backgroundDebounce?.cancel();
        _syncForegroundState(resumed: true);
        MessageListenerService.stop();
        if (mounted) {
          context.read<AppState>().onAppResumed();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _backgroundDebounce?.cancel();
        _backgroundDebounce = Timer(
          const Duration(milliseconds: 350),
          _goBackground,
        );
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _syncForegroundState(resumed: false);
        _goBackground();
        break;
    }
  }

  Future<void> _goBackground() async {
    await _syncForegroundState(resumed: false);
    if (!mounted) return;

    final settings = context.read<ServerSettings>();
    if (!settings.isConfigured) return;

    final appState = context.read<AppState>();
    if (!appState.isLoggedIn) return;

    if (NotificationPreferences.isMobilePlatform) {
      final notifPrefs = context.read<NotificationPreferences>();
      await notifPrefs.ensureLoaded();
      if (!notifPrefs.enabled) return;
    }

    // Hand off to foreground listener (uses URLs from Server settings).
    await appState.prepareForBackgroundListener();
    await MessageListenerService.start();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
