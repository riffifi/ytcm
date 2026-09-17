import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'services/appearance_preferences.dart';
import 'services/messenger_log.dart';
import 'services/notification_preferences.dart';
import 'services/notification_service.dart';
import 'services/server_settings.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'theme.dart';
import 'widgets/app_lifecycle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final serverSettings = ServerSettings();
    final appearance = AppearancePreferences();
    final notificationPrefs = NotificationPreferences();
    final messengerLog = MessengerLog();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: serverSettings),
        ChangeNotifierProvider.value(value: appearance),
        ChangeNotifierProvider.value(value: notificationPrefs),
        ChangeNotifierProvider.value(value: messengerLog),
        ChangeNotifierProvider(
          create: (_) => AppState(
            serverSettings: serverSettings,
            log: messengerLog,
          ),
        ),
      ],
      child: Consumer<AppearancePreferences>(
        builder: (_, appearance, __) {
          final palette = appearance.palette;
          final lightPalette = palette.resolve(Brightness.light);
          final darkPalette = palette.resolve(Brightness.dark);
          final brightness = appearance.effectiveBrightness(
            MediaQuery.platformBrightnessOf(context),
          );

          SystemChrome.setSystemUIOverlayStyle(
            AppTheme.overlayFor(brightness),
          );

          return MaterialApp(
            title: 'YeChat',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(lightPalette),
            darkTheme: AppTheme.dark(darkPalette),
            themeMode: appearance.mode,
            themeAnimationDuration: AppMotion.theme,
            themeAnimationCurve: AppMotion.standard,
            builder: (context, child) {
              final theme = Theme.of(context);
              return DefaultTextStyle(
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const AppLifecycleBridge(child: _Bootstrap()),
          );
        },
      ),
    );
  }
}

class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ServerSettings>();
    final c = context.mc;
    if (!settings.isLoaded) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: CircularProgressIndicator(color: c.accent),
        ),
      );
    }
    return const _Root();
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = context.mc;

    if (!state.sessionChecked) {
      return Scaffold(
        key: const ValueKey('session-check'),
        backgroundColor: c.bg,
        body: Center(
          child: CircularProgressIndicator(color: c.accent),
        ),
      );
    }

    if (state.isLoggedIn) {
      return const HomeShell(key: ValueKey('home'));
    }

    return const AuthScreen(key: ValueKey('auth'));
  }
}
