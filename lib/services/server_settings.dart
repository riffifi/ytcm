import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerSettings extends ChangeNotifier {
  static const _keyAuth = 'server_auth_url';
  static const _keyChat = 'server_chat_url';

  static String get defaultAuthUrl =>
      (!kIsWeb && Platform.isAndroid)
          ? 'http://10.0.2.2:3000'
          : 'http://127.0.0.1:3000';

  static String get defaultChatUrl =>
      (!kIsWeb && Platform.isAndroid)
          ? 'ws://10.0.2.2:3001/ws'
          : 'ws://127.0.0.1:3001/ws';

  String _authUrl = defaultAuthUrl;
  String _chatUrl = defaultChatUrl;
  bool _loaded = false;
  final Completer<void> _loadCompleter = Completer<void>();

  String get authUrl => _authUrl;
  String get chatUrl => _chatUrl;
  bool get isLoaded => _loaded;

  ServerSettings() {
    _load();
  }

  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authUrl = prefs.getString(_keyAuth) ?? defaultAuthUrl;
      _chatUrl = prefs.getString(_keyChat) ?? defaultChatUrl;
    } finally {
      _loaded = true;
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      notifyListeners();
    }
  }

  Future<void> save(String authUrl, String chatUrl) async {
    final prefs = await SharedPreferences.getInstance();
    _authUrl = authUrl.trim();
    _chatUrl = chatUrl.trim();
    await prefs.setString(_keyAuth, _authUrl);
    await prefs.setString(_keyChat, _chatUrl);
    notifyListeners();
  }

  Future<void> reset() async {
    await save(defaultAuthUrl, defaultChatUrl);
  }
}
