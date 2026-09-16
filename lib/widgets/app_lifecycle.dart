import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/background_messaging.dart';
import '../services/background_state.dart';
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
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncForegroundState(resumed: true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !NotificationPreferences.isMobilePlatform) return;
      final preferences = context.read<NotificationPreferences>();
      await preferences.ensureLoaded();
      if (preferences.enabled) {
        final granted = await NotificationService.instance.requestPermission();
        if (!granted) await preferences.setEnabled(false);
      }
    });
  }

  @override
  void dispose() {
    _backgroundDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _syncForegroundState({required bool resumed}) async {
    _isForeground = resumed;
    NotificationService.instance.setAppForeground(resumed);
    await BackgroundState.updateAppState(inForeground: resumed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _backgroundDebounce?.cancel();
        _syncForegroundState(resumed: true);
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
    if (_isForeground) return;
    await _syncForegroundState(resumed: false);
    if (!mounted || _isForeground) return;

    final settings = context.read<ServerSettings>();
    if (!settings.isConfigured) return;

    final appState = context.read<AppState>();
    if (!appState.isLoggedIn) return;
    final notifPrefs = NotificationPreferences.isMobilePlatform
        ? context.read<NotificationPreferences>()
        : null;

    // The UI socket is the server's online-presence signal. Close it before
    // scheduling brief inbox checks so the account remains visibly offline.
    await appState.prepareForBackgroundNotifications();
    if (_isForeground) {
      await appState.onAppResumed();
      return;
    }

    if (notifPrefs != null) {
      await notifPrefs.ensureLoaded();
      if (!notifPrefs.enabled) return;
    }

    await BackgroundMessaging.ensureRunning();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
