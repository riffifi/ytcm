import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/group_models.dart';
import '../models/models.dart';
import 'messenger_log.dart';

class MessageDeletedEvent {
  final String messageUuid;
  final String byUserId;
  final bool forEveryone;

  const MessageDeletedEvent({
    required this.messageUuid,
    required this.byUserId,
    required this.forEveryone,
  });
}

class GroupMessageDeletedEvent {
  final String groupId;
  final String messageUuid;
  final String byUserId;
  final bool forEveryone;

  const GroupMessageDeletedEvent({
    required this.groupId,
    required this.messageUuid,
    required this.byUserId,
    required this.forEveryone,
  });
}

class ChatService {
  final String wsUrl;
  final MessengerLog? log;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  String? _token;
  bool _joined = false;
  final List<Map<String, dynamic>> _pendingActions = [];

  final _messageController = StreamController<Message>.broadcast();
  final _historyController =
      StreamController<Map<String, List<Message>>>.broadcast();
  final _connectionsController = StreamController<List<Connection>>.broadcast();
  final _joinController = StreamController<UserInfo>.broadcast();
  final _readReceiptController = StreamController<String>.broadcast();
  final _markReadResultController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _pongController = StreamController<void>.broadcast();
  final _groupsController = StreamController<List<ChatGroup>>.broadcast();
  final _groupMessageController = StreamController<GroupMessage>.broadcast();
  final _groupHistoryController =
      StreamController<Map<String, List<GroupMessage>>>.broadcast();
  final _groupCreatedController = StreamController<ChatGroup>.broadcast();
  final _groupUpdatedController = StreamController<ChatGroup>.broadcast();
  final _groupInfoController = StreamController<GroupDetails>.broadcast();
  final _groupDeletedController = StreamController<String>.broadcast();
  final _messageDeletedController =
      StreamController<MessageDeletedEvent>.broadcast();
  final _groupMessageDeletedController =
      StreamController<GroupMessageDeletedEvent>.broadcast();
  final _groupMembershipChangedController = StreamController<void>.broadcast();
  final _groupReadChangedController = StreamController<String>.broadcast();

  Stream<Message> get messages => _messageController.stream;
  Stream<Map<String, List<Message>>> get historyEvents =>
      _historyController.stream;
  Stream<List<Connection>> get connections => _connectionsController.stream;
  Stream<UserInfo> get joinEvents => _joinController.stream;
  Stream<String> get readReceipts => _readReceiptController.stream;
  Stream<String> get markReadResults => _markReadResultController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;
  Stream<void> get pongs => _pongController.stream;
  Stream<List<ChatGroup>> get groups => _groupsController.stream;
  Stream<GroupMessage> get groupMessages => _groupMessageController.stream;
  Stream<Map<String, List<GroupMessage>>> get groupHistoryEvents =>
      _groupHistoryController.stream;
  Stream<ChatGroup> get groupCreated => _groupCreatedController.stream;
  Stream<ChatGroup> get groupUpdated => _groupUpdatedController.stream;
  Stream<GroupDetails> get groupInfo => _groupInfoController.stream;
  Stream<String> get groupDeleted => _groupDeletedController.stream;
  Stream<MessageDeletedEvent> get messageDeleted =>
      _messageDeletedController.stream;
  Stream<GroupMessageDeletedEvent> get groupMessageDeleted =>
      _groupMessageDeletedController.stream;
  Stream<void> get groupMembershipChanged =>
      _groupMembershipChangedController.stream;
  Stream<String> get groupReadChanged => _groupReadChangedController.stream;

  bool get isConnected => _channel != null && _joined;

  ChatService({required this.wsUrl, this.log});

