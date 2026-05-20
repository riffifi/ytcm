import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerSettings extends ChangeNotifier {
  static const _keyAuth = 'server_auth_url';
  static const _keyChat = 'server_chat_url';
  static const _keyFile = 'server_file_ws_url';

  static String get defaultAuthUrl =>
      'https://auth.yechat.ru';

  static String get defaultChatUrl =>
      'wss://msg.yechat.ru/ws';

  static String get defaultFileWsUrl =>
      'wss://file.yechat.ru/ws';

  String _authUrl = defaultAuthUrl;
  String _chatUrl = defaultChatUrl;
  String _fileWsUrl = defaultFileWsUrl;
  bool _loaded = false;
  final Completer<void> _loadCompleter = Completer<void>();

  String get authUrl => _authUrl;
  String get chatUrl => _chatUrl;
  String get fileWsUrl => _fileWsUrl;
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
      _fileWsUrl = prefs.getString(_keyFile) ?? defaultFileWsUrl;
    } finally {
      _loaded = true;
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      notifyListeners();
    }
  }

  Future<void> save(String authUrl, String chatUrl, String fileWsUrl) async {
    final prefs = await SharedPreferences.getInstance();
    _authUrl = authUrl.trim();
    _chatUrl = chatUrl.trim();
    _fileWsUrl = fileWsUrl.trim();
    await prefs.setString(_keyAuth, _authUrl);
    await prefs.setString(_keyChat, _chatUrl);
    await prefs.setString(_keyFile, _fileWsUrl);
    notifyListeners();
  }

  Future<void> reset() async {
    await save(defaultAuthUrl, defaultChatUrl, defaultFileWsUrl);
  }
}
