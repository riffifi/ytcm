import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleOption {
  final String code;
  final String label;

  const LocaleOption({required this.code, required this.label});
}

/// Loads `assets/l10n/strings_<code>.json`, discovers locales via [AssetManifest.json].
class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'locale_code';
  static final _fileRe = RegExp(r'^assets/l10n/strings_([a-zA-Z-]+)\.json$');

  final Map<String, Map<String, String>> _cache = {};
  List<String> availableCodes = ['en', 'ru'];
  List<LocaleOption> _availableLocales = const [
    LocaleOption(code: 'en', label: 'English'),
    LocaleOption(code: 'ru', label: 'Русский'),
  ];
  String _code = 'en';
  Map<String, String> _flat = {};

  Locale get locale => Locale(_code);
  String get localeCode => _code;
  List<LocaleOption> get availableLocales => List.unmodifiable(_availableLocales);

  Future<void> init() async {
    await _discoverCodes();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && availableCodes.contains(saved)) {
      _code = saved;
    } else if (availableCodes.isNotEmpty) {
      _code = availableCodes.first;
    }
    await _loadCurrent();
    notifyListeners();
  }

  Future<void> _discoverCodes() async {
    try {
      final raw = await rootBundle.loadString('AssetManifest.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final found = <String>{};
      for (final k in map.keys) {
        final m = _fileRe.firstMatch(k);
        if (m != null) found.add(m.group(1)!);
      }
      if (found.isNotEmpty) {
        availableCodes = found.toList()..sort();
      }
      await _loadLocaleLabels();
    } catch (_) {
      availableCodes = ['en', 'ru'];
      _availableLocales = const [
        LocaleOption(code: 'en', label: 'English'),
        LocaleOption(code: 'ru', label: 'Русский'),
      ];
    }
  }

  Future<void> _loadLocaleLabels() async {
    final labels = <LocaleOption>[];
    for (final code in availableCodes) {
      labels.add(LocaleOption(code: code, label: await _readLocaleLabel(code)));
    }
    if (labels.isNotEmpty) {
      _availableLocales = labels;
    }
  }

  Future<String> _readLocaleLabel(String code) async {
    final path = 'assets/l10n/strings_$code.json';
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final localeNode = decoded['locale'];
        if (localeNode is Map<String, dynamic>) {
          final name = localeNode['name']?.toString().trim();
          if (name != null && name.isNotEmpty) {
            return name;
          }
        }
      }
    } catch (_) {
      // Fall back to the locale code below.
    }
    return code;
  }

  Future<void> setLocale(String code) async {
    if (!availableCodes.contains(code)) return;
    _code = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
    await _loadCurrent();
    notifyListeners();
  }

  Future<void> _loadCurrent() async {
    if (_cache.containsKey(_code)) {
      _flat = _cache[_code]!;
      return;
    }
    final path = 'assets/l10n/strings_$_code.json';
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final flat = <String, String>{};
      void walk(String prefix, Map<String, dynamic> node) {
        node.forEach((k, v) {
          final p = prefix.isEmpty ? k : '$prefix.$k';
          if (v is Map<String, dynamic>) {
            walk(p, v);
          } else if (v != null) {
            flat[p] = v.toString();
          }
        });
      }
      walk('', decoded);
      _cache[_code] = flat;
      _flat = flat;
    } catch (_) {
      _flat = {};
    }
  }

  String t(String key) => _flat[key] ?? key;
}

extension L10nBuildContext on BuildContext {
  String str(String key) {
    final lc = read<LocaleController>();
    return lc.t(key);
  }
}
