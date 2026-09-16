import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/color_palette.dart';

/// Light/dark mode and accent palette (persisted).
class AppearancePreferences extends ChangeNotifier {
  static const _keyMode = 'theme_mode';
  static const _keyPalette = 'color_palette_id';

  ThemeMode _mode = ThemeMode.system;
  String _paletteId = ColorPaletteOption.defaultId;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  bool get isLoaded => _loaded;

  ColorPaletteOption get palette =>
      ColorPaletteOption.byId(_paletteId) ?? ColorPaletteOption.presets.first;

  Brightness effectiveBrightness(Brightness platformBrightness) =>
      switch (_mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => platformBrightness,
      };

  AppearancePreferences() {
    _load();
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_keyMode);
    if (savedMode == 'light') {
      _mode = ThemeMode.light;
    } else if (savedMode == 'dark') {
      _mode = ThemeMode.dark;
    } else {
      _mode = ThemeMode.system;
    }
    final savedPalette = prefs.getString(_keyPalette);
    if (savedPalette == 'sage') {
      _paletteId = ColorPaletteOption.defaultId;
      await prefs.setString(_keyPalette, _paletteId);
    } else if (savedPalette != null &&
        ColorPaletteOption.byId(savedPalette) != null) {
      _paletteId = savedPalette;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode.name);
    notifyListeners();
  }

  Future<void> setPaletteId(String id) async {
    if (ColorPaletteOption.byId(id) == null) return;
    _paletteId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPalette, id);
    notifyListeners();
  }
}
