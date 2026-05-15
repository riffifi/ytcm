import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/conversation_store.dart';
import '../services/server_settings.dart';

class AppState extends ChangeNotifier {
  AuthService auth;
  ChatService chat;
  final ServerSettings serverSettings;
  final ConversationStore _conversationStore = ConversationStore();

  String? _token;
  UserInfo? _me;
  bool _loading = false;
  String? _error;
  String? _chatStatus;

  final Map<String, List<Message>> _conversations = {};
  List<Connection> _contacts = [];
  String? _activeChatUserId;
  String? _activeChatUsername;

  StreamSubscription<Message>? _msgSub;
  StreamSubscription<Map<String, List<Message>>>? _historySub;
  StreamSubscription<List<Connection>>? _connectionsSub;
  StreamSubscription<String>? _readSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<UserInfo>? _joinSub;

  String? get token => _token;
  UserInfo? get me => _me;
  bool get loading => _loading;
  String? get error => _error;
  String? get chatStatus => _chatStatus;
  Map<String, List<Message>> get conversations => _conversations;
  List<Connection> get contacts => _contacts;
  String? get activeChatUserId => _activeChatUserId;
  String? get activeChatUsername => _activeChatUsername;
  bool get isLoggedIn => _token != null && _me != null;

  /// All chats: saved peers, message history, and known contacts.
  List<ConversationPeer> get conversationPeers {
    final ids = <String>{
      ..._conversationStore.peerNames.keys,
      ..._conversations.keys,
      ..._contacts.map((c) => c.uuid),
    };

    final peers = ids.map((id) {
      final fromContact = _contacts.cast<Connection?>().firstWhere(
            (c) => c!.uuid == id,
            orElse: () => null,
          );
      final username = fromContact?.username ??
          _conversationStore.nameFor(id) ??
          _shortPeerLabel(id);
      return ConversationPeer(userId: id, username: username);
    }).toList();

    peers.sort((a, b) {
      final aT = _lastActivity(a.userId);
      final bT = _lastActivity(b.userId);
      if (aT == null && bT == null) {
        return a.username.compareTo(b.username);
      }
      if (aT == null) return 1;
      if (bT == null) return -1;
      return bT.compareTo(aT);
    });
    return peers;
  }

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
    await _cancelChatSubscriptions();
    chat.disconnect();
    _conversations.clear();
    _contacts.clear();
    _rebuildServices();

    if (_token == null) {
      _rebuildServices();
      notifyListeners();
      return;
    }

