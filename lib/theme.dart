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
    bg: Color(0xFF0E0F12),
    surface: Color(0xFF17191E),
    surfaceHigh: Color(0xFF202329),
    border: Color(0xFF30333B),
    borderSoft: Color(0xFF24272E),
    primary: Color(0xFFF7F2E9),
    secondary: Color(0xFFAAA7A2),
    tertiary: Color(0xFF6F7077),
    accent: Color(0xFFE87524),
    accentSoft: Color(0xFF352216),
    accentDim: Color(0xFFA94F16),
    bubbleOut: Color(0xFF9E4816),
    bubbleOutBorder: Color(0xFFC45E1C),
    bubbleIn: Color(0xFF1C1F25),
    bubbleInBorder: Color(0xFF30343D),
    error: Color(0xFFFF716D),
    success: Color(0xFF67C587),
  );

  static const light = AppColors(
    bg: Color(0xFFF4F0E8),
    surface: Color(0xFFFFFCF7),
    surfaceHigh: Color(0xFFECE7DE),
    border: Color(0xFFD8D1C5),
    borderSoft: Color(0xFFE7E1D7),
    primary: Color(0xFF1C1B1A),
    secondary: Color(0xFF65615C),
    tertiary: Color(0xFF969087),
    accent: Color(0xFFD75F10),
    accentSoft: Color(0xFFFFE7D2),
    accentDim: Color(0xFFAD4708),
    bubbleOut: Color(0xFFFFD4AD),
    bubbleOutBorder: Color(0xFFF2B67D),
    bubbleIn: Color(0xFFFFFCF7),
    bubbleInBorder: Color(0xFFD8D1C5),
    error: Color(0xFFC83E3A),
    success: Color(0xFF27814A),
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

abstract final class AppRadius {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const tail = 7.0;
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 180);
  static const enter = Duration(milliseconds: 220);
  static const theme = Duration(milliseconds: 260);
  static const standard = Curves.easeOutCubic;
  static const emphasized = Curves.easeOutBack;
}

abstract final class AppShadow {
  static List<BoxShadow> level1(AppColors c) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> level2(AppColors c) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 32,
          offset: const Offset(0, 14),
        ),
      ];

  static List<BoxShadow> accentGlow(AppColors c) => [
        BoxShadow(
          color: c.accent.withValues(alpha: 0.18),
          blurRadius: 36,
        ),
      ];
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
  static TextStyle heading(AppColors c, {double fontSize = 28}) => text(
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

  static TextStyle caption(AppColors c, {Color? color}) => text(
        c,
        color: color ?? c.secondary,
        fontSize: 12,
        wght: 450,
        height: 1.35,
      );

  static TextStyle listTitle(AppColors c, {bool emphasized = false}) => text(
        c,
        fontSize: 15,
        wght: emphasized ? AppFontWeight.semibold : AppFontWeight.medium,
        height: 1.2,
      );

  static TextStyle timestamp(AppColors c, {Color? color}) => text(
        c,
        color: color ?? c.tertiary,
        fontSize: 11,
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
              secondary: c.accentDim,
              error: c.error,
              onError: Colors.white,
              onSurface: c.primary,
            )
          : ColorScheme.dark(
              surface: c.surface,
              primary: c.accent,
              onPrimary: Colors.white,
              secondary: c.accentDim,
              error: c.error,
              onError: Colors.white,
              onSurface: c.primary,
            ),
      fontFamily: fontFamily,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: c.borderSoft,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.28),
        selectionHandleColor: c.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : c.tertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.accent : c.border,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: 64,
        titleTextStyle: appBarTitle(c),
        iconTheme: IconThemeData(color: c.secondary, size: 22),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceHigh,
        contentTextStyle: text(c, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: appBarTitle(c),
        contentTextStyle: text(c, fontSize: 15, height: 1.45),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: c.borderSoft),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text(c, fontSize: 15, wght: AppFontWeight.medium),
        subtitleTextStyle:
            text(c, color: c.secondary, fontSize: 13, height: 1.35),
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
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
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
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: text(c, fontSize: 14, wght: AppFontWeight.semibold),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accentSoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? c.accent : c.tertiary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text(
            c,
            color: selected ? c.accent : c.tertiary,
            fontSize: 11,
            wght: selected ? AppFontWeight.semibold : AppFontWeight.medium,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.accentSoft,
        selectedIconTheme: IconThemeData(color: c.accent, size: 22),
        unselectedIconTheme: IconThemeData(color: c.tertiary, size: 22),
        selectedLabelTextStyle: text(
          c,
          color: c.accent,
          fontSize: 12,
          wght: AppFontWeight.semibold,
        ),
        unselectedLabelTextStyle: text(
          c,
          color: c.tertiary,
          fontSize: 12,
          wght: AppFontWeight.medium,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceHigh,
        selectedColor: c.accentSoft,
        side: BorderSide(color: c.borderSoft),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        labelStyle: text(c, fontSize: 13, wght: AppFontWeight.medium),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }

  static ThemeData dark([AppColors? palette]) =>
      themeFor(Brightness.dark, palette);
  static ThemeData light([AppColors? palette]) =>
      themeFor(Brightness.light, palette);

  static SystemUiOverlayStyle overlayFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          dark ? AppColors.dark.surface : AppColors.light.surface,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }
}
