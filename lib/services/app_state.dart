import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/group_models.dart';
import '../models/messenger_file.dart';
import '../services/auth_service.dart';
import '../services/background_messaging.dart';
import '../services/background_state.dart';
import '../services/background_sync.dart';
import '../services/chat_service.dart';
import '../services/file_metadata_cache.dart';
import '../services/file_service.dart';
import '../services/conversation_store.dart';
import '../services/message_cache.dart';
import '../services/notification_service.dart';
import '../services/server_settings.dart';
import '../utils/file_limits.dart';
import '../utils/profile_extras.dart';
import 'messenger_log.dart';

class AppState extends ChangeNotifier {
  AuthService auth;
  ChatService chat;
  FileService file;
  final ServerSettings serverSettings;
  final MessengerLog log;
  final ConversationStore _conversationStore = ConversationStore();
  final MessageCache _messageCache = MessageCache();
  final FileMetadataCache _fileMetadataCache = FileMetadataCache();
  Timer? _persistDebounce;
  Timer? _presenceTimer;
  Timer? _reconnectTimer;

  String? _token;
  UserInfo? _me;
  bool _loading = false;
  bool _sessionChecked = false;
  String? _error;
  String? _chatStatus;
  double? _uploadProgress;

  final Map<String, List<Message>> _conversations = {};
  final Map<String, List<GroupMessage>> _groupConversations = {};
  final List<ChatGroup> _groups = [];
  List<Connection> _contacts = [];
  final Map<String, UserInfo> _peerProfiles = {};
  final Set<String> _onlinePeerIds = {};
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
  StreamSubscription<bool>? _connectionStateSub;
  StreamSubscription<ChatGroup>? _groupUpdatedSub;
  StreamSubscription<String>? _groupDeletedSub;
  StreamSubscription<MessageDeletedEvent>? _messageDeletedSub;
  StreamSubscription<GroupMessageDeletedEvent>? _groupMessageDeletedSub;
  StreamSubscription<void>? _groupMembershipChangedSub;

  String? get token => _token;
  UserInfo? get me => _me;
  bool get loading => _loading;
  bool get sessionChecked => _sessionChecked;
  String? get error => _error;
  String? get chatStatus => _chatStatus;
  double? get uploadProgress => _uploadProgress;
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
      final profile = _peerProfiles[id];
      final username = profile?.username ??
          fromContact?.username ??
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

  AppState({required this.serverSettings, required this.log})
      : auth = AuthService(baseUrl: serverSettings.authUrl),
        chat = ChatService(
          wsUrl: serverSettings.chatUrl,
          log: log,
        ),
        file = FileService(wsUrl: serverSettings.fileUrl) {
    log.info('App started', category: 'app', banner: false);
    _init();
  }

  void _rebuildServices() {
    final previousChat = chat;
    auth = AuthService(baseUrl: serverSettings.authUrl);
    chat = ChatService(wsUrl: serverSettings.chatUrl, log: log);
    file = FileService(wsUrl: serverSettings.fileUrl);
    previousChat.dispose();
    log.info('Server endpoints updated', category: 'app');
  }

  void _setStatus(String message, {String category = 'app'}) {
    _chatStatus = message;
    log.info(message, category: category);
    notifyListeners();
  }

  void _setError(String message, {String category = 'app'}) {
    _error = message;
    _chatStatus = message;
    log.error(message, category: category);
    notifyListeners();
  }

  void _setUploadProgress(double value) {
    final progress = value.clamp(0.0, 1.0);
    if (_uploadProgress != null &&
        progress < 1 &&
        (progress - _uploadProgress!).abs() < 0.02) {
      return;
    }
    _uploadProgress = progress;
    notifyListeners();
  }

  MessengerFileInfo? fileMetadata(String fileId) =>
      _fileMetadataCache.get(fileId);

  Future<void> reconnectWithNewSettings() async {
    log.info('Applying new server settings…', category: 'app');
    await _cancelChatSubscriptions();
    await chat.disconnect();
    _conversations.clear();
    _contacts.clear();
    _groups.clear();
    _groupConversations.clear();
    _rebuildServices();

    if (_token == null) {
      notifyListeners();
      return;
    }

    final info = await auth.getSessionInfo(_token!);
    if (info != null) {
      _me = info;
      await _applyAccountStorage(info.uuid);
      await _connectChat();
    } else {
      _token = null;
      _me = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
      await prefs.remove('user_uuid');
      await _conversationStore.setUserScope(null);
      await _messageCache.setUserScope(null);
    }
    notifyListeners();
  }