  Future<void> connect(String token) async {
    await _closeSocket();
    _token = token;
    _joined = false;
    log?.info('Connecting to chat…', category: 'chat');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready.timeout(const Duration(seconds: 10));
      _connectionStateController.add(true);
      log?.debug('Chat WebSocket open', category: 'chat', banner: false);
      _socketSubscription = _channel!.stream.listen(
        _handleMessage,
        onError: (_) {
          _joined = false;
          _channel = null;
          _connectionStateController.add(false);
        },
        onDone: () {
          _joined = false;
          _channel = null;
          _connectionStateController.add(false);
        },
      );
      _send({'action': 'join', 'session_token': token});
      log?.debug('Sent join', category: 'chat', banner: false);
    } catch (e) {
      await _closeSocket();
      _connectionStateController.add(false);
      final raw = e.toString();
      final msg = raw.contains('status code: 502') ||
              raw.contains('status code: 503')
          ? 'Chat service is temporarily unavailable (server gateway error).'
          : 'WebSocket connection failed: $e';
      log?.error(msg, category: 'chat');
      _errorController.add(msg);
    }
  }

  /// Opens the socket briefly to verify reachability (no join).
  Future<String> pingReachability() async {
    WebSocketChannel? probe;
    try {
      probe = WebSocketChannel.connect(Uri.parse(wsUrl));
      await probe.ready.timeout(const Duration(seconds: 8));
      await probe.sink.close().timeout(const Duration(seconds: 1));
      return 'Reachable (WebSocket open)';
    } catch (e) {
      final text = e.toString();
      if (text.contains('status code: 502') ||
          text.contains('status code: 503')) {
        return 'Server gateway error. The reverse proxy is online, but '
            'chat-service is unavailable.';
      }
      return 'Failed: $e';
    } finally {
      try {
        await probe?.sink.close().timeout(const Duration(seconds: 1));
      } catch (_) {}
    }
  }

  Future<String> pingSession() async {
    if (_token == null || !_joined) {
      return 'Not connected — sign in first for a full ping';
    }
    final completer = Completer<String>();
    late StreamSubscription<void> sub;
    sub = pongs.listen((_) {
      if (!completer.isCompleted) completer.complete('Pong received');
      sub.cancel();
    });
    ping();
    Future.delayed(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete('No pong within 5s');
        sub.cancel();
      }
    });
    return completer.future;
  }

  void _handleMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = json['type'] as String?;
      switch (type) {
        case 'joined':
          _joined = true;
          log?.info(
            'Joined as ${json['username']} (${json['connection_number']} connections)',
            category: 'chat',
          );
          _joinController.add(UserInfo(
            uuid: json['user_id'] as String,
            username: json['username'] as String,
          ));
          _flushPendingActions();
          break;
        case 'message':
          _messageController
              .add(Message.fromJson(json['message'] as Map<String, dynamic>));
          break;
        case 'history':
          final msgs = (json['messages'] as List)
              .map((m) => Message.fromJson(m as Map<String, dynamic>))
              .toList();
          _historyController.add({
            json['with_user_id'] as String: msgs,
          });
          break;
        case 'connections':
          final conns = (json['connections'] as List)
              .map((c) => Connection.fromJson(c as Map<String, dynamic>))
              .toList();
          _connectionsController.add(conns);
          break;
        case 'read_receipt':
          _readReceiptController.add(json['by_user_id'] as String);
          break;
        case 'mark_read_result':
          final withUser = json['with_user_id'] as String?;
          if (withUser != null) {
            _markReadResultController.add(withUser);
          }
          break;
        case 'message_deleted':
          _messageDeletedController.add(MessageDeletedEvent(
            messageUuid: json['message_uuid'] as String,
            byUserId: json['by_user_id'] as String,
            forEveryone: json['for_everyone'] as bool? ?? false,
          ));
          break;
        case 'groups':
          log?.debug(
            'Groups list (${(json['groups'] as List).length})',
            category: 'group',
            banner: false,
          );
          final groups = (json['groups'] as List)
              .map((g) => ChatGroup.fromJson(g as Map<String, dynamic>))
              .toList();
          _groupsController.add(groups);
          break;
        case 'group_created':
          final g = ChatGroup.fromJson(json['group'] as Map<String, dynamic>);
          log?.info('Group created: ${g.name}', category: 'group');
          _groupCreatedController.add(g);
          break;
        case 'group_updated':
          _groupUpdatedController.add(
            ChatGroup.fromJson(json['group'] as Map<String, dynamic>),
          );
          break;
        case 'group_info':
          _groupInfoController.add(
            GroupDetails.fromJson(json['details'] as Map<String, dynamic>),
          );
          break;
        case 'group_deleted':
          _groupDeletedController.add(json['group_id'] as String);
          break;
        case 'group_member_added':
        case 'group_member_updated':
        case 'group_member_removed':
          _groupMembershipChangedController.add(null);
          break;
        case 'group_message':
          _groupMessageController.add(GroupMessage.fromJson(
            json['message'] as Map<String, dynamic>,
          ));
          break;
        case 'group_history':
          final msgs = (json['messages'] as List)
              .map((m) => GroupMessage.fromJson(m as Map<String, dynamic>))
              .toList();
          _groupHistoryController.add({
            json['group_id'] as String: msgs,
          });
          break;
        case 'group_message_deleted':
          _groupMessageDeletedController.add(GroupMessageDeletedEvent(
            groupId: json['group_id'] as String,
            messageUuid: json['message_uuid'] as String,
            byUserId: json['by_user_id'] as String,
            forEveryone: json['for_everyone'] as bool? ?? false,
          ));
          break;
        case 'group_mark_read_result':
        case 'group_read_receipt':
          final groupId = json['group_id'] as String?;
          if (groupId != null) _groupReadChangedController.add(groupId);
          break;
        case 'pong':
          log?.debug('Pong', category: 'chat', banner: false);
          _pongController.add(null);
          break;
        case 'error':
          final err = json['message'] as String? ?? 'Unknown error';
          log?.error(err, category: 'chat');
          _errorController.add(err);
          break;
        default:
          log?.debug('Event: $type', category: 'chat', banner: false);
          break;
      }
    } catch (e) {
      final msg = 'Failed to parse server message: $e';
      log?.warn(msg, category: 'chat');
      _errorController.add(msg);
    }
  }

  void _send(Map<String, dynamic> data) {
    if (!_joined && data['action'] != 'join') {
      if (_pendingActions.length >= 100) _pendingActions.removeAt(0);
      _pendingActions.add(Map<String, dynamic>.from(data));
      return;
    }
    _channel?.sink.add(jsonEncode(data));
  }

  void _flushPendingActions() {
    if (!_joined || _channel == null || _pendingActions.isEmpty) return;
    final pending = List<Map<String, dynamic>>.from(_pendingActions);
    _pendingActions.clear();
    for (final action in pending) {
      action['session_token'] = _token;
      _channel!.sink.add(jsonEncode(action));
    }
  }

  void sendMessage({required String receiverId, String? text, String? fileId}) {
    _send({
      'action': 'send_message',
      'session_token': _token,
      'receiver_id': receiverId,
      'text': text,
      'file_id': fileId,
    });
  }

  void requestHistory(String withUserId, {int limit = 100}) {
    _send({
      'action': 'history',
      'session_token': _token,
      'with_user_id': withUserId,
      'limit': limit,
    });
  }

  void markRead(String withUserId) {
    _send({
      'action': 'mark_read',
      'session_token': _token,
      'with_user_id': withUserId,
    });
  }

  void deleteMessage(String messageUuid, {bool forEveryone = false}) {
    _send({
      'action': 'delete_message',
      'session_token': _token,
      'message_uuid': messageUuid,
      'for_everyone': forEveryone,
    });
  }

  void listConnections() {
    _send({'action': 'list_connections', 'session_token': _token});
  }

  void ping() {
    _send({'action': 'ping', 'session_token': _token});
  }

  void listGroups() {
    _send({'action': 'list_groups', 'session_token': _token});
  }

  void createGroup({
    required String name,
    String? description,
    List<String> memberIds = const [],
    bool isPrivate = false,
    bool isChannel = false,
    String? avatarId,
  }) {
    _send({
      'action': 'create_group',
      'session_token': _token,
      'name': name,
      'description': description,
      'avatar_id': avatarId,
      'is_private': isPrivate,
      'is_channel': isChannel,
      'member_ids': memberIds,
    });
  }

  void requestGroupInfo(String groupId) {
    _send({
      'action': 'group_info',
      'session_token': _token,
      'group_id': groupId,
    });
  }

  void updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? avatarId,
    bool? isPrivate,
    bool? isChannel,
  }) {
    _send({
      'action': 'update_group',
      'session_token': _token,
      'group_id': groupId,
      'name': name,
      'description': description,
      'avatar_id': avatarId,
      'is_private': isPrivate,
      'is_channel': isChannel,
    });
  }

  void setGroupMemberRole({
    required String groupId,
    required String userId,
    required String role,
  }) {
    _send({
      'action': 'set_group_member_role',
      'session_token': _token,
      'group_id': groupId,
      'user_id': userId,
      'role': role,
    });
  }

  void removeGroupMember({
    required String groupId,
    required String userId,
  }) {
    _send({
      'action': 'remove_group_member',
      'session_token': _token,
      'group_id': groupId,
      'user_id': userId,
    });
  }

  void requestGroupHistory(String groupId, {int limit = 100}) {
    _send({
      'action': 'group_history',
      'session_token': _token,
      'group_id': groupId,
      'limit': limit,
    });
  }

  void sendGroupMessage({
    required String groupId,
    String? text,
    String? fileId,
  }) {
    _send({
      'action': 'send_group_message',
      'session_token': _token,
      'group_id': groupId,
      'text': text,
      'file_id': fileId,
    });
  }

  void markGroupRead(String groupId) {
    _send({
      'action': 'mark_group_read',
      'session_token': _token,
      'group_id': groupId,
    });
  }

  void addGroupMember({
    required String groupId,
    required String userId,
    String role = 'member',
  }) {
    _send({
      'action': 'add_group_member',
      'session_token': _token,
      'group_id': groupId,
      'user_id': userId,
      'role': role,
    });
  }

  void deleteGroupMessage(String messageUuid, {bool forEveryone = false}) {
    _send({
      'action': 'delete_group_message',
      'session_token': _token,
      'message_uuid': messageUuid,
      'for_everyone': forEveryone,
    });
  }

  void leaveGroup(String groupId) {
    _send({
      'action': 'leave_group',
      'session_token': _token,
      'group_id': groupId,
    });
  }

  void deleteGroup(String groupId) {
    _send({
      'action': 'delete_group',
      'session_token': _token,
      'group_id': groupId,
    });
  }

  Future<void> disconnect({bool clearPending = false}) {
    _joined = false;
    if (clearPending) _pendingActions.clear();
    log?.info('Chat disconnected', category: 'chat');
    return _closeSocket();
  }

  Future<void> _closeSocket() async {
    final subscription = _socketSubscription;
    final channel = _channel;
    _socketSubscription = null;
    _channel = null;
    await subscription?.cancel();
    try {
      await channel?.sink.close().timeout(const Duration(seconds: 1));
    } catch (_) {}
  }

  void dispose() {
    disconnect(clearPending: true);
    _messageController.close();
    _historyController.close();
    _connectionsController.close();
    _joinController.close();
    _readReceiptController.close();
    _markReadResultController.close();
    _errorController.close();
    _connectionStateController.close();
    _pongController.close();
    _groupsController.close();
    _groupMessageController.close();
    _groupHistoryController.close();
    _groupCreatedController.close();
    _groupUpdatedController.close();
    _groupInfoController.close();
    _groupDeletedController.close();
    _messageDeletedController.close();
    _groupMessageDeletedController.close();
    _groupMembershipChangedController.close();
    _groupReadChangedController.close();
  }
}
