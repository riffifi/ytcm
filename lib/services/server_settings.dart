import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerSettings extends ChangeNotifier {
  static const _keyAuth = 'server_auth_url';
  static const _keyChat = 'server_chat_url';

  static const defaultAuthUrl = 'http://127.0.0.1:3000';
  static const defaultChatUrl = 'ws://127.0.0.1:3001/ws';

  String _authUrl = defaultAuthUrl;
  String _chatUrl = defaultChatUrl;

  String get authUrl => _authUrl;
  String get chatUrl => _chatUrl;

  ServerSettings() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _authUrl = prefs.getString(_keyAuth) ?? defaultAuthUrl;
    _chatUrl = prefs.getString(_keyChat) ?? defaultChatUrl;
    notifyListeners();
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
