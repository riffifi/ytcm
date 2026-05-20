import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/group_models.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'conversation_store.dart';
import 'file_transfer_service.dart';
import 'messenger_notifications.dart';
import 'locale_controller.dart';
import 'server_settings.dart';
import 'package:path_provider/path_provider.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AuthService auth;
  ChatService chat;
  final ServerSettings serverSettings;
  final LocaleController localeController;
  final ConversationStore _conversationStore = ConversationStore();

  String? _token;
  UserInfo? _me;
  bool _loading = false;
  String? _error;
  String? _chatStatus;

  final Map<String, List<Message>> _conversations = {};
  List<Connection> _contacts = [];
  final Map<String, String> _peerLabels = {};
  String? _activeChatUserId;
  String? _activeChatUsername;
  String? _activeGroupId;
  String? _activeGroupName;

  final Map<String, UserPresence?> _presence = {};
  final Map<String, double> _uploadProgress = {};
  final Map<String, Uint8List?> _peerAvatarCache = {};
  final List<GroupInfo> _groups = [];
  final Map<String, List<GroupMessage>> _groupMessages = {};
  GroupDetails? _lastGroupDetails;

  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  String? _chatStatusKey;

  StreamSubscription<Message>? _msgSub;
  StreamSubscription<Map<String, List<Message>>>? _historySub;
  StreamSubscription<List<Connection>>? _connectionsSub;
  StreamSubscription<String>? _readSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<UserInfo>? _joinSub;
  StreamSubscription<GroupListEvent>? _groupListSub;
  StreamSubscription<GroupMessage>? _groupMsgSub;
  StreamSubscription<Map<String, List<GroupMessage>>>? _groupHistSub;
  StreamSubscription<GroupDetails>? _groupDetailsSub;
  StreamSubscription<Map<String, String>>? _groupReadSub;
  StreamSubscription<Map<String, dynamic>>? _msgDeletedSub;

  String? get token => _token;
  UserInfo? get me => _me;
  bool get loading => _loading;
  String? get error => _error;
    String? get chatStatus =>
      _chatStatus ??
      (_chatStatusKey == null ? null : localeController.t(_chatStatusKey!));
  Map<String, List<Message>> get conversations => _conversations;
  List<Connection> get contacts => _contacts;
  String? get activeChatUserId => _activeChatUserId;
  String? get activeChatUsername => _activeChatUsername;
  String? get activeGroupId => _activeGroupId;
  String? get activeGroupName => _activeGroupName;
  bool get isLoggedIn => _token != null && _me != null;
  List<GroupInfo> get groups => List.unmodifiable(_groups);
  GroupDetails? get lastGroupDetails => _lastGroupDetails;

  List<ConversationPeer> get conversationPeers {
    final ids = <String>{
      ..._conversationStore.peerNames.keys,
      ..._conversations.keys,
      ..._contacts.map((c) => c.uuid),
    };

    final peers = ids.map((id) {
      Connection? fromContact;
      for (final c in _contacts) {
        if (c.uuid == id) {
          fromContact = c;
          break;
        }
      }
      final displayName = _peerLabels[id] ??
          _conversationStore.nameFor(id) ??
          fromContact?.username ??
          _shortPeerLabel(id);
      return ConversationPeer(userId: id, username: displayName);
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

  AppState({required this.serverSettings, required this.localeController})
      : auth = AuthService(baseUrl: serverSettings.authUrl),
        chat = ChatService(wsUrl: serverSettings.chatUrl) {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (_token == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      auth.setOffline(_token!);
    } else if (state == AppLifecycleState.resumed) {
      auth.setOnline(_token!);
    }
  }

  void _rebuildServices() {
    auth = AuthService(baseUrl: serverSettings.authUrl);
    chat = ChatService(wsUrl: serverSettings.chatUrl);
  }

  FileTransferService _files() =>
      FileTransferService(wsUrl: serverSettings.fileWsUrl);

  Future<Uint8List?> downloadFileBytes(String fileId) async {
    final tok = _token;
    if (tok == null) return null;
    try {
      return await _files().downloadFile(sessionToken: tok, fileId: fileId);
    } catch (_) {
      return null;
    }
  }

  /// Save bytes to a user-visible location (application documents or downloads folder).
  /// Returns the saved absolute path on success or null.
  Future<String?> saveBytesToDevice(Uint8List bytes, String filename) async {
    try {
      Directory? dir;
      // Prefer Downloads if available
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {
        dir = null;
      }
      if (dir == null) {
        try {
          dir = await getApplicationDocumentsDirectory();
        } catch (_) {
          dir = Directory.systemTemp;
        }
      }
      final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final outPath = p.join(dir.path, safeName);
      final f = File(outPath);
      await f.writeAsBytes(bytes, flush: true);
      return outPath;
    } catch (e, st) {
      debugPrint('saveBytesToDevice failed: $e\n$st');
      return null;
    }
  }

  Future<void> reconnectWithNewSettings() async {
    await _cancelChatSubscriptions();
    chat.disconnect();
    _conversations.clear();
    _contacts.clear();
    _groups.clear();
    _groupMessages.clear();
    _presence.clear();
    _rebuildServices();

    if (_token == null) {
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

  void _setUploadProgress(String localId, double progress) {
    _uploadProgress[localId] = progress;
    notifyListeners();
  }

  void _clearUploadProgress(String localId) {
    _uploadProgress.remove(localId);
    notifyListeners();
  }

  double? getUploadProgress(String localId) => _uploadProgress[localId];

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
      _error = localeController.t('auth.sign_in_failed');
      notifyListeners();
      return false;
    }

    final info = await auth.getSessionInfo(token);
    if (info == null) {
      _loading = false;
      _error = localeController.t('auth.session_error');
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
      _error = localeController.t('auth.register_failed');
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
        _chatStatusKey = null;
        _chatStatus = text;
        notifyListeners();
      }
    });
    _joinSub = chat.joinEvents.listen((info) {
      _chatStatus = null;
      _chatStatusKey = 'status.connected';
      _rememberPeer(info.uuid, info.username);
      _loadPersistedConversations();
      chat.listConnections();
      chat.listGroups();
      MessengerNotifications.requestPermissionsIfNeeded();
      notifyListeners();
    });

    _groupListSub = chat.groupListEvents.listen(_onGroupListEvent);
    _groupMsgSub = chat.groupMessages.listen(_onGroupMessage);
    _groupHistSub = chat.groupHistoryEvents.listen(_onGroupHistory);
    _groupDetailsSub = chat.groupDetailsEvents.listen((d) {
      _lastGroupDetails = d;
      notifyListeners();
    });
    _groupReadSub = chat.groupReadReceipts.listen(_onGroupReadReceipt);
    _msgDeletedSub = chat.messageDeletedEvents.listen(_onDmMessageDeleted);

    _loadPersistedConversations();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (chat.isConnected) {
        chat.listConnections();
        chat.listGroups();
      }
    });
  }

  void _onDmMessageDeleted(Map<String, dynamic> ev) {
    final uuid = ev['message_uuid'] as String?;
    if (uuid == null) return;
    for (final e in _conversations.entries) {
      final list = e.value;
      final idx = list.indexWhere((m) => m.uuid == uuid);
      if (idx != -1) {
        list.removeAt(idx);
        notifyListeners();
        return;
      }
    }
  }

  void _onGroupReadReceipt(Map<String, String> m) {
    final gid = m['group_id'];
    final by = m['by_user_id'];
    if (gid == null || by == null) return;
    final list = _groupMessages[gid];
    if (list == null) return;
    final meId = _me?.uuid;
    _groupMessages[gid] = list.map((msg) {
      if (meId != null && msg.senderId == meId) {
        final readers = List<String>.from(msg.whoRead);
        if (!readers.contains(by)) readers.add(by);
        return GroupMessage(
          uuid: msg.uuid,
          groupId: msg.groupId,
          senderId: msg.senderId,
          text: msg.text,
          fileId: msg.fileId,
          createdAt: msg.createdAt,
          whoDelivered: msg.whoDelivered,
          whoRead: readers,
          deletedForEveryone: msg.deletedForEveryone,
          status: msg.status,
        );
      }
      return msg;
    }).toList();
    notifyListeners();
  }

  void _onGroupListEvent(GroupListEvent ev) {
    switch (ev.kind) {
      case GroupListKind.replace:
        _groups
          ..clear()
          ..addAll(ev.groups ?? []);
        break;
      case GroupListKind.upsert:
        final g = ev.group;
        if (g == null) break;
        final i = _groups.indexWhere((x) => x.uuid == g.uuid);
        if (i >= 0) {
          _groups[i] = g;
        } else {
          _groups.add(g);
        }
        break;
      case GroupListKind.remove:
        final id = ev.groupId;
        if (id != null) {
          _groups.removeWhere((x) => x.uuid == id);
          _groupMessages.remove(id);
        }
        break;
    }
    notifyListeners();
  }

  void _onGroupMessage(GroupMessage m) {
    _groupMessages.putIfAbsent(m.groupId, () => []);
    final list = _groupMessages[m.groupId]!;
    final idx = list.indexWhere((x) => x.uuid == m.uuid);
    if (idx == -1) {
      list.add(m);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      list[idx] = m;
    }

    if (m.senderId != _me?.uuid) {
      String gname = m.groupId;
      for (final g in _groups) {
        if (g.uuid == m.groupId) {
          gname = g.name;
          break;
        }
      }
      final show = _lifecycle != AppLifecycleState.resumed ||
          _activeGroupId != m.groupId;
      if (show) {
        MessengerNotifications.showGroup(
          groupId: m.groupId,
          title: gname,
          body: _localizedPreview(m.previewText, m.fileId != null),
        );
      }
    }
    notifyListeners();
  }

  void _onGroupHistory(Map<String, List<GroupMessage>> ev) {
    ev.forEach((gid, msgs) {
      _groupMessages[gid] = msgs;
    });
    notifyListeners();
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
    await _groupListSub?.cancel();
    await _groupMsgSub?.cancel();
    await _groupHistSub?.cancel();
    await _groupDetailsSub?.cancel();
    await _groupReadSub?.cancel();
    await _msgDeletedSub?.cancel();
    _msgSub = null;
    _historySub = null;
    _connectionsSub = null;
    _readSub = null;
    _errorSub = null;
    _joinSub = null;
    _groupListSub = null;
    _groupMsgSub = null;
    _groupHistSub = null;
    _groupDetailsSub = null;
    _groupReadSub = null;
    _msgDeletedSub = null;
  }

  Future<void> _notifyIncomingDm(Message msg, String peerId) async {
    if (msg.senderId == _me?.uuid) return;
    final inThisChat = _activeChatUserId == peerId &&
        _lifecycle == AppLifecycleState.resumed;
    if (inThisChat) return;
    final name = _nameForPeer(peerId);
    final body = _localizedPreview(msg.previewText, msg.fileId != null);
    await MessengerNotifications.showDm(
      peerId: peerId,
      title: name,
      body: body,
    );
  }

  void _onMessage(Message msg) {
    final peerId =
        msg.senderId == _me?.uuid ? msg.receiverId : msg.senderId;

    if (msg.senderId != _me?.uuid) {
      String? senderName;
      for (final c in _contacts) {
        if (c.uuid == msg.senderId) {
          senderName = c.username;
          break;
        }
      }
      if (senderName != null) {
        _rememberPeer(msg.senderId, senderName);
      }
    }
    _rememberPeer(peerId, _nameForPeer(peerId));
    _conversations.putIfAbsent(peerId, () => []);

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

    if (msg.senderId != _me?.uuid) {
      _notifyIncomingDm(msg, peerId);
    }
    notifyListeners();
  }

  /// Forward an existing message (DM or group message) to a single peer.
  Future<void> forwardMessage({
    required Message message,
    required String toUserId,
  }) async {
    final tok = _token;
    final meId = _me?.uuid;
    if (tok == null || meId == null) return;

    // optimistic in recipient conversation
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = Message(
      uuid: localId,
      senderId: meId,
      receiverId: toUserId,
      dialogId: '',
      text: message.text,
      fileId: null,
      createdAt: DateTime.now(),
      status: 0,
    );
    _conversations.putIfAbsent(toUserId, () => []);
    _conversations[toUserId]!.add(optimistic);
    notifyListeners();

    try {
      if (message.fileId != null) {
        // grant access to recipient
        await _files().grantAccess(sessionToken: tok, fileId: message.fileId!, userId: toUserId);
      }
      // send using chat service
      chat.sendMessage(receiverId: toUserId, text: message.text, fileId: message.fileId);
    } catch (_) {
      // on failure, remove optimistic
      final list = _conversations[toUserId];
      if (list != null) {
        list.removeWhere((m) => m.uuid == localId);
      }
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
    unawaited(_refreshContactProfiles());
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
    if (userId.isEmpty || username.isEmpty) return;
    _peerLabels[userId] = username;
    _conversationStore.setName(userId, username);
    _conversationStore.save();
  }

  String _nameForPeer(String peerId) {
    final label = _peerLabels[peerId];
    if (label != null && label.isNotEmpty) return label;
    for (final c in _contacts) {
      if (c.uuid == peerId) return c.username;
    }
    return _conversationStore.nameFor(peerId) ?? _shortPeerLabel(peerId);
  }

  Future<void> _refreshContactProfiles() async {
    final tok = _token;
    if (tok == null) return;
    for (final c in _contacts) {
      final profile = await auth.getUserProfile(tok, c.username, uuid: c.uuid);
      if (profile != null) {
        _rememberPeer(c.uuid, profile.displayName);
      }
    }
    notifyListeners();
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

  bool isPeerInConnections(String userId) {
    for (final c in _contacts) {
      if (c.uuid == userId) return true;
    }
    return false;
  }

  Future<void> refreshPresence(String userId) async {
    if (_token == null) return;
    final p = await auth.getUserPresence(_token!, userId);
    _presence[userId] = p;
    notifyListeners();
  }

  /// Subtitle for DM header / list (pass localized strings for online / template / unknown).
  String presenceSubtitle(
    String userId, {
    required String onlineLabel,
    required String lastSeenTemplate,
    required String unknownLabel,
  }) {
    if (isPeerInConnections(userId)) return onlineLabel;
    final p = _presence[userId];
    if (p == null) return unknownLabel;
    if (p.isOnline) return onlineLabel;
    final t = p.lastOnline;
    if (t == null) return unknownLabel;
    final time = DateFormat('HH:mm').format(t.toLocal());
    return lastSeenTemplate.replaceAll('{time}', time);
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
    if (q == me.username.toLowerCase()) {
      return (peerId: me.uuid, username: me.username);
    }
    return null;
  }

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
    return null;
  }

  String? _lastPeerLookupError;
  String? get lastPeerLookupError => _lastPeerLookupError;

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
      'No user "$trimmed". Try username.';
    return null;
  }

  String resolvePeerErrorHint(String query) =>
      _lastPeerLookupError ??
      localeController
        .t('conversations.lookup_hint')
        .replaceAll('{query}', query);

  void openChat(String userId, String username) {
    _activeChatUserId = userId;
    _activeChatUsername = username;
    _activeGroupId = null;
    _activeGroupName = null;
    _rememberPeer(userId, username);
    _conversations.putIfAbsent(userId, () => []);
    chat.requestHistory(userId);
    chat.markRead(userId);
    refreshPresence(userId);
    notifyListeners();
  }

  void closeChat() {
    _activeChatUserId = null;
    _activeChatUsername = null;
    notifyListeners();
  }

  void openGroupChat(String groupId, String name) {
    _activeGroupId = groupId;
    _activeGroupName = name;
    _activeChatUserId = null;
    _activeChatUsername = null;
    _groupMessages.putIfAbsent(groupId, () => []);
    chat.requestGroupHistory(groupId);
    chat.markGroupRead(groupId);
    chat.groupInfo(groupId);
    notifyListeners();
  }

  void closeGroupChat() {
    _activeGroupId = null;
    _activeGroupName = null;
    notifyListeners();
  }

  void requestGroupInfo(String groupId) {
    chat.groupInfo(groupId);
  }

  void createGroupByName(String name, {List<String>? memberIds}) {
    if (name.trim().isEmpty) return;
    chat.createGroup(name: name.trim(), memberIds: memberIds);
  }

  void addMemberToGroup(String groupId, String userId) {
    chat.addGroupMember(groupId, userId);
    chat.groupInfo(groupId);
  }

  void leaveActiveGroup() {
    final id = _activeGroupId;
    if (id == null) return;
    chat.leaveGroup(id);
    closeGroupChat();
  }

  void sendMessage(String text) {
    if (_activeChatUserId == null || text.trim().isEmpty) return;
    if (!chat.isConnected) {
      _chatStatus = localeController.t('status.waiting_for_chat_connection');
      notifyListeners();
      return;
    }
    final trimmed = text.trim();
    final receiverId = _activeChatUserId!;
    final meId = _me?.uuid;
    if (meId == null) return;

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

  Future<void> sendActiveDmFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String? caption,
  }) async {
    final receiverId = _activeChatUserId;
    final tok = _token;
    final meId = _me?.uuid;
    if (receiverId == null || tok == null || meId == null) return;
    if (!chat.isConnected) return;
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = Message(
      uuid: localId,
      senderId: meId,
      receiverId: receiverId,
      dialogId: '',
      text: caption,
      fileId: null,
      createdAt: DateTime.now(),
      status: 0,
    );
    _onMessage(optimistic);
    _setUploadProgress(localId, 0.0);

    try {
      final fileId = await _files().uploadBytes(
        sessionToken: tok,
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        onProgress: (sent, total) {
          final p = total > 0 ? sent / total : 0.0;
          _setUploadProgress(localId, p);
        },
      );
      await _files().grantAccess(
        sessionToken: tok,
        fileId: fileId,
        userId: receiverId,
      );

      // replace optimistic message with one containing real fileId
      final list = _conversations[receiverId];
      if (list != null) {
        final idx = list.indexWhere((m) => m.uuid == localId);
        if (idx != -1) {
          list[idx] = Message(
            uuid: localId,
            senderId: meId,
            receiverId: receiverId,
            dialogId: '',
            text: caption,
            fileId: fileId,
            createdAt: DateTime.now(),
            status: 0,
          );
        }
      }

      chat.sendMessage(
        receiverId: receiverId,
        text: caption,
        fileId: fileId,
      );
    } finally {
      _clearUploadProgress(localId);
      notifyListeners();
    }
  }

  Future<void> sendActiveGroupFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String? caption,
  }) async {
    final gid = _activeGroupId;
    final tok = _token;
    if (gid == null || tok == null || !chat.isConnected) return;

    for (var i = 0; i < 15; i++) {
      if (_lastGroupDetails?.group.uuid == gid &&
          (_lastGroupDetails?.members.isNotEmpty ?? false)) {
        break;
      }
      chat.groupInfo(gid);
      await Future.delayed(const Duration(milliseconds: 120));
    }

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = GroupMessage(
      uuid: localId,
      groupId: gid,
      senderId: _me!.uuid,
      text: caption,
      fileId: null,
      createdAt: DateTime.now(),
      whoDelivered: const [],
      whoRead: const [],
      deletedForEveryone: false,
      status: 'pending',
    );
    _groupMessages.putIfAbsent(gid, () => []);
    _groupMessages[gid]!.add(optimistic);
    _setUploadProgress(localId, 0.0);
    notifyListeners();

    try {
      final fileId = await _files().uploadBytes(
        sessionToken: tok,
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        onProgress: (sent, total) {
          final p = total > 0 ? sent / total : 0.0;
          _setUploadProgress(localId, p);
        },
      );

      for (final m in _lastGroupDetails?.members ?? const <GroupMember>[]) {
        if (m.userId != _me?.uuid) {
          try {
            await _files().grantAccess(
              sessionToken: tok,
              fileId: fileId,
              userId: m.userId,
            );
          } catch (_) {}
        }
      }

      // replace optimistic group message with final one
      final list = _groupMessages[gid];
      if (list != null) {
        final idx = list.indexWhere((m) => m.uuid == localId);
        if (idx != -1) {
          list[idx] = GroupMessage(
            uuid: localId,
            groupId: gid,
            senderId: _me!.uuid,
            text: caption,
            fileId: fileId,
            createdAt: DateTime.now(),
            whoDelivered: const [],
            whoRead: const [],
            deletedForEveryone: false,
            status: 'sent',
          );
        }
      }

      chat.sendGroupMessage(groupId: gid, text: caption, fileId: fileId);
    } finally {
      _clearUploadProgress(localId);
      notifyListeners();
    }
  }

  /// Update group metadata (name/description/avatar). If [avatarBytes] is
  /// provided, upload it first and grant access to group members.
  Future<bool> updateGroupDetails({
    required String groupId,
    String? name,
    String? description,
    Uint8List? avatarBytes,
    String avatarFilename = 'avatar.jpg',
    String avatarMime = 'image/jpeg',
  }) async {
    final tok = _token;
    if (tok == null || !chat.isConnected) return false;

    String? avatarId;
    if (avatarBytes != null) {
      try {
        avatarId = await _files().uploadBytes(
          sessionToken: tok,
          bytes: avatarBytes,
          filename: avatarFilename,
          mimeType: avatarMime,
        );

        // grant access to group members
        for (final m in _lastGroupDetails?.members ?? const <GroupMember>[]) {
          try {
            await _files().grantAccess(sessionToken: tok, fileId: avatarId, userId: m.userId);
          } catch (_) {}
        }
      } catch (e) {
        return false;
      }
    }

    try {
      chat.updateGroup(groupId: groupId, name: name, description: description, avatarId: avatarId);
      // refresh info
      chat.groupInfo(groupId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update current user's avatar by uploading bytes and notifying server.
  Future<bool> updateMyAvatar({
    required Uint8List bytes,
    String filename = 'avatar.jpg',
    String mimeType = 'image/jpeg',
  }) async {
    final tok = _token;
    if (tok == null) return false;
    try {
      final fileId = await _files().uploadBytes(
        sessionToken: tok,
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );
      // try to notify server via chat websocket (server may support update_profile)
      try {
        chat.updateProfileAvatar(avatarId: fileId);
      } catch (_) {}

      // If auth server supports HTTP profile update, try to refresh session info
      final info = await auth.getSessionInfo(tok);
      if (info != null) {
        _me = info;
        notifyListeners();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get avatar bytes for a peer (by userId). Will attempt to fetch profile via
  /// auth server if needed and then download the avatar file. Caches result.
  Future<Uint8List?> getPeerAvatarBytes(String userId, String username) async {
    if (_peerAvatarCache.containsKey(userId)) return _peerAvatarCache[userId];
    final tok = _token;
    if (tok == null) return null;
    try {
      final profile = await auth.getUserProfile(tok, username, uuid: userId);
      final avatarId = profile?.avatarId;
      if (avatarId == null) {
        _peerAvatarCache[userId] = null;
        return null;
      }
      final data = await downloadFileBytes(avatarId);
      _peerAvatarCache[userId] = data;
      return data;
    } catch (_) {
      _peerAvatarCache[userId] = null;
      return null;
    }
  }


  List<Message> getMessages(String userId) => _conversations[userId] ?? [];

  List<GroupMessage> getGroupMessages(String groupId) =>
      _groupMessages[groupId] ?? [];

  int getUnreadCount(String userId) {
    return _conversations[userId]
            ?.where((m) => m.senderId == userId && m.status < 2)
            .length ??
        0;
  }

  int getGroupUnreadCount(String groupId, String myId) {
    final list = _groupMessages[groupId];
    if (list == null) return 0;
    var n = 0;
    for (final m in list) {
      if (m.senderId == myId) continue;
      if (!m.isReadBy(myId)) n++;
    }
    return n;
  }

  Message? getLastMessage(String userId) {
    final msgs = _conversations[userId];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last;
  }

  GroupMessage? getLastGroupMessage(String groupId) {
    final msgs = _groupMessages[groupId];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last;
  }

  String lastMessagePreview(String userId) {
    final last = getLastMessage(userId);
    if (last == null) return localeController.t('chat.no_messages');
    final preview = _localizedPreview(last.previewText, last.fileId != null);
    if (preview.isNotEmpty) return preview;
    return localeController.t('chat.no_messages');
  }

  void sendGroupText(String text) {
    final gid = _activeGroupId;
    if (gid == null || text.trim().isEmpty || !chat.isConnected) return;
    chat.sendGroupMessage(groupId: gid, text: text.trim());
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
      _rememberPeer(_me!.uuid, _me!.displayName);
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
    _activeChatUsername = null;
    _activeGroupId = null;
    _activeGroupName = null;
    _chatStatus = null;
    _chatStatusKey = null;
    _groups.clear();
    _groupMessages.clear();
    _presence.clear();
    _conversationStore.clear();
    await _conversationStore.save();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _localizedPreview(String preview, bool hasAttachment) {
    if (preview.isEmpty) {
      return hasAttachment ? localeController.t('chat.attachment') : '';
    }
    if (preview == 'Attachment') {
      return localeController.t('chat.attachment');
    }
    return preview;
  }
}
