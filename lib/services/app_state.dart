import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/server_settings.dart';

class AppState extends ChangeNotifier {
  AuthService auth;
  ChatService chat;
  final ServerSettings serverSettings;

  String? _token;
  UserInfo? _me;
  bool _loading = false;
  String? _error;

  // conversations: userId -> list of messages
  final Map<String, List<Message>> _conversations = {};
  // contacts from list_connections
  List<Connection> _contacts = [];
  // currently open chat
  String? _activeChatUserId;
  String? _activeChatUsername;

  String? get token => _token;
  UserInfo? get me => _me;
  bool get loading => _loading;
  String? get error => _error;
  Map<String, List<Message>> get conversations => _conversations;
  List<Connection> get contacts => _contacts;
  String? get activeChatUserId => _activeChatUserId;
  String? get activeChatUsername => _activeChatUsername;
  bool get isLoggedIn => _token != null && _me != null;

  AppState({required this.serverSettings})
      : auth = AuthService(baseUrl: serverSettings.authUrl),
        chat = ChatService(wsUrl: serverSettings.chatUrl) {
    _init();
  }

  void _rebuildServices() {
    auth = AuthService(baseUrl: serverSettings.authUrl);
    chat = ChatService(wsUrl: serverSettings.chatUrl);
  }

  Future<void> reconnectWithNewSettings() async {
    if (_token == null) {
      _rebuildServices();
      return;
    }
    // Disconnect existing
    chat.disconnect();
    _conversations.clear();
    _contacts.clear();
    _rebuildServices();
    // Re-verify session with new auth URL
    final info = await auth.getSessionInfo(_token!);
    if (info != null) {
      _me = info;
      await _connectChat();
    } else {
      // New server doesn't know this session
      _token = null;
      _me = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
    }
    notifyListeners();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('session_token');
    if (saved != null) {
      await _restoreSession(saved);
    }
  }

  Future<void> _restoreSession(String token) async {
    final info = await auth.getSessionInfo(token);
    if (info != null) {
      _token = token;
      _me = info;
      await _connectChat();
      notifyListeners();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
    }
  }

  Future<bool> login(String loginDetails, String password,
      {String loginType = 'email'}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final token = await auth.login(
      loginDetails: loginDetails,
      password: password,
      loginType: loginType,
    );

    if (token == null) {
      _loading = false;
      _error = 'Invalid credentials';
      notifyListeners();
      return false;
    }

    final info = await auth.getSessionInfo(token);
    if (info == null) {
      _loading = false;
      _error = 'Session error';
      notifyListeners();
      return false;
    }

    _token = token;
    _me = info;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_token', token);

    await _connectChat();
    _loading = false;
    notifyListeners();
    return true;
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String phone,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final ok = await auth.register(
      username: username,
      email: email,
      password: password,
      phoneNumber: phone,
    );

    _loading = false;
    if (!ok) _error = 'Registration failed';
    notifyListeners();
    return ok;
  }

  Future<void> _connectChat() async {
    if (_token == null) return;
    await auth.setOnline(_token!);
    await chat.connect(_token!);

    chat.messages.listen((msg) {
      final peerId =
          msg.senderId == _me?.uuid ? msg.receiverId : msg.senderId;
      _conversations.putIfAbsent(peerId, () => []);
      final idx = _conversations[peerId]!.indexWhere((m) => m.uuid == msg.uuid);
      if (idx == -1) {
        _conversations[peerId]!.add(msg);
        _conversations[peerId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      notifyListeners();
    });

    chat.historyEvents.listen((event) {
      event.forEach((userId, msgs) {
        _conversations[userId] = msgs;
        notifyListeners();
      });
    });

    chat.connections.listen((conns) {
      _contacts = conns.where((c) => c.uuid != _me?.uuid).toList();
      for (final c in _contacts) {
        if (!_conversations.containsKey(c.uuid)) {
          chat.requestHistory(c.uuid);
        }
      }
      notifyListeners();
    });

    chat.readReceipts.listen((userId) {
      final msgs = _conversations[userId];
      if (msgs != null) {
        _conversations[userId] = msgs
            .map((m) => m.senderId == _me?.uuid ? m.copyWith(status: 2) : m)
            .toList();
        notifyListeners();
      }
    });

    // Fetch contacts after short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      chat.listConnections();
    });
  }

  void openChat(String userId, String username) {
    _activeChatUserId = userId;
    _activeChatUsername = username;
    _conversations.putIfAbsent(userId, () => []);
    chat.requestHistory(userId);
    chat.markRead(userId);
    notifyListeners();
  }

  void closeChat() {
    _activeChatUserId = null;
    _activeChatUsername = null;
    notifyListeners();
  }

  void sendMessage(String text) {
    if (_activeChatUserId == null || text.trim().isEmpty) return;
    chat.sendMessage(receiverId: _activeChatUserId!, text: text.trim());
  }

  List<Message> getMessages(String userId) =>
      _conversations[userId] ?? [];

  int getUnreadCount(String userId) {
    return _conversations[userId]
            ?.where((m) => m.senderId == userId && m.status < 2)
            .length ??
        0;
  }

  Message? getLastMessage(String userId) {
    final msgs = _conversations[userId];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last;
  }

  Future<void> logout() async {
    if (_token != null) await auth.setOffline(_token!);
    chat.disconnect();
    _token = null;
    _me = null;
    _conversations.clear();
    _contacts.clear();
    _activeChatUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
