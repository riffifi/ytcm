import 'package:flutter/material.dart';

import '../theme.dart';

/// Named accent palettes applied on top of light/dark base themes.
class ColorPaletteOption {
  final String id;
  final String name;
  final Color accent;

  const ColorPaletteOption({
    required this.id,
    required this.name,
    required this.accent,
  });

  AppColors resolve(Brightness brightness) {
    final base =
        brightness == Brightness.light ? AppColors.light : AppColors.dark;
    return base.withAccent(accent);
  }

  static const presets = <ColorPaletteOption>[
    ColorPaletteOption(id: 'sage', name: 'Sage', accent: Color(0xFF5B9E8F)),
    ColorPaletteOption(id: 'ocean', name: 'Ocean', accent: Color(0xFF4A8FD4)),
    ColorPaletteOption(id: 'plum', name: 'Plum', accent: Color(0xFF9B6ED0)),
    ColorPaletteOption(id: 'coral', name: 'Coral', accent: Color(0xFFE07A5F)),
    ColorPaletteOption(id: 'amber', name: 'Amber', accent: Color(0xFFD4A03C)),
    ColorPaletteOption(id: 'rose', name: 'Rose', accent: Color(0xFFE05A8A)),
  ];

  static ColorPaletteOption? byId(String id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }
}

extension AppColorsAccent on AppColors {
  AppColors withAccent(Color accent) {
    final isLight = bg.computeLuminance() > 0.5;
    final accentSoft = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.14 : 0.22),
      bg,
    );
    final accentDim = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.35 : 0.45),
      surfaceHigh,
    );
    final bubbleOut = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.18 : 0.28),
      isLight ? const Color(0xFFF7F8F7) : const Color(0xFF131614),
    );
    return AppColors(
      bg: bg,
      surface: surface,
      surfaceHigh: surfaceHigh,
      border: border,
      borderSoft: borderSoft,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      accent: accent,
      accentSoft: accentSoft,
      accentDim: accentDim,
      bubbleOut: bubbleOut,
      bubbleOutBorder: Color.alphaBlend(
        accent.withValues(alpha: 0.35),
        border,
      ),
      bubbleIn: bubbleIn,
      bubbleInBorder: bubbleInBorder,
      error: error,
      success: success,
    );
  }
}