  Future<void> _init() async {
    try {
      await serverSettings.ensureLoaded();
      _rebuildServices();
      await _fileMetadataCache.load();

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('session_token');
      if (saved != null) {
        log.info('Restoring saved session…', category: 'auth', banner: false);
        await _restoreSession(saved);
      }
    } finally {
      _sessionChecked = true;
      notifyListeners();
    }
  }

  Future<void> _restoreSession(String token) async {
    final info = await auth.getSessionInfo(token);
    if (info != null) {
      _token = token;
      _me = info;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uuid', info.uuid);
      await _applyAccountStorage(info.uuid);
      await loadMyProfile();
      await _connectChat();
      await _registerBackgroundTasks();
      notifyListeners();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
      await prefs.remove('user_uuid');
    }
  }

  Future<bool> login(String loginDetails, String password,
      {String loginType = 'email'}) async {
    if (loginDetails.trim().isEmpty || password.isEmpty) {
      _setError(
          'Enter your ${loginType == 'phone' ? 'phone number' : 'email'} and password.',
          category: 'auth');
      return false;
    }
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
      _setError(
        'Could not sign in. Check credentials and server URL in settings.',
        category: 'auth',
      );
      return false;
    }

    final info = await auth.getSessionInfo(token);
    if (info == null) {
      _loading = false;
      _setError('Session error — auth server may be unreachable.',
          category: 'auth');
      return false;
    }

    _token = token;
    _me = info;
    log.info('Signed in as ${info.username}', category: 'auth');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_token', token);
    await prefs.setString('user_uuid', info.uuid);

