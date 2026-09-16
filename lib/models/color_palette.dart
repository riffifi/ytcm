import 'package:flutter/material.dart';

import '../theme.dart';

/// Named accent palettes applied on top of light/dark base themes.
class ColorPaletteOption {
  final String id;
  final String name;
  final Color accent;
  final Color companion;

  const ColorPaletteOption({
    required this.id,
    required this.name,
    required this.accent,
    required this.companion,
  });

  AppColors resolve(Brightness brightness) {
    final base =
        brightness == Brightness.light ? AppColors.light : AppColors.dark;
    return base.withAccent(accent, companion: companion);
  }

  static const defaultId = 'autumn';

  static const presets = <ColorPaletteOption>[
    ColorPaletteOption(
      id: defaultId,
      name: 'Autumn',
      accent: Color(0xFFE87524),
      companion: Color(0xFF8F2438),
    ),
    ColorPaletteOption(
      id: 'marigold',
      name: 'Marigold',
      accent: Color(0xFFE5A62B),
      companion: Color(0xFFC85B19),
    ),
    ColorPaletteOption(
      id: 'maple',
      name: 'Maple',
      accent: Color(0xFFC9582B),
      companion: Color(0xFF7E2639),
    ),
    ColorPaletteOption(
      id: 'moss',
      name: 'Moss',
      accent: Color(0xFF64825E),
      companion: Color(0xFF365B50),
    ),
    ColorPaletteOption(
      id: 'ocean',
      name: 'Ocean',
      accent: Color(0xFF4489C7),
      companion: Color(0xFF315A91),
    ),
    ColorPaletteOption(
      id: 'plum',
      name: 'Plum',
      accent: Color(0xFF9468C5),
      companion: Color(0xFF643E80),
    ),
  ];

  static ColorPaletteOption? byId(String id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }
}

extension AppColorsAccent on AppColors {
  AppColors withAccent(Color accent, {Color? companion}) {
    final isLight = bg.computeLuminance() > 0.5;
    final paired = companion ?? accent;
    final accentSoft = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.14 : 0.22),
      bg,
    );
    final accentDim = Color.alphaBlend(
      paired.withValues(alpha: isLight ? 0.82 : 0.9),
      surfaceHigh,
    );
    final bubbleOut = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.24 : 0.5),
      bg,
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
        paired.withValues(alpha: 0.48),
        border,
      ),
      bubbleIn: bubbleIn,
      bubbleInBorder: bubbleInBorder,
      error: error,
      success: success,
    );
  }
}
