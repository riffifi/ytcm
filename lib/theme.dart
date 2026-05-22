import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color borderSoft;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color accent;
  final Color accentSoft;
  final Color accentDim;
  final Color bubbleOut;
  final Color bubbleOutBorder;
  final Color bubbleIn;
  final Color bubbleInBorder;
  final Color error;
  final Color success;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.borderSoft,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.accent,
    required this.accentSoft,
    required this.accentDim,
    required this.bubbleOut,
    required this.bubbleOutBorder,
    required this.bubbleIn,
    required this.bubbleInBorder,
    required this.error,
    required this.success,
  });

  static const dark = AppColors(
    bg: Color(0xFF131614),
    surface: Color(0xFF1C1F1E),
    surfaceHigh: Color(0xFF252928),
    border: Color(0xFF2E3230),
    borderSoft: Color(0xFF242726),
    primary: Color(0xFFE3E6E4),
    secondary: Color(0xFF878F8C),
    tertiary: Color(0xFF545C59),
    accent: Color(0xFF5B9E8F),
    accentSoft: Color(0xFF1A2825),
    accentDim: Color(0xFF3D7066),
    bubbleOut: Color(0xFF1E2E2B),
    bubbleOutBorder: Color(0xFF2D4A44),
    bubbleIn: Color(0xFF1C1F1E),
    bubbleInBorder: Color(0xFF2A2E2C),
    error: Color(0xFFE07070),
    success: Color(0xFF5FA876),
  );

  static const light = AppColors(
    bg: Color(0xFFF7F8F7),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF0F2F1),
    border: Color(0xFFD8DEDC),
    borderSoft: Color(0xFFE8EBEA),
    primary: Color(0xFF1A1D1C),
    secondary: Color(0xFF5C6562),
    tertiary: Color(0xFF8A9490),
    accent: Color(0xFF2D7A6A),
    accentSoft: Color(0xFFE4F2EF),
    accentDim: Color(0xFF236657),
    bubbleOut: Color(0xFFDCEFEA),
    bubbleOutBorder: Color(0xFFB8DDD4),
    bubbleIn: Color(0xFFFFFFFF),
    bubbleInBorder: Color(0xFFD8DEDC),
    error: Color(0xFFC44B4B),
    success: Color(0xFF3D8B55),
  );
}

class MessengerColors extends ThemeExtension<MessengerColors> {
  final AppColors palette;

  const MessengerColors(this.palette);

  @override
  MessengerColors copyWith({AppColors? palette}) =>
      MessengerColors(palette ?? this.palette);