    await _applyAccountStorage(info.uuid);
    await loadMyProfile();
    await _connectChat();
    await _registerBackgroundTasks();
    _loading = false;
    notifyListeners();
    return true;
  }

  Future<void> _registerBackgroundTasks() async {
    if (!serverSettings.isConfigured) return;
    if (BackgroundSync.isSupported) {
      await BackgroundSync.register();
    }
  }

  /// Disconnect the visible session and advertise offline before background sync.
  Future<void> prepareForBackgroundNotifications() async {
    if (_token == null) return;
    await _cancelChatSubscriptions();
    await chat.disconnect();
    await auth.setOffline(_token!);
    _contacts = [];
    _onlinePeerIds.clear();
    _setStatus('Offline — background notifications enabled', category: 'chat');
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
    if (username.trim().isEmpty || password.isEmpty) {
      _setError('Username and password are required.', category: 'auth');
      return false;
    }
    if (email.trim().isEmpty && phone.trim().isEmpty) {
      _setError('Enter an email address or phone number.', category: 'auth');
      return false;
    }
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
      _setError('Registration failed — check server URL in settings.',
          category: 'auth');
    } else {
      log.info('Registration successful', category: 'auth');
    }
    notifyListeners();
    return ok;
  }

  Future<void> _connectChat() async {
    if (_token == null) return;
    if (!serverSettings.isConfigured) {
      _setStatus(
        'Set auth, chat, and file URLs in Profile → Server settings',
      );
      return;
    }
    log.info('Connecting chat session…', category: 'chat');
    await _cancelChatSubscriptions();

    // Let the UI socket own join/sync (background listener would consume offline mail).
    await BackgroundMessaging.stop();

    await auth.setOnline(_token!);
    _msgSub = chat.messages.listen(_onMessage);
    _historySub = chat.historyEvents.listen(_onHistory);
    _connectionsSub = chat.connections.listen(_onConnections);
    _readSub = chat.readReceipts.listen(_onReadReceipt);
    _markReadSub = chat.markReadResults.listen(_onMarkReadResult);
    _errorSub = chat.errors.listen((msg) {
      final text = msg.trim();
      if (text.isNotEmpty) _setError(text, category: 'chat');
    });
    _connectionStateSub = chat.connectionState.listen((connected) {
      if (connected) {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      } else if (_token != null) {
        _setStatus('Chat disconnected — reconnecting…', category: 'chat');
        _scheduleChatReconnect();
      }
    });
    _joinSub = chat.joinEvents.listen((info) {
      _setStatus('Connected', category: 'chat');
      _rememberPeer(info.uuid, info.username);
      _migrateStoredPeerKeys();
      _indexPeersFromCachedMessages();
      _loadPersistedConversations();
      chat.listConnections();
      chat.listGroups();
      _scheduleServerSync();
      _scheduleProfilePrefetch();
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
    _groupUpdatedSub = chat.groupUpdated.listen(_onGroupUpdated);
    _groupDeletedSub = chat.groupDeleted.listen(_onGroupDeleted);
    _messageDeletedSub = chat.messageDeleted.listen(_onMessageDeleted);
    _groupMessageDeletedSub =
        chat.groupMessageDeleted.listen(_onGroupMessageDeleted);
    _groupMembershipChangedSub = chat.groupMembershipChanged.listen((_) {
      if (chat.isConnected) chat.listGroups();
    });

    // Subscribe before join: broadcast streams do not replay a fast server
    // response, so connecting first can lose the `joined` event.
    await chat.connect(_token!);

    _migrateStoredPeerKeys();
    _indexPeersFromCachedMessages();
    _loadPersistedConversations();
    _scheduleServerSync();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (chat.isConnected) chat.listConnections();
    });

    _startPresencePolling();
  }

  void _startPresencePolling() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (chat.isConnected) chat.listConnections();
    });
  }

  void _stopPresencePolling() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  void _scheduleChatReconnect() {
    if (_reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      if (_token != null && !chat.isConnected) {
        unawaited(_connectChat());
      }
    });
  }

  void _scheduleServerSync() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (chat.isConnected) _syncAllConversationsFromServer();
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (chat.isConnected) {
        _indexPeersFromCachedMessages();
        _syncAllConversationsFromServer();
      }
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (chat.isConnected) {
        _indexPeersFromCachedMessages();
        _loadPersistedConversations();
        notifyListeners();
      }
    });
  }

  /// Pull history for every known peer (store, cache, contacts, live chats).
  void _syncAllConversationsFromServer() {
    if (!chat.isConnected) return;
    final meId = _me?.uuid;
    if (meId == null) return;

    final peers = <String>{
      ..._conversationStore.peerNames.keys,
      ..._conversations.keys,
      ..._contacts.map((c) => c.uuid),
    };

    for (final id in peers) {
      final peerId = _canonicalPeerId(id);
      if (peerId == meId) continue;
      _conversations.putIfAbsent(peerId, () => []);
      chat.requestHistory(peerId);
    }
    _conversationStore.save();
    notifyListeners();
  }

  void _indexPeersFromCachedMessages() {
    final meId = _me?.uuid;
    for (final entry in _conversations.entries) {
      final peerId = _canonicalPeerId(entry.key);
      if (peerId.isNotEmpty) {
        _rememberPeer(peerId, _nameForPeer(peerId));
      }
      for (final m in entry.value) {
        final other =
            meId != null && m.senderId == meId ? m.receiverId : m.senderId;
        if (other.isEmpty || other == meId) continue;
        _rememberPeer(_canonicalPeerId(other), _nameForPeer(other));
      }
    }
  }

  Future<void> _applyAccountStorage(String userId) async {
    await _conversationStore.setUserScope(userId);
    await _messageCache.setUserScope(userId);
    _conversations.clear();
    _conversations.addAll(await _messageCache.load());
    _indexPeersFromCachedMessages();
    final peerCount = _conversationStore.peerNames.length;
    log.info(
      'Loaded ${_conversations.length} cached thread(s), $peerCount saved peer(s)',
      category: 'app',
      banner: false,
    );
    notifyListeners();
    _scheduleProfilePrefetch();
  }

  Future<void> loadMyProfile() async {
    if (_token == null || _me == null) return;
    final profile = await auth.fetchUserProfile(
      token: _token!,
      username: _me!.username,
      uuid: _me!.uuid,
    );
    if (profile != null) {
      _me = profile;
      notifyListeners();
    }
  }

  void _loadPersistedConversations() {
    if (!chat.isConnected) return;
    final meId = _me?.uuid;
    final peers = <String>{
      ..._conversationStore.peerNames.keys,
      ..._conversations.keys,
    };
    for (final id in peers) {
      final peerId = _canonicalPeerId(id);
      if (peerId.isEmpty || peerId == meId) continue;
      _conversations.putIfAbsent(peerId, () => []);
      chat.requestHistory(peerId);
    }
  }

  Future<void> _cancelChatSubscriptions() async {
    _stopPresencePolling();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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
    await _connectionStateSub?.cancel();
    await _groupUpdatedSub?.cancel();
    await _groupDeletedSub?.cancel();
    await _messageDeletedSub?.cancel();
    await _groupMessageDeletedSub?.cancel();
    await _groupMembershipChangedSub?.cancel();
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
    _connectionStateSub = null;
    _groupUpdatedSub = null;
    _groupDeletedSub = null;
    _messageDeletedSub = null;
    _groupMessageDeletedSub = null;
    _groupMembershipChangedSub = null;
  }

  void _onGroups(List<ChatGroup> groups) {
    _groups
      ..clear()
      ..addAll(groups)
      ..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void _onGroupUpdated(ChatGroup group) {
    final index = _groups.indexWhere((item) => item.uuid == group.uuid);
    if (index == -1) {
      _groups.add(group);
    } else {
      _groups[index] = group;
    }
    _groups.sort((a, b) => a.name.compareTo(b.name));
    if (_activeGroupId == group.uuid) _activeGroupName = group.name;
    notifyListeners();
  }

  void _onGroupDeleted(String groupId) {
    _groups.removeWhere((group) => group.uuid == groupId);
    _groupConversations.remove(groupId);
    if (_activeGroupId == groupId) closeGroupChat();
    notifyListeners();
  }

  void _onMessageDeleted(MessageDeletedEvent event) {
    var changed = false;
    for (final messages in _conversations.values) {
      final before = messages.length;
      messages.removeWhere((message) => message.uuid == event.messageUuid);
      changed = changed || before != messages.length;
    }
    if (changed) {
      _schedulePersist();
      notifyListeners();
    }
  }

  void _onGroupMessageDeleted(GroupMessageDeletedEvent event) {
    final messages = _groupConversations[event.groupId];
    if (messages == null) return;
    messages.removeWhere((message) => message.uuid == event.messageUuid);
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
    if (msg.senderId != _me?.uuid) {
      final group = _groups.cast<ChatGroup?>().firstWhere(
            (item) => item?.uuid == msg.groupId,
            orElse: () => null,
          );
      final inActiveGroup = _activeGroupId == msg.groupId;
      NotificationService.instance.showIncomingMessage(
        peerId: 'group:${msg.groupId}',
        title: group?.name ?? 'Group message',
        body: msg.previewText.isNotEmpty ? msg.previewText : 'New message',
        force: !inActiveGroup,
      );
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
    NotificationService.instance.setActiveChat('group:$groupId');
    unawaited(BackgroundState.updateAppState(
      inForeground: true,
      activeChatPeerId: 'group:$groupId',
    ));
    _groupConversations.putIfAbsent(groupId, () => []);
    chat.requestGroupHistory(groupId);
    chat.markGroupRead(groupId);
    notifyListeners();
  }

  void closeGroupChat() {
    _activeGroupId = null;
    _activeGroupName = null;
    NotificationService.instance.setActiveChat(null);
    unawaited(BackgroundState.updateAppState(inForeground: true));
    notifyListeners();
  }

  void deleteGroupMessage(GroupMessage message, {bool forEveryone = false}) {
    if (message.uuid.startsWith('local-')) return;
    chat.deleteGroupMessage(message.uuid, forEveryone: forEveryone);
  }

  void leaveActiveGroup() {
    final groupId = _activeGroupId;
    if (groupId == null) return;
    chat.leaveGroup(groupId);
    _groups.removeWhere((group) => group.uuid == groupId);
    _groupConversations.remove(groupId);
    closeGroupChat();
  }

  /// Splits comma/semicolon/newline-separated usernames.
  static List<String> parseUsernameList(String raw) {
    return raw
        .split(RegExp(r'[,;\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<({String userId, String username})?> _resolveUsername(
    String query,
  ) async {
    final peer = await resolvePeer(query);
    if (peer == null) return null;
    return (userId: peer.peerId, username: peer.username);
  }

  /// Adds a member to the active group. [username] is resolved via auth (not UUID).
  Future<String?> addGroupMemberByUsername(String username) async {
    if (_activeGroupId == null) return 'Open a group first';
    if (_token == null) return 'Not signed in';
    if (!chat.isConnected) return 'Waiting for chat connection…';

    final trimmed = _normalizeQuery(username);
    if (trimmed.isEmpty) return 'Enter a username';

    final resolved = await _resolveUsername(trimmed);
    if (resolved == null) {
      return lastPeerLookupError ?? 'User "$trimmed" not found';
    }
    if (resolved.userId == _me?.uuid) {
      return 'You are already in this group';
    }

    chat.addGroupMember(groupId: _activeGroupId!, userId: resolved.userId);
    _rememberPeer(resolved.userId, resolved.username);
    log.info('Added ${resolved.username} to group', category: 'group');
    _setStatus('Added ${resolved.username} to group', category: 'group');
    return null;
  }

  /// Creates a group; [memberUsernames] are resolved to UUIDs before create.
  Future<({bool ok, String? message})> createGroup(
    String name, {
    List<String> memberUsernames = const [],
    String? description,
    bool isPrivate = false,
    bool isChannel = false,
  }) async {
    if (!chat.isConnected) {
      return (ok: false, message: 'Waiting for chat connection…');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return (ok: false, message: 'Enter a group name');
    }

    final memberIds = <String>[];
    final failed = <String>[];
    for (final raw in memberUsernames) {
      final u = _normalizeQuery(raw);
      if (u.isEmpty) continue;
      final resolved = await _resolveUsername(u);
      if (resolved == null) {
        failed.add(u);
        continue;
      }
      if (resolved.userId == _me?.uuid) continue;
      if (!memberIds.contains(resolved.userId)) {
        memberIds.add(resolved.userId);
        _rememberPeer(resolved.userId, resolved.username);
      }
    }

    final cleanDescription = description?.trim();
    chat.createGroup(
      name: trimmed,
      description: cleanDescription?.isEmpty == true ? null : cleanDescription,
      memberIds: memberIds,
      isPrivate: isPrivate,
      isChannel: isChannel,
    );
    log.info('Creating group "$trimmed" (${memberIds.length} members)',
        category: 'group');

    if (failed.isNotEmpty) {
      return (
        ok: true,
        message:
            'Group created. Could not find: ${failed.map((u) => '"$u"').join(', ')}',
      );
    }
    return (ok: true, message: null);
  }

  Future<({Uint8List bytes, String filename, String mimeType})?>
      pickFileForUpload() async {
    final pick = await FilePicker.platform.pickFiles(withData: true);
    if (pick == null || pick.files.isEmpty) return null;

    final platformFile = pick.files.first;
    final bytes = platformFile.bytes;
    if (bytes == null || bytes.isEmpty) {
      _setError('Could not read the selected file', category: 'file');
      return null;
    }

    final filename = platformFile.name.isNotEmpty
        ? platformFile.name
        : 'file_${DateTime.now().millisecondsSinceEpoch}';
    var mimeType = lookupMimeType(filename);
    if (mimeType == null && platformFile.extension != null) {
      mimeType = 'application/${platformFile.extension}';
    }
    mimeType ??= 'application/octet-stream';

    final limitError = FileLimits.validateUpload(
      sizeBytes: bytes.length,
      filename: filename,
      mimeType: mimeType,
    );
    if (limitError != null) {
      _setError(limitError, category: 'file');
      return null;
    }

    return (
      bytes: Uint8List.fromList(bytes),
      filename: filename,
      mimeType: mimeType,
    );
  }

  void sendGroupMessage(String text) {
    if (_activeGroupId == null || text.trim().isEmpty) return;
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
    if (!serverSettings.isConfigured) {
      _setError('Set auth, chat, and file URLs in Server settings');
      return false;
    }
    if (!chat.isConnected) {
      _setStatus('Attachment will send after chat reconnects',
          category: 'chat');
    }

    final picked = await pickFileForUpload();
    if (picked == null) return false;

    _loading = true;
    _uploadProgress = 0;
    _error = null;
    log.info('Uploading ${picked.filename} to group…', category: 'file');
    notifyListeners();
    try {
      final fileId = await file.uploadFile(
        sessionToken: _token!,
        bytes: picked.bytes,
        filename: picked.filename,
        mimeType: picked.mimeType,
        onProgress: _setUploadProgress,
      );
      log.info('Group file uploaded ($fileId)', category: 'file');
      await _fileMetadataCache.put(MessengerFileInfo(
        fileId: fileId,
        filename: picked.filename,
        originalSize: picked.bytes.length,
        storedSize: picked.bytes.length,
        isCompressed: false,
        mimeType: picked.mimeType,
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
    } on FileServiceException catch (e) {
      _setError(e.message, category: 'file');
      return false;
    } catch (e) {
      _setError('Upload failed: $e', category: 'file');
      return false;
    } finally {
      _loading = false;
      _uploadProgress = null;
      notifyListeners();
    }
  }

  void _onMessage(Message msg) {
    final rawPeer = msg.senderId == _me?.uuid ? msg.receiverId : msg.senderId;
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
    _schedulePersist();
  }

  void _onHistory(Map<String, List<Message>> event) {
    event.forEach((userId, msgs) {
      final peerId = _canonicalPeerId(userId);
      _rememberPeer(peerId, _nameForPeer(peerId));
      _conversations.putIfAbsent(peerId, () => []);
      _mergeConversation(peerId, msgs);
    });
    final active = _activeChatUserId;
    if (active != null) {
      _markIncomingRead(active);
    }
    _schedulePersist();
    _scheduleProfilePrefetch();
    notifyListeners();
  }

  void _onConnections(List<Connection> conns) {
    _contacts = conns.where((c) => c.uuid != _me?.uuid).toList();
    _onlinePeerIds
      ..clear()
      ..addAll(_contacts.map((c) => c.uuid));
    for (final c in _contacts) {
      _rememberPeer(c.uuid, c.username);
      if (!_conversations.containsKey(c.uuid)) {
        chat.requestHistory(c.uuid);
      }
    }
    _scheduleProfilePrefetch();
    notifyListeners();
  }

  void _onReadReceipt(String userId) {
    final peerId = _canonicalPeerId(userId);
    final msgs = _conversations[peerId];
    if (msgs != null) {
      _conversations[peerId] = msgs
          .map((m) => m.senderId == _me?.uuid ? m.copyWith(status: 2) : m)
          .toList();
      _schedulePersist();
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
      if (entry.value.toLowerCase() == id.toLowerCase() &&
          _looksLikeUuid(entry.key)) {
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

    final fromContacts = await _resolvePeerFromContacts(trimmed);
    if (fromContacts != null) {
      _rememberPeer(fromContacts.peerId, fromContacts.username);
      return fromContacts;
    }

    final lookup = await auth.lookupPeer(token: _token!, query: trimmed);
    if (lookup.result != null) {
      final r = lookup.result!;
      _rememberPeer(r.uuid, r.username);
      return (peerId: r.uuid, username: r.username);
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
    unawaited(BackgroundState.updateAppState(
      inForeground: true,
      activeChatPeerId: peerId,
    ));
    _rememberPeer(peerId, username);
    _conversations.putIfAbsent(peerId, () => []);
    chat.requestHistory(peerId);
    _markIncomingRead(peerId);
    chat.markRead(peerId);
    unawaited(refreshPeerProfile(peerId));
    notifyListeners();
  }

  UserInfo? peerProfile(String peerId) =>
      _peerProfiles[_canonicalPeerId(peerId)];

  String peerUsername(String peerId) {
    final id = _canonicalPeerId(peerId);
    return _peerProfiles[id]?.username ??
        _conversationStore.nameFor(id) ??
        _contacts
            .cast<Connection?>()
            .firstWhere((c) => c!.uuid == id, orElse: () => null)
            ?.username ??
        _shortPeerLabel(id);
  }

  String peerDisplayName(String peerId) {
    final id = _canonicalPeerId(peerId);
    return _peerProfiles[id]?.displayName ?? peerUsername(id);
  }

  ProfileExtras peerExtras(String peerId) =>
      ProfileExtras.parse(peerProfile(peerId)?.additionalInfo);

  bool isPeerOnline(String peerId) =>
      _onlinePeerIds.contains(_canonicalPeerId(peerId));

  String? _authLookupUsername(String peerId) {
    final id = _canonicalPeerId(peerId);
    final stored = _conversationStore.nameFor(id);
    if (stored != null &&
        stored.isNotEmpty &&
        !_looksLikeUuid(stored) &&
        stored != id) {
      return stored;
    }
    for (final c in _contacts) {
      if (c.uuid == id && c.username.isNotEmpty) return c.username;
    }
    final cached = _peerProfiles[id]?.username;
    if (cached != null &&
        cached.isNotEmpty &&
        !_looksLikeUuid(cached) &&
        cached != id) {
      return cached;
    }
    if (!_looksLikeUuid(id)) return id;
    return null;
  }

  void _setPeerProfileFallback(String peerId, {String? username}) {
    final id = _canonicalPeerId(peerId);
    final name = username ?? peerUsername(id);
    _peerProfiles[id] = UserInfo(uuid: id, username: name);
    if (!_looksLikeUuid(name)) {
      _rememberPeer(id, name);
    }
  }

  Future<void> refreshPeerProfile(String peerId) async {
    if (_token == null) return;
    final canonical = _canonicalPeerId(peerId);

    var lookupName = _authLookupUsername(canonical);
    String resolvedUuid = canonical;

    if (lookupName == null && _looksLikeUuid(canonical)) {
      final identity = await auth.resolvePeerIdentity(
        token: _token!,
        query: canonical,
      );
      if (identity != null) {
        resolvedUuid = identity.uuid;
        if (!_looksLikeUuid(identity.username)) {
          lookupName = identity.username;
          _rememberPeer(resolvedUuid, identity.username);
        }
      }
    }

    if (lookupName == null) {
      _setPeerProfileFallback(canonical);
      notifyListeners();
      return;
    }

    final profile = await auth.fetchUserProfile(
      token: _token!,
      username: lookupName,
      uuid: _looksLikeUuid(resolvedUuid) ? resolvedUuid : null,
    );

    if (profile == null) {
      _setPeerProfileFallback(resolvedUuid, username: lookupName);
      notifyListeners();
      return;
    }

    final storeId = _looksLikeUuid(canonical) ? canonical : resolvedUuid;
    final prev = _peerProfiles[storeId];
    _peerProfiles[storeId] = profile;
    _rememberPeer(storeId, profile.username);

    if (prev != null &&
        (prev.firstName != profile.firstName ||
            prev.lastName != profile.lastName ||
            prev.additionalInfo != profile.additionalInfo)) {
      log.info('Profile updated for ${profile.username}', category: 'auth');
    }
    notifyListeners();
  }

  /// Loads names/avatars for conversation list (throttled).
  Future<void> prefetchPeerProfiles(Iterable<String> peerIds) async {
    if (_token == null) return;
    for (final raw in peerIds) {
      final id = _canonicalPeerId(raw);
      if (id.isEmpty || id == _me?.uuid) continue;
      final cached = _peerProfiles[id];
      if (cached != null &&
          (cached.firstName != null ||
              cached.lastName != null ||
              cached.additionalInfo != null)) {
        continue;
      }
      await refreshPeerProfile(id);
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  void _scheduleProfilePrefetch() {
    final ids = conversationPeers.map((p) => p.userId).toList();
    if (ids.isEmpty) return;
    unawaited(prefetchPeerProfiles(ids));
  }

  void closeChat() {
    _activeChatUserId = null;
    _activeChatUsername = null;
    _activeGroupId = null;
    _activeGroupName = null;
    NotificationService.instance.setActiveChat(null);
    unawaited(BackgroundState.updateAppState(inForeground: true));
    notifyListeners();
  }

  void sendMessage(String text) {
    if (_activeChatUserId == null || text.trim().isEmpty) return;
    if (!chat.isConnected) {
      _setStatus('Message queued — reconnecting…', category: 'chat');
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

  void deleteMessage(Message message, {bool forEveryone = false}) {
    if (message.uuid.startsWith('local-')) return;
    chat.deleteMessage(message.uuid, forEveryone: forEveryone);
  }

  /// Picks a file, uploads via file-service, then sends a chat message with [file_id].
  /// Chat-service grants the recipient access automatically.
  Future<bool> sendFileAttachment({String? caption}) async {
    if (_activeChatUserId == null || _token == null) return false;
    if (!serverSettings.isConfigured) {
      _setError('Set auth, chat, and file URLs in Server settings');
      return false;
    }
    if (!chat.isConnected) {
      _setStatus('Attachment will send after chat reconnects',
          category: 'chat');
    }

    final picked = await pickFileForUpload();
    if (picked == null) return false;

    _loading = true;
    _uploadProgress = 0;
    _error = null;
    log.info('Uploading ${picked.filename}…', category: 'file');
    notifyListeners();

    try {
      final fileId = await file.uploadFile(
        sessionToken: _token!,
        bytes: picked.bytes,
        filename: picked.filename,
        mimeType: picked.mimeType,
        onProgress: _setUploadProgress,
      );
      log.info('Uploaded ${picked.filename}', category: 'file');

      final info = MessengerFileInfo(
        fileId: fileId,
        filename: picked.filename,
        originalSize: picked.bytes.length,
        storedSize: picked.bytes.length,
        isCompressed: false,
        mimeType: picked.mimeType,
      );
      await _fileMetadataCache.put(info);

      final receiverId = _canonicalPeerId(_activeChatUserId!);
      final meId = _me!.uuid;
      final trimmedCaption = caption?.trim();
      final hasCaption = trimmedCaption != null && trimmedCaption.isNotEmpty;

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
      _setError(e.message, category: 'file');
      return false;
    } catch (e) {
      _setError('Upload failed: $e', category: 'file');
      return false;
    } finally {
      _loading = false;
      _uploadProgress = null;
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
    await ensureFileMetadata(fileId);
  }

  Future<MessengerFileInfo?> ensureFileMetadata(String fileId) async {
    final cached = _fileMetadataCache.get(fileId);
    if (cached != null) return cached;
    if (_token == null) return null;
    try {
      final files = await file.listFiles(_token!);
      for (final f in files) {
        await _fileMetadataCache.put(f);
      }
    } catch (_) {}
    return _fileMetadataCache.get(fileId);
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
    String? username,
    String? dateOfBirth,
    String? bio,
    String? avatarFileId,
  }) async {
    if (_token == null) return false;
    final fnOk = await auth.changeFirstName(_token!, firstName);
    final lnOk = await auth.changeLastName(_token!, lastName);
    final cleanUsername = username?.trim();
    var usernameOk = true;
    var usernameChanged = false;
    if (cleanUsername != null &&
        cleanUsername.isNotEmpty &&
        cleanUsername != _me?.username) {
      usernameOk = await auth.changeUsername(_token!, cleanUsername);
      if (usernameOk && _me != null) {
        usernameChanged = true;
        _me = UserInfo(
          uuid: _me!.uuid,
          username: cleanUsername,
          firstName: _me!.firstName,
          lastName: _me!.lastName,
          dateOfBirth: _me!.dateOfBirth,
          additionalInfo: _me!.additionalInfo,
        );
      }
    }
    var birthDateOk = true;
    if (dateOfBirth != null && dateOfBirth.trim() != (_me?.dateOfBirth ?? '')) {
      birthDateOk = await auth.changeDateOfBirth(_token!, dateOfBirth.trim());
    }

    final extras = ProfileExtras.parse(_me?.additionalInfo);
    final serialized = ProfileExtras(
      bio: bio ?? extras.bio,
      avatarFileId: avatarFileId ?? extras.avatarFileId,
    ).serialize();
    var extrasOk = true;
    if (serialized != (_me?.additionalInfo ?? '')) {
      extrasOk = await auth.changeAdditionalInfo(_token!, serialized);
    }

    await loadMyProfile();
    if (usernameChanged) await _connectChat();
    return fnOk && lnOk && usernameOk && birthDateOk && extrasOk;
  }

  Future<String?> uploadAvatarImage() async {
    if (_token == null) return null;
    final picked = await pickFileForUpload();
    if (picked == null) return null;

    final mime = picked.mimeType.toLowerCase();
    if (!mime.startsWith('image/')) {
      _setError('Avatar must be an image', category: 'file');
      return null;
    }

    _loading = true;
    _uploadProgress = 0;
    notifyListeners();
    try {
      final fileId = await file.uploadFile(
        sessionToken: _token!,
        bytes: picked.bytes,
        filename: picked.filename,
        mimeType: picked.mimeType,
        onProgress: _setUploadProgress,
      );
      await _fileMetadataCache.put(MessengerFileInfo(
        fileId: fileId,
        filename: picked.filename,
        originalSize: picked.bytes.length,
        storedSize: picked.bytes.length,
        isCompressed: false,
        mimeType: picked.mimeType,
      ));
      return fileId;
    } catch (e) {
      _setError('Avatar upload failed: $e', category: 'file');
      return null;
    } finally {
      _loading = false;
      _uploadProgress = null;
      notifyListeners();
    }
  }

  Future<String> pingAuth() => auth.ping();

  Future<String> pingChatReachability() => chat.pingReachability();

  Future<String> pingChatSession() => chat.pingSession();

  Future<void> logout() async {
    if (_token != null) await auth.setOffline(_token!);
    await _cancelChatSubscriptions();
    await chat.disconnect(clearPending: true);
    _token = null;
    _me = null;
    _conversations.clear();
    _contacts.clear();
    _peerProfiles.clear();
    _onlinePeerIds.clear();
    _activeChatUserId = null;
    _activeGroupId = null;
    _activeGroupName = null;
    _groups.clear();
    _groupConversations.clear();
    _chatStatus = null;
    log.info('Signed out', category: 'auth');
    log.setBanner(null);
    await _conversationStore.setUserScope(null);
    await _messageCache.setUserScope(null);
    await NotificationService.instance.cancelAll();
    await BackgroundMessaging.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    await prefs.remove('user_uuid');
    notifyListeners();
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _stopPresencePolling();
    unawaited(_cancelChatSubscriptions());
    chat.dispose();
    super.dispose();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