    final info = await auth.getSessionInfo(_token!);
    if (info != null) {
      _me = info;
      await _connectChat();
    } else {
      _token = null;
      _me = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
      _conversationStore.clear();
      await _conversationStore.save();
    }
    notifyListeners();
  }

  Future<void> _init() async {
    await serverSettings.ensureLoaded();
    _rebuildServices();
    await _conversationStore.load();

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
      _error =
          'Could not sign in. Check credentials and server URL in settings.';
      notifyListeners();
      return false;
    }

    final info = await auth.getSessionInfo(token);
    if (info == null) {
      _loading = false;
      _error = 'Session error — auth server may be unreachable.';
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
    if (!ok) {
      _error = 'Registration failed — check server URL in settings.';
    }
    notifyListeners();
    return ok;
  }

  Future<void> _connectChat() async {
    if (_token == null) return;
    await _cancelChatSubscriptions();

    await auth.setOnline(_token!);
    await chat.connect(_token!);

    _msgSub = chat.messages.listen(_onMessage);
    _historySub = chat.historyEvents.listen(_onHistory);
    _connectionsSub = chat.connections.listen(_onConnections);
    _readSub = chat.readReceipts.listen(_onReadReceipt);
    _errorSub = chat.errors.listen((msg) {
      final text = msg.trim();
      if (text.isNotEmpty) {
        _chatStatus = text;
        notifyListeners();
      }
    });
    _joinSub = chat.joinEvents.listen((info) {
      _chatStatus = 'Connected';
      _rememberPeer(info.uuid, info.username);
      _loadPersistedConversations();
      chat.listConnections();
      notifyListeners();
    });

    _loadPersistedConversations();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (chat.isConnected) chat.listConnections();
    });
  }

  void _loadPersistedConversations() {
    for (final entry in _conversationStore.peerNames.entries) {
      if (!_conversations.containsKey(entry.key)) {
        chat.requestHistory(entry.key);
      }
    }
  }

  Future<void> _cancelChatSubscriptions() async {
    await _msgSub?.cancel();
    await _historySub?.cancel();
    await _connectionsSub?.cancel();
    await _readSub?.cancel();
    await _errorSub?.cancel();
    await _joinSub?.cancel();
    _msgSub = null;
    _historySub = null;
    _connectionsSub = null;
    _readSub = null;
    _errorSub = null;
    _joinSub = null;
  }

  void _onMessage(Message msg) {
    final peerId =
        msg.senderId == _me?.uuid ? msg.receiverId : msg.senderId;
    // Learn peer ids from traffic (including offline delivery on join).
    if (msg.senderId != _me?.uuid) {
      final senderName = _contacts
          .where((c) => c.uuid == msg.senderId)
          .map((c) => c.username)
          .firstOrNull;
      if (senderName != null) {
        _rememberPeer(msg.senderId, senderName);
      }
    }
    _rememberPeer(peerId, _nameForPeer(peerId));
    _conversations.putIfAbsent(peerId, () => []);

    // Replace optimistic local message when server echo arrives.
    if (msg.senderId == _me?.uuid) {
      _conversations[peerId]!.removeWhere((m) => m.uuid.startsWith('local-'));
    }

    final idx = _conversations[peerId]!.indexWhere((m) => m.uuid == msg.uuid);
    if (idx == -1) {
      _conversations[peerId]!.add(msg);
      _conversations[peerId]!
          .sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      _conversations[peerId]![idx] = msg;
    }
    notifyListeners();
  }

  void _onHistory(Map<String, List<Message>> event) {
    event.forEach((userId, msgs) {
      if (msgs.isNotEmpty) {
        _rememberPeer(userId, _nameForPeer(userId));
      }
      _conversations[userId] = msgs;
    });
    notifyListeners();
  }

  void _onConnections(List<Connection> conns) {
    _contacts = conns.where((c) => c.uuid != _me?.uuid).toList();
    for (final c in _contacts) {
      _rememberPeer(c.uuid, c.username);
      if (!_conversations.containsKey(c.uuid)) {
        chat.requestHistory(c.uuid);
      }
    }
    notifyListeners();
  }

  void _onReadReceipt(String userId) {
    final msgs = _conversations[userId];
    if (msgs != null) {
      _conversations[userId] = msgs
          .map((m) => m.senderId == _me?.uuid ? m.copyWith(status: 2) : m)
          .toList();
      notifyListeners();
    }
  }

  void _rememberPeer(String userId, String username) {
    _conversationStore.setName(userId, username);
    _conversationStore.save();
  }

  String _nameForPeer(String peerId) {
    final contact = _contacts.cast<Connection?>().firstWhere(
          (c) => c!.uuid == peerId,
          orElse: () => null,
        );
    if (contact != null) return contact.username;
    return _conversationStore.nameFor(peerId) ?? _shortPeerLabel(peerId);
  }

  String _shortPeerLabel(String id) {
    if (id.length <= 8) return id;
    return 'User ${id.substring(0, 8)}…';
  }

  DateTime? _lastActivity(String userId) {
    final msgs = _conversations[userId];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last.createdAt;
  }

  String _normalizeQuery(String query) {
    var q = query.trim();
    if (q.startsWith('@')) q = q.substring(1).trim();
    return q;
  }

  ({String peerId, String username})? _resolveSelf(String query) {
    final me = _me;
    if (me == null) return null;
    final q = _normalizeQuery(query).toLowerCase();
    if (q.isEmpty) return null;
    if (q == me.username.toLowerCase() || q == me.uuid.toLowerCase()) {
      return (peerId: me.uuid, username: me.username);
    }
    return null;
  }

  /// Resolves a tag/username or UUID to a peer id (no online requirement).
  String? resolvePeerId(String query) {
    final self = _resolveSelf(query);
    if (self != null) return self.peerId;

    final q = _normalizeQuery(query).toLowerCase();
    if (q.isEmpty) return null;

    for (final entry in _conversationStore.peerNames.entries) {
      if (entry.value.toLowerCase() == q) return entry.key;
    }
    for (final c in _contacts) {
      if (c.username.toLowerCase() == q) return c.uuid;
    }
    final raw = _normalizeQuery(query);
    if (_looksLikeUuid(raw)) return raw;
    return null;
  }

  String? _lastPeerLookupError;

  String? get lastPeerLookupError => _lastPeerLookupError;

  /// Resolves peer for a new chat; uses auth lookup (works when user is offline).
  Future<({String peerId, String username})?> resolvePeer(String query) async {
    _lastPeerLookupError = null;
    final trimmed = _normalizeQuery(query);
    if (trimmed.isEmpty) return null;

    final self = _resolveSelf(trimmed);
    if (self != null) {
      _rememberPeer(self.peerId, self.username);
      return self;
    }

    final cached = resolvePeerId(trimmed);
    if (cached != null) {
      return (peerId: cached, username: _nameForPeer(cached));
    }

    if (_token == null) {
      _lastPeerLookupError = 'Not signed in';
      return null;
    }

    final lookup = await auth.lookupPeer(token: _token!, query: trimmed);
    if (lookup.result != null) {
      final r = lookup.result!;
      _rememberPeer(r.uuid, r.username);
      return (peerId: r.uuid, username: r.username);
    }

    _lastPeerLookupError = lookup.failure?.message ??
        'No user "$trimmed". Try username, email, or UUID.';
    return null;
  }

  String resolvePeerErrorHint(String query) =>
      _lastPeerLookupError ??
      'No user "$query". Use their exact username (GET /getuserinfo), '
      'or UUID from Profile. They do not need to be online to receive messages.';

  bool _looksLikeUuid(String value) {
    final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    return re.hasMatch(value);
  }

  void openChat(String userId, String username) {
    _activeChatUserId = userId;
    _activeChatUsername = username;
    _rememberPeer(userId, username);
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
    if (!chat.isConnected) {
      _chatStatus = 'Waiting for chat connection…';
      notifyListeners();
      return;
    }
    final trimmed = text.trim();
    final receiverId = _activeChatUserId!;
    final meId = _me?.uuid;
    if (meId == null) return;

    // Optimistic UI — message shows immediately; server echoes on delivery.
    final optimistic = Message(
      uuid: 'local-${DateTime.now().microsecondsSinceEpoch}',
      senderId: meId,
      receiverId: receiverId,
      dialogId: '',
      text: trimmed,
      createdAt: DateTime.now(),
      status: 0,
    );
    _onMessage(optimistic);

    chat.sendMessage(receiverId: receiverId, text: trimmed);
  }

  List<Message> getMessages(String userId) => _conversations[userId] ?? [];

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

  String lastMessagePreview(String userId) {
    final last = getLastMessage(userId);
    if (last == null) return 'No messages yet';
    final preview = last.previewText;
    if (preview.isNotEmpty) return preview;
    return 'No messages yet';
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
  }) async {
    if (_token == null) return false;
    final fnOk = await auth.changeFirstName(_token!, firstName);
    final lnOk = await auth.changeLastName(_token!, lastName);
    if (!fnOk && !lnOk) return false;

    final info = await auth.getSessionInfo(_token!);
    if (info != null) {
      _me = UserInfo(
        uuid: info.uuid,
        username: info.username,
        firstName: firstName.isNotEmpty ? firstName : info.firstName,
        lastName: lastName.isNotEmpty ? lastName : info.lastName,
        dateOfBirth: info.dateOfBirth,
        additionalInfo: info.additionalInfo,
      );
      notifyListeners();
    }
    return true;
  }

  Future<String> pingAuth() => auth.ping();

  Future<String> pingChatReachability() => chat.pingReachability();

  Future<String> pingChatSession() => chat.pingSession();

  Future<void> logout() async {
    if (_token != null) await auth.setOffline(_token!);
    await _cancelChatSubscriptions();
    chat.disconnect();
    _token = null;
    _me = null;
    _conversations.clear();
    _contacts.clear();
    _activeChatUserId = null;
    _chatStatus = null;
    _conversationStore.clear();
    await _conversationStore.save();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
