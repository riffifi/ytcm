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

class AppTheme {
  static ThemeData themeFor(Brightness brightness) {
    final c =
        brightness == Brightness.light ? AppColors.light : AppColors.dark;

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
      fontFamily: 'ABCDiatype',
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: c.primary,
          fontSize: 27,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.6,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          color: c.primary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          color: c.primary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
        bodyLarge: TextStyle(color: c.primary, fontSize: 15, height: 1.45),
        bodyMedium: TextStyle(color: c.secondary, fontSize: 13, height: 1.4),
        labelSmall: TextStyle(
          color: c.tertiary,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
      dividerColor: c.borderSoft,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: c.primary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: c.secondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceHigh,
        contentTextStyle: TextStyle(color: c.primary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceHigh,
        hintStyle: TextStyle(color: c.tertiary, fontSize: 15),
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
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get dark => themeFor(Brightness.dark);
  static ThemeData get light => themeFor(Brightness.light);

  static SystemUiOverlayStyle overlayFor(Brightness brightness) {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          brightness == Brightness.light ? Brightness.dark : Brightness.light,
    );
  }
}
