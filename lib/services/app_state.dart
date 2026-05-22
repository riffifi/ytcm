import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/group_models.dart';
import '../models/messenger_file.dart';
import '../services/auth_service.dart';
import '../services/background_sync.dart';
import '../services/chat_service.dart';
import '../services/file_metadata_cache.dart';
import '../services/file_service.dart';
import '../services/message_listener_service.dart';
import '../services/conversation_store.dart';
import '../services/message_cache.dart';
import '../services/notification_service.dart';
import '../services/server_settings.dart';

class AppState extends ChangeNotifier {
  AuthService auth;
  ChatService chat;
  FileService file;
  final ServerSettings serverSettings;
  final ConversationStore _conversationStore = ConversationStore();
  final MessageCache _messageCache = MessageCache();
  final FileMetadataCache _fileMetadataCache = FileMetadataCache();
  Timer? _persistDebounce;

  String? _token;
  UserInfo? _me;
  bool _loading = false;
  String? _error;
  String? _chatStatus;

  final Map<String, List<Message>> _conversations = {};
  final Map<String, List<GroupMessage>> _groupConversations = {};
  final List<ChatGroup> _groups = [];
  List<Connection> _contacts = [];
  String? _activeChatUserId;
  String? _activeChatUsername;
  String? _activeGroupId;
  String? _activeGroupName;

  StreamSubscription<Message>? _msgSub;
  StreamSubscription<Map<String, List<Message>>>? _historySub;
  StreamSubscription<List<Connection>>? _connectionsSub;
  StreamSubscription<String>? _readSub;
  StreamSubscription<String>? _markReadSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<UserInfo>? _joinSub;
  StreamSubscription<List<ChatGroup>>? _groupsSub;
  StreamSubscription<GroupMessage>? _groupMsgSub;
  StreamSubscription<Map<String, List<GroupMessage>>>? _groupHistorySub;
  StreamSubscription<ChatGroup>? _groupCreatedSub;

  String? get token => _token;
  UserInfo? get me => _me;
  bool get loading => _loading;
  String? get error => _error;
  String? get chatStatus => _chatStatus;
  Map<String, List<Message>> get conversations => _conversations;
  List<Connection> get contacts => _contacts;
  String? get activeChatUserId => _activeChatUserId;
  String? get activeChatUsername => _activeChatUsername;
  String? get activeGroupId => _activeGroupId;
  String? get activeGroupName => _activeGroupName;
  List<ChatGroup> get groups => List.unmodifiable(_groups);
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
        chat = ChatService(wsUrl: serverSettings.chatUrl),
        file = FileService(wsUrl: serverSettings.fileUrl) {
    _init();
  }

  void _rebuildServices() {
    auth = AuthService(baseUrl: serverSettings.authUrl);
    chat = ChatService(wsUrl: serverSettings.chatUrl);
    file = FileService(wsUrl: serverSettings.fileUrl);
  }

  MessengerFileInfo? fileMetadata(String fileId) => _fileMetadataCache.get(fileId);

  Future<void> reconnectWithNewSettings() async {
    await _cancelChatSubscriptions();
    chat.disconnect();
    _conversations.clear();
    _contacts.clear();
    _groups.clear();
    _groupConversations.clear();
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
    await _fileMetadataCache.load();
    final cachedMessages = await _messageCache.load();
    _conversations.addAll(cachedMessages);

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uuid', info.uuid);
      await _connectChat();
      await _registerBackgroundTasks();
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
    await prefs.setString('user_uuid', info.uuid);

    await _connectChat();
    await _registerBackgroundTasks();
    _loading = false;
    notifyListeners();
    return true;
  }

  Future<void> _registerBackgroundTasks() async {
    if (!serverSettings.isConfigured) return;
    await MessageListenerService.configure();
    if (BackgroundSync.isSupported) await BackgroundSync.register();
  }

  /// Drop the UI WebSocket so the background listener owns the server connection.
  Future<void> prepareForBackgroundListener() async {
    if (_token == null) return;
    await _cancelChatSubscriptions();
    chat.disconnect();
    _chatStatus = 'Background listener active';
    notifyListeners();
  }

