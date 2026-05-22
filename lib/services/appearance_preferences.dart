import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/color_palette.dart';
import '../theme.dart';

/// Light/dark mode and accent palette (persisted).
class AppearancePreferences extends ChangeNotifier {
  static const _keyMode = 'theme_mode';
  static const _keyPalette = 'color_palette_id';

  ThemeMode _mode = ThemeMode.dark;
  String _paletteId = ColorPaletteOption.presets.first.id;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  bool get isLight => _mode == ThemeMode.light;
  bool get isLoaded => _loaded;

  ColorPaletteOption get palette =>
      ColorPaletteOption.byId(_paletteId) ?? ColorPaletteOption.presets.first;

  AppColors get colors => palette.resolve(
        isLight ? Brightness.light : Brightness.dark,
      );

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
    }
    final savedPalette = prefs.getString(_keyPalette);
    if (savedPalette != null && ColorPaletteOption.byId(savedPalette) != null) {
      _paletteId = savedPalette;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLight(bool light) async {
    _mode = light ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, light ? 'light' : 'dark');
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
