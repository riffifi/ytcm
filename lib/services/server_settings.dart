import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'server_endpoints.dart';

class ServerSettings extends ChangeNotifier {
  static const _keyTenor = 'tenor_api_key';

  /// Local dev defaults — never used on Android/iOS unless saved in prefs.
  static String get desktopAuthDefault => ServerEndpoints.desktopAuthDefault;
  static String get desktopChatDefault => ServerEndpoints.desktopChatDefault;
  static String get desktopFileDefault => ServerEndpoints.desktopFileDefault;

  String _authUrl = '';
  String _chatUrl = '';
  String _fileUrl = '';
  String? _tenorApiKey;
  bool _loaded = false;
  final Completer<void> _loadCompleter = Completer<void>();

  String get authUrl => _authUrl;
  String get chatUrl => _chatUrl;
  String get fileUrl => _fileUrl;
  String? get tenorApiKey => _tenorApiKey;
  bool get isLoaded => _loaded;

  bool get isConfigured =>
      _authUrl.isNotEmpty && _chatUrl.isNotEmpty && _fileUrl.isNotEmpty;

  bool get usesLocalhost =>
      _authUrl.contains('127.0.0.1') ||
      _authUrl.contains('localhost') ||
      _chatUrl.contains('127.0.0.1') ||
      _chatUrl.contains('localhost') ||
      _fileUrl.contains('127.0.0.1') ||
      _fileUrl.contains('localhost');

  ServerSettings() {
    _load();
  }

  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedAuth = prefs.getString(ServerEndpoints.prefsKeyAuth)?.trim();
      final storedChat = prefs.getString(ServerEndpoints.prefsKeyChat)?.trim();
      final storedFile = prefs.getString(ServerEndpoints.prefsKeyFile)?.trim();

      if (storedAuth != null && storedAuth.isNotEmpty) {
        _authUrl = _normalizeHttpUrl(storedAuth);
      } else if (_allowDesktopDefaults) {
        _authUrl = desktopAuthDefault;
      }

      if (storedChat != null && storedChat.isNotEmpty) {
        _chatUrl = _normalizeWebSocketUrl(storedChat);
      } else if (_allowDesktopDefaults) {
        _chatUrl = desktopChatDefault;
      }

      if (storedFile != null && storedFile.isNotEmpty) {
        _fileUrl = _normalizeWebSocketUrl(storedFile);
      } else if (_allowDesktopDefaults) {
        _fileUrl = desktopFileDefault;
      }

      _tenorApiKey = prefs.getString(_keyTenor);
    } finally {
      _loaded = true;
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      notifyListeners();
    }
  }

  bool get _allowDesktopDefaults {
    return true;
  }

  Future<void> save(
    String authUrl,
    String chatUrl,
    String fileUrl, {
    String? tenorApiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _authUrl = _normalizeHttpUrl(authUrl);
    _chatUrl = _normalizeWebSocketUrl(chatUrl);
    _fileUrl = _normalizeWebSocketUrl(fileUrl);
    final tenor = tenorApiKey?.trim();
    _tenorApiKey = (tenor == null || tenor.isEmpty) ? null : tenor;
    await prefs.setString(ServerEndpoints.prefsKeyAuth, _authUrl);
    await prefs.setString(ServerEndpoints.prefsKeyChat, _chatUrl);
    await prefs.setString(ServerEndpoints.prefsKeyFile, _fileUrl);
    if (_tenorApiKey != null) {
      await prefs.setString(_keyTenor, _tenorApiKey!);
    } else {
      await prefs.remove(_keyTenor);
    }
    notifyListeners();
  }

  static String _normalizeHttpUrl(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  static String _normalizeWebSocketUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return trimmed;
    if (uri.path.isEmpty || uri.path == '/') {
      return uri.replace(path: '/ws').toString();
    }
    return uri.toString();
  }

  Future<void> reset() async {
    if (_allowDesktopDefaults) {
      await save(
        desktopAuthDefault,
        desktopChatDefault,
        desktopFileDefault,
        tenorApiKey: '',
      );
    } else {
      await save('', '', '', tenorApiKey: '');
    }
  }
}