  /// Called when the app returns to the foreground.
  Future<void> onAppResumed() async {
    if (_token != null && !chat.isConnected) {
      await _connectChat();
      notifyListeners();
    }
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 500), () {
      _messageCache.save(_conversations);
    });
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
    if (!serverSettings.isConfigured) {
      _chatStatus =
          'Set auth, chat, and file URLs in Profile → Server settings';
      notifyListeners();
      return;
    }
    await _cancelChatSubscriptions();

    await auth.setOnline(_token!);
    await chat.connect(_token!);

    _msgSub = chat.messages.listen(_onMessage);
    _historySub = chat.historyEvents.listen(_onHistory);
    _connectionsSub = chat.connections.listen(_onConnections);
    _readSub = chat.readReceipts.listen(_onReadReceipt);
    _markReadSub = chat.markReadResults.listen(_onMarkReadResult);
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
      _migrateStoredPeerKeys();
      _loadPersistedConversations();
      chat.listConnections();
      chat.listGroups();
      notifyListeners();
    });

    _groupsSub = chat.groups.listen(_onGroups);
    _groupMsgSub = chat.groupMessages.listen(_onGroupMessage);
    _groupHistorySub = chat.groupHistoryEvents.listen(_onGroupHistory);
    _groupCreatedSub = chat.groupCreated.listen((group) {
      if (!_groups.any((g) => g.uuid == group.uuid)) {
        _groups.add(group);
        _groups.sort((a, b) => a.name.compareTo(b.name));
        notifyListeners();
      }
    });

    _migrateStoredPeerKeys();
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
    await _markReadSub?.cancel();
    await _errorSub?.cancel();
    await _joinSub?.cancel();
    await _groupsSub?.cancel();
    await _groupMsgSub?.cancel();
    await _groupHistorySub?.cancel();
    await _groupCreatedSub?.cancel();
    _msgSub = null;
    _historySub = null;
    _connectionsSub = null;
    _readSub = null;
    _markReadSub = null;
    _errorSub = null;
    _joinSub = null;
    _groupsSub = null;
    _groupMsgSub = null;
    _groupHistorySub = null;
    _groupCreatedSub = null;
  }

  void _onGroups(List<ChatGroup> groups) {
    _groups
      ..clear()
      ..addAll(groups)
      ..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void _onGroupHistory(Map<String, List<GroupMessage>> event) {
    for (final entry in event.entries) {
      final sorted = List<GroupMessage>.from(entry.value)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _groupConversations[entry.key] = sorted;
    }
    notifyListeners();
  }

  void _onGroupMessage(GroupMessage msg) {
    _groupConversations.putIfAbsent(msg.groupId, () => []);
    final list = _groupConversations[msg.groupId]!;
    if (msg.senderId == _me?.uuid) {
      list.removeWhere((m) => m.uuid.startsWith('local-'));
    }
    final idx = list.indexWhere((m) => m.uuid == msg.uuid);
    if (idx == -1) {
      list.add(msg);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      list[idx] = msg;
    }
    if (_activeGroupId == msg.groupId) {
      chat.markGroupRead(msg.groupId);
    }
    notifyListeners();
  }

  List<GroupMessage> getGroupMessages(String groupId) =>
      _groupConversations[groupId] ?? [];

  void openGroupChat(String groupId, String name) {
    _activeGroupId = groupId;
    _activeGroupName = name;
    _activeChatUserId = null;
    _activeChatUsername = null;
    _groupConversations.putIfAbsent(groupId, () => []);
    chat.requestGroupHistory(groupId);
    chat.markGroupRead(groupId);
    notifyListeners();
  }

  void closeGroupChat() {
    _activeGroupId = null;
    _activeGroupName = null;
    notifyListeners();
  }

  Future<bool> createGroup(String name, {List<String> memberIds = const []}) async {
    if (!chat.isConnected) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    chat.createGroup(name: trimmed, memberIds: memberIds);
    return true;
  }

  void sendGroupMessage(String text) {
    if (_activeGroupId == null || text.trim().isEmpty) return;
    if (!chat.isConnected) return;
    final groupId = _activeGroupId!;
    final meId = _me?.uuid;
    if (meId == null) return;
    final trimmed = text.trim();
    final optimistic = GroupMessage(
      uuid: 'local-${DateTime.now().microsecondsSinceEpoch}',
      groupId: groupId,
      senderId: meId,
      text: trimmed,
      createdAt: DateTime.now(),
      deletedForEveryone: false,
      status: 'sent',
    );
    _onGroupMessage(optimistic);
    chat.sendGroupMessage(groupId: groupId, text: trimmed);
  }

  Future<bool> sendGroupFileAttachment() async {
    if (_activeGroupId == null || _token == null) return false;
    if (!serverSettings.isConfigured || !chat.isConnected) return false;

    final pick = await FilePicker.platform.pickFiles(withData: true);
    if (pick == null || pick.files.isEmpty) return false;
    final platformFile = pick.files.first;
    final bytes = platformFile.bytes;
    if (bytes == null || bytes.isEmpty) return false;

    final filename = platformFile.name.isNotEmpty
        ? platformFile.name
        : 'file_${DateTime.now().millisecondsSinceEpoch}';
    var mimeType = lookupMimeType(filename);
    if (mimeType == null && platformFile.extension != null) {
      mimeType = 'application/${platformFile.extension}';
    }
    mimeType ??= 'application/octet-stream';

    _loading = true;
    notifyListeners();
    try {
      final fileId = await file.uploadFile(
        sessionToken: _token!,
        bytes: Uint8List.fromList(bytes),
        filename: filename,
        mimeType: mimeType,
      );
      await _fileMetadataCache.put(MessengerFileInfo(
        fileId: fileId,
        filename: filename,
        originalSize: bytes.length,
        storedSize: bytes.length,
        isCompressed: false,
        mimeType: mimeType,
      ));
      final groupId = _activeGroupId!;
      final meId = _me!.uuid;
      final optimistic = GroupMessage(
        uuid: 'local-${DateTime.now().microsecondsSinceEpoch}',
        groupId: groupId,
        senderId: meId,
        fileId: fileId,
        createdAt: DateTime.now(),
        deletedForEveryone: false,
        status: 'sent',
      );
      _onGroupMessage(optimistic);
      chat.sendGroupMessage(groupId: groupId, fileId: fileId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _onMessage(Message msg) {
    final rawPeer =
        msg.senderId == _me?.uuid ? msg.receiverId : msg.senderId;
    final peerId = _canonicalPeerId(rawPeer);
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
    if (msg.senderId == _me?.uuid) {
      final active = _activeChatUserId;
      if (active != null &&
          !_looksLikeUuid(active) &&
          _looksLikeUuid(msg.receiverId)) {
        final name = _activeChatUsername ?? active;
        _rememberPeer(msg.receiverId, name);
        _mergePeerAlias(active, msg.receiverId);
        _activeChatUserId = msg.receiverId;
      } else {
        _promoteActiveChatPeer(peerId);
      }
    } else {
      _promoteActiveChatPeer(peerId);
    }
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
    if (_activeChatUserId != null &&
        peerId == _canonicalPeerId(_activeChatUserId!)) {
      _markIncomingRead(peerId);
      chat.markRead(peerId);
    }

    if (msg.senderId != _me?.uuid) {
      final preview = msg.previewText;
      final inActiveChat = _activeChatUserId != null &&
          peerId == _canonicalPeerId(_activeChatUserId!);
      NotificationService.instance.showIncomingMessage(
        peerId: peerId,
        title: _nameForPeer(msg.senderId),
        body: preview.isNotEmpty ? preview : 'New message',
        force: !inActiveChat,
      );
    }

    if (msg.fileId != null && msg.fileId!.isNotEmpty) {
      prefetchFileMetadata(msg.fileId!);
    }

    _schedulePersist();
    notifyListeners();
  }

  void _onMarkReadResult(String withUserId) {
    _markIncomingRead(withUserId);
    notifyListeners();
  }

  void _markIncomingRead(String userId) {
    final peerId = _canonicalPeerId(userId);
    final meId = _me?.uuid;
    if (meId == null) return;

    final msgs = _conversations[peerId];
    if (msgs == null) return;

    var changed = false;
    _conversations[peerId] = msgs.map((m) {
      if (m.senderId != meId && m.status < 2) {
        changed = true;
        return m.copyWith(status: 2);
      }
      return m;
    }).toList();

    if (!changed) return;
  }

  void _onHistory(Map<String, List<Message>> event) {
    event.forEach((userId, msgs) {
      final peerId = _canonicalPeerId(userId);
      if (msgs.isNotEmpty) {
        _rememberPeer(peerId, _nameForPeer(peerId));
      }
      _mergeConversation(peerId, msgs);
    });
    final active = _activeChatUserId;
    if (active != null) {
      _markIncomingRead(active);
    }
    _schedulePersist();
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
    final peerId = _canonicalPeerId(userId);
    final msgs = _conversations[peerId];
    if (msgs != null) {
      _conversations[peerId] = msgs
          .map((m) => m.senderId == _me?.uuid ? m.copyWith(status: 2) : m)
          .toList();
      notifyListeners();
    }
  }

  void _rememberPeer(String userId, String username) {
    final canonical = _canonicalPeerId(userId);
    if (canonical != userId) {
      _mergePeerAlias(userId, canonical);
    }
    for (final entry in _conversationStore.peerNames.entries.toList()) {
      if (entry.key != canonical &&
          entry.value.toLowerCase() == username.toLowerCase() &&
          _looksLikeUuid(canonical)) {
        _mergePeerAlias(entry.key, canonical);
      }
    }
    _conversationStore.setName(canonical, username);
    _conversationStore.save();
  }

  /// After the server echoes a message, map an active username chat to the real UUID.
  void _promoteActiveChatPeer(String canonicalPeerId) {
    final active = _activeChatUserId;
    if (active == null || _looksLikeUuid(active)) return;
    if (!_looksLikeUuid(canonicalPeerId)) return;

    final activeName = (_activeChatUsername ?? active).toLowerCase();
    final peerName = _nameForPeer(canonicalPeerId).toLowerCase();
    if (active.toLowerCase() == canonicalPeerId.toLowerCase() ||
        activeName == peerName ||
        activeName == canonicalPeerId.toLowerCase()) {
      _mergePeerAlias(active, canonicalPeerId);
      _activeChatUserId = canonicalPeerId;
    }
  }

  /// Maps stored username keys to real UUIDs (chat server uses UUIDs only).
  String _canonicalPeerId(String id) {
    if (_looksLikeUuid(id)) return id;

    for (final c in _contacts) {
      if (c.username.toLowerCase() == id.toLowerCase()) return c.uuid;
    }
    for (final entry in _conversationStore.peerNames.entries) {
      if (entry.value.toLowerCase() == id.toLowerCase() && _looksLikeUuid(entry.key)) {
        return entry.key;
      }
    }
    return id;
  }

  void _mergePeerAlias(String aliasId, String canonicalId) {
    if (aliasId == canonicalId) return;

    final aliasMsgs = _conversations.remove(aliasId);
    if (aliasMsgs != null && aliasMsgs.isNotEmpty) {
      _conversations.putIfAbsent(canonicalId, () => []);
      final existing = _conversations[canonicalId]!;
      final seen = existing.map((m) => m.uuid).toSet();
      for (final m in aliasMsgs) {
        if (seen.add(m.uuid)) existing.add(m);
      }
      existing.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final aliasName = _conversationStore.nameFor(aliasId);
    if (aliasName != null) {
      _conversationStore.setName(canonicalId, aliasName);
    }
  }

  void _mergeConversation(String peerId, List<Message> msgs) {
    final existing = _conversations[peerId];
    if (existing == null || existing.isEmpty) {
      _conversations[peerId] = List<Message>.from(msgs);
      return;
    }
    final seen = existing.map((m) => m.uuid).toSet();
    final merged = [...existing];
    for (final m in msgs) {
      if (seen.add(m.uuid)) merged.add(m);
    }
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _conversations[peerId] = merged;
    _schedulePersist();
  }

  void _migrateStoredPeerKeys() {
    for (final entry in _conversationStore.peerNames.entries.toList()) {
      if (_looksLikeUuid(entry.key)) continue;
      final canonical = _canonicalPeerId(entry.key);
      if (canonical != entry.key && _looksLikeUuid(canonical)) {
        _mergePeerAlias(entry.key, canonical);
        _conversationStore.setName(canonical, entry.value);
      }
    }
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
      if (entry.value.toLowerCase() == q) {
        return _canonicalPeerId(entry.key);
      }
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

    final fromContacts = await _resolvePeerFromContacts(trimmed);
    if (fromContacts != null) {
      _rememberPeer(fromContacts.peerId, fromContacts.username);
      return fromContacts;
    }

    _lastPeerLookupError = lookup.failure?.message ??
        'Could not find "$trimmed" on the auth server. Use exact username, email, '
        'or their user ID from Profile. Recipients do not need to be online.';
    return null;
  }

  Connection? _contactMatching(String query) {
    final q = _normalizeQuery(query).toLowerCase();
    for (final c in _contacts) {
      if (c.username.toLowerCase() == q) return c;
    }
    if (q.contains('@')) {
      final local = q.split('@').first;
      for (final c in _contacts) {
        if (c.username.toLowerCase() == local) return c;
      }
    }
    return null;
  }

  Future<({String peerId, String username})?> _resolvePeerFromContacts(
    String query,
  ) async {
    var match = _contactMatching(query);
    if (match != null) {
      return (peerId: match.uuid, username: match.username);
    }

    if (chat.isConnected) {
      chat.listConnections();
      await Future.delayed(const Duration(milliseconds: 500));
      match = _contactMatching(query);
      if (match != null) {
        return (peerId: match.uuid, username: match.username);
      }
    }

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

  void markPeerRead(String userId) {
    final peerId = _canonicalPeerId(userId);
    _markIncomingRead(peerId);
    chat.markRead(peerId);
    notifyListeners();
  }

  void openChat(String userId, String username) {
    final peerId = _canonicalPeerId(userId);
    _activeChatUserId = peerId;
    _activeChatUsername = username;
    _activeGroupId = null;
    _activeGroupName = null;
    NotificationService.instance.setActiveChat(peerId);
    MessageListenerService.updateAppState(
      inForeground: true,
      activeChatPeerId: peerId,
    );
    _rememberPeer(peerId, username);
    _conversations.putIfAbsent(peerId, () => []);
    chat.requestHistory(peerId);
    _markIncomingRead(peerId);
    chat.markRead(peerId);
    notifyListeners();
  }

  void closeChat() {
    _activeChatUserId = null;
    _activeChatUsername = null;
    _activeGroupId = null;
    _activeGroupName = null;
    NotificationService.instance.setActiveChat(null);
    MessageListenerService.updateAppState(
      inForeground: true,
      activeChatPeerId: null,
    );
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
    final receiverId = _canonicalPeerId(_activeChatUserId!);
    final meId = _me?.uuid;
    if (meId == null) return;

    if (receiverId != _activeChatUserId) {
      _activeChatUserId = receiverId;
    }

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

  /// Picks a file, uploads via file-service, then sends a chat message with [file_id].
  /// Chat-service grants the recipient access automatically.
  Future<bool> sendFileAttachment({String? caption}) async {
    if (_activeChatUserId == null || _token == null) return false;
    if (!serverSettings.isConfigured) {
      _error = 'Set auth, chat, and file URLs in Server settings';
      notifyListeners();
      return false;
    }
    if (!chat.isConnected) {
      _chatStatus = 'Waiting for chat connection…';
      notifyListeners();
      return false;
    }

    final pick = await FilePicker.platform.pickFiles(withData: true);
    if (pick == null || pick.files.isEmpty) return false;
    final platformFile = pick.files.first;
    final bytes = platformFile.bytes;
    if (bytes == null || bytes.isEmpty) {
      _error = 'Could not read the selected file';
      notifyListeners();
      return false;
    }

    final filename = platformFile.name.isNotEmpty
        ? platformFile.name
        : 'file_${DateTime.now().millisecondsSinceEpoch}';
    var mimeType = lookupMimeType(filename);
    if (mimeType == null && platformFile.extension != null) {
      mimeType = 'application/${platformFile.extension}';
    }
    mimeType ??= 'application/octet-stream';

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final fileId = await file.uploadFile(
        sessionToken: _token!,
        bytes: Uint8List.fromList(bytes),
        filename: filename,
        mimeType: mimeType,
      );

      final info = MessengerFileInfo(
        fileId: fileId,
        filename: filename,
        originalSize: bytes.length,
        storedSize: bytes.length,
        isCompressed: false,
        mimeType: mimeType,
      );
      await _fileMetadataCache.put(info);

      final receiverId = _canonicalPeerId(_activeChatUserId!);
      final meId = _me!.uuid;
      final trimmedCaption = caption?.trim();
      final hasCaption =
          trimmedCaption != null && trimmedCaption.isNotEmpty;

      final optimistic = Message(
        uuid: 'local-${DateTime.now().microsecondsSinceEpoch}',
        senderId: meId,
        receiverId: receiverId,
        dialogId: '',
        text: hasCaption ? trimmedCaption : null,
        fileId: fileId,
        createdAt: DateTime.now(),
        status: 0,
      );
      _onMessage(optimistic);

      chat.sendMessage(
        receiverId: receiverId,
        text: hasCaption ? trimmedCaption : null,
        fileId: fileId,
      );
      return true;
    } on FileServiceException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Upload failed: $e';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<DownloadedFile> downloadFile(String fileId) async {
    if (_token == null) {
      throw const FileServiceException('Not signed in');
    }
    final downloaded = await file.downloadFile(
      sessionToken: _token!,
      fileId: fileId,
    );
    final meta = _fileMetadataCache.get(fileId);
    if (meta == null) {
      await _fileMetadataCache.put(MessengerFileInfo(
        fileId: fileId,
        filename: downloaded.filename,
        originalSize: downloaded.bytes.length,
        storedSize: downloaded.bytes.length,
        isCompressed: false,
        mimeType: downloaded.mimeType,
      ));
    }
    return downloaded;
  }

  Future<String?> cachedFilePath(String fileId, String filename) =>
      FileService.cachedPath(fileId, filename);

  Future<void> prefetchFileMetadata(String fileId) async {
    if (_fileMetadataCache.get(fileId) != null || _token == null) return;
    try {
      final files = await file.listFiles(_token!);
      for (final f in files) {
        await _fileMetadataCache.put(f);
      }
    } catch (_) {}
  }

  Future<String> pingFileReachability() => file.pingReachability();

  List<Message> getMessages(String userId) => _conversations[userId] ?? [];

  int getUnreadCount(String userId) {
    final peerId = _canonicalPeerId(userId);
    final meId = _me?.uuid;
    if (meId == null) return 0;
    if (_activeChatUserId != null &&
        peerId == _canonicalPeerId(_activeChatUserId!)) {
      return 0;
    }
    return _conversations[peerId]
            ?.where((m) => m.senderId == peerId && m.status < 2)
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
    _activeGroupId = null;
    _activeGroupName = null;
    _groups.clear();
    _groupConversations.clear();
    _chatStatus = null;
    _conversationStore.clear();
    await _conversationStore.save();
    await _messageCache.clear();
    await NotificationService.instance.cancelAll();
    await MessageListenerService.stop();
    if (BackgroundSync.isSupported) await BackgroundSync.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
