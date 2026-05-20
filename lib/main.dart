import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'services/locale_controller.dart';
import 'services/messenger_notifications.dart';
import 'services/server_settings.dart';
import 'services/theme_preferences.dart';
import 'screens/auth_screen.dart';
import 'screens/conversations_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MessengerNotifications.init();
  final localeController = LocaleController();
  await localeController.init();
  runApp(App(localeController: localeController));
}

class App extends StatelessWidget {
  const App({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final serverSettings = ServerSettings();
    final themePrefs = ThemePreferences();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: serverSettings),
        ChangeNotifierProvider.value(value: themePrefs),
        ChangeNotifierProvider.value(value: localeController),
        ChangeNotifierProvider(
          create: (_) => AppState(
            serverSettings: serverSettings,
            localeController: localeController,
          ),
        ),
      ],
      child: Consumer2<ThemePreferences, LocaleController>(
        builder: (_, themePrefs, locale, __) {
          SystemChrome.setSystemUIOverlayStyle(
            AppTheme.overlayFor(
              themePrefs.isLight ? Brightness.light : Brightness.dark,
            ),
          );

          return MaterialApp(
            title: locale.t('app.title'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themePrefs.mode,
            locale: locale.locale,
            supportedLocales:
                locale.availableCodes.map((c) => Locale(c)).toList(),
            home: const _Bootstrap(),
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: state.isLoggedIn
          ? const ConversationsScreen(key: ValueKey('conversations'))
          : const AuthScreen(key: ValueKey('auth')),
    );
  }
}
