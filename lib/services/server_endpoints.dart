import 'package:shared_preferences/shared_preferences.dart';

/// Persisted auth/chat URLs — single source of truth for UI and background code.
class ServerEndpoints {
  static const prefsKeyAuth = 'server_auth_url';
  static const prefsKeyChat = 'server_chat_url';
  static const prefsKeyFile = 'server_file_url';

  /// Desktop-only defaults when nothing is saved yet.
  static const desktopAuthDefault = 'https://auth.yechat.ru';
  static const desktopChatDefault = 'wss://msg.yechat.ru/ws';
  static const desktopFileDefault = 'wss://fl.yechat.ru/ws';

  static Future<({String? authUrl, String? chatUrl, String? fileUrl})>
      fromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = prefs.getString(prefsKeyAuth)?.trim();
    final chat = prefs.getString(prefsKeyChat)?.trim();
    final file = prefs.getString(prefsKeyFile)?.trim();
    return (
      authUrl: auth != null && auth.isNotEmpty ? auth : null,
      chatUrl: chat != null && chat.isNotEmpty ? chat : null,
      fileUrl: file != null && file.isNotEmpty ? file : null,
    );
  }

  static Future<bool> get isConfigured async {
    final urls = await fromPrefs();
    return urls.authUrl != null && urls.chatUrl != null && urls.fileUrl != null;
  }
}
