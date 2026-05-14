import 'package:flutter/material.dart';

class AppTheme {
  // Palette — warm dark, easy on eyes
  //
  // Background: very slightly warm near-black (not pure #000, not cold blue-black)
  // Surfaces: layered warm grays with low contrast steps
  // Accent: desaturated teal-blue — readable, not aggressive
  // Text: off-white primary, warm mid-gray secondary
  // Borders: barely-there, only for structure
  // Bubbles: outgoing = deep teal-black tint, incoming = warm surface

  static const bg          = Color(0xFF131614); // warm near-black, hint of green-gray
  static const surface     = Color(0xFF1C1F1E); // slightly lifted, still warm
  static const surfaceHigh = Color(0xFF252928); // inputs, chips
  static const border      = Color(0xFF2E3230); // very subtle border
  static const borderSoft  = Color(0xFF242726); // even softer — dividers

  static const primary   = Color(0xFFE3E6E4); // off-white, warm cast
  static const secondary = Color(0xFF878F8C); // warm mid-gray, readable
  static const tertiary  = Color(0xFF545C59); // timestamps, labels

  // Accent: muted sage-teal — calm, not electric
  static const accent     = Color(0xFF5B9E8F);
  static const accentSoft = Color(0xFF1A2825); // accent tinted bg for badges/info
  static const accentDim  = Color(0xFF3D7066); // pressed state / subtle

  // Message bubbles
  static const bubbleOut    = Color(0xFF1E2E2B); // outgoing: deep teal tint
  static const bubbleOutBorder = Color(0xFF2D4A44);
  static const bubbleIn     = Color(0xFF1C1F1E); // incoming: same as surface
  static const bubbleInBorder  = Color(0xFF2A2E2C);

  static const error   = Color(0xFFE07070); // softer red
  static const success = Color(0xFF5FA876);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          surface: surface,
          primary: accent,
          onPrimary: Colors.white,
          secondary: accent,
          error: error,
          onError: Colors.white,
        ),
        fontFamily: 'ABCDiatype',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              color: primary,
              fontSize: 27,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.6,
              height: 1.2),
          titleLarge: TextStyle(
              color: primary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2),
          titleMedium: TextStyle(
              color: primary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1),
          bodyLarge: TextStyle(
              color: primary, fontSize: 15, height: 1.45),
          bodyMedium: TextStyle(
              color: secondary, fontSize: 13, height: 1.4),
          labelSmall: TextStyle(
              color: tertiary, fontSize: 11, letterSpacing: 0.4),
        ),
        dividerColor: borderSoft,
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          iconTheme: IconThemeData(color: secondary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceHigh,
          hintStyle: const TextStyle(color: tertiary, fontSize: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13)),
            textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accent,
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      );
}