  @override
  MessengerColors lerp(ThemeExtension<MessengerColors>? other, double t) {
    if (other is! MessengerColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension MessengerTheme on BuildContext {
  AppColors get mc {
    final ext = Theme.of(this).extension<MessengerColors>();
    if (ext != null) return ext.palette;
    return Theme.of(this).brightness == Brightness.light
        ? AppColors.light
        : AppColors.dark;
  }
}

/// Geist variable-font weight tokens ([wght] axis, 100–900).
abstract final class AppFontWeight {
  static const body = 400.0;
  static const medium = 500.0;
  static const semibold = 560.0;
  static const tab = 580.0;
  static const button = 580.0;
  /// App bar / chat header titles — between w600 and w700.
  static const appBar = 620.0;
  /// Large screen titles (e.g. Messages).
  static const heading = 680.0;
  /// Marketing / auth hero.
  static const display = 720.0;
}

class AppTheme {
  static const fontFamily = 'Geist';

  static FontWeight _nearestFontWeight(double wght) {
    if (wght >= 700) return FontWeight.w700;
    if (wght >= 600) return FontWeight.w600;
    if (wght >= 500) return FontWeight.w500;
    if (wght >= 300) return FontWeight.w300;
    return FontWeight.w400;
  }

  /// Base [TextStyle] with Geist [wght] axis (variable font).
  static TextStyle text(
    AppColors c, {
    Color? color,
    double fontSize = 15,
    double wght = AppFontWeight.body,
    double? letterSpacing,
    double? height,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontVariations: [FontVariation.weight(wght.clamp(100.0, 900.0))],
      fontWeight: _nearestFontWeight(wght),
      color: color ?? c.primary,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
    );
  }

  /// Toolbar / navigation bar title.
  static TextStyle appBarTitle(AppColors c, {double fontSize = 17}) => text(
        c,
        wght: AppFontWeight.appBar,
        fontSize: fontSize,
        letterSpacing: -0.12,
        height: 1.15,
      );

  /// Primary screen title (conversation list, settings page, etc.).
  static TextStyle heading(AppColors c, {double fontSize = 22}) => text(
        c,
        wght: AppFontWeight.heading,
        fontSize: fontSize,
        letterSpacing: -0.06,
        height: 1.1,
      );

  /// Large marketing line (auth splash).
  static TextStyle display(AppColors c, {double fontSize = 27}) => text(
        c,
        wght: AppFontWeight.display,
        fontSize: fontSize,
        letterSpacing: -0.04,
        height: 1.2,
      );

  /// Uppercase section labels in settings / profile.
  static TextStyle sectionLabel(AppColors c) => text(
        c,
        wght: AppFontWeight.semibold,
        color: c.secondary,
        fontSize: 11,
        letterSpacing: 0.85,
        height: 1.2,
      );

  static TextTheme _textTheme(AppColors c, Brightness brightness) {
    final base = brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white;
    return base
        .apply(
          fontFamily: fontFamily,
          bodyColor: c.primary,
          displayColor: c.primary,
        )
        .copyWith(
          displayLarge: display(c),
          titleLarge: appBarTitle(c),
          titleMedium: text(
            c,
            wght: AppFontWeight.medium,
            fontSize: 15,
            letterSpacing: -0.08,
          ),
          bodyLarge: text(c, fontSize: 15, height: 1.45),
          bodyMedium: text(
            c,
            color: c.secondary,
            fontSize: 13,
            wght: 430,
            height: 1.4,
          ),
          labelSmall: text(
            c,
            color: c.tertiary,
            fontSize: 11,
            wght: 450,
            letterSpacing: 0.35,
          ),
        );
  }

  static ThemeData themeFor(Brightness brightness, [AppColors? palette]) {
    final c = palette ??
        (brightness == Brightness.light ? AppColors.light : AppColors.dark);
    final textTheme = _textTheme(c, brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      extensions: [MessengerColors(c)],
      colorScheme: brightness == Brightness.light
          ? ColorScheme.light(
              surface: c.surface,
              primary: c.accent,
              onPrimary: Colors.white,
              secondary: c.accent,
              error: c.error,
              onError: Colors.white,
              onSurface: c.primary,
            )
          : ColorScheme.dark(
              surface: c.surface,
              primary: c.accent,
              onPrimary: Colors.white,
              secondary: c.accent,
              error: c.error,
              onError: Colors.white,
              onSurface: c.primary,
            ),
      fontFamily: fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: c.borderSoft,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: 52,
        titleTextStyle: appBarTitle(c),
        iconTheme: IconThemeData(color: c.secondary, size: 22),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceHigh,
        contentTextStyle: text(c, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: appBarTitle(c),
        contentTextStyle: text(c, fontSize: 15, height: 1.45),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text(c, fontSize: 15, wght: AppFontWeight.medium),
        subtitleTextStyle: text(c, color: c.secondary, fontSize: 13, height: 1.35),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: text(c, fontSize: 14, wght: AppFontWeight.tab),
        unselectedLabelStyle: text(
          c,
          color: c.secondary,
          fontSize: 14,
          wght: 450,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceHigh,
        hintStyle: text(c, color: c.tertiary, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          maxWidth: 40,
          minHeight: 24,
          maxHeight: 24,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          maxWidth: 40,
          minHeight: 24,
          maxHeight: 24,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: text(
            c,
            color: Colors.white,
            fontSize: 15,
            wght: AppFontWeight.button,
            letterSpacing: 0.06,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: text(
            c,
            color: c.accent,
            fontSize: 14,
            wght: AppFontWeight.medium,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData dark([AppColors? palette]) => themeFor(Brightness.dark, palette);
  static ThemeData light([AppColors? palette]) =>
      themeFor(Brightness.light, palette);

  static SystemUiOverlayStyle overlayFor(Brightness brightness) {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          brightness == Brightness.light ? Brightness.dark : Brightness.light,
    );
  }
}
