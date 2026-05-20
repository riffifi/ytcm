import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';
import '../models/group_models.dart';

class ChatService {
  final String wsUrl;
  WebSocketChannel? _channel;
  String? _token;
  bool _joined = false;

  final _messageController = StreamController<Message>.broadcast();
  final _historyController =
      StreamController<Map<String, List<Message>>>.broadcast();
  final _connectionsController =
      StreamController<List<Connection>>.broadcast();
  final _joinController = StreamController<UserInfo>.broadcast();
  final _readReceiptController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _pongController = StreamController<void>.broadcast();

  final _groupListController = StreamController<GroupListEvent>.broadcast();
  final _groupMessageController = StreamController<GroupMessage>.broadcast();
  final _groupHistoryController =
      StreamController<Map<String, List<GroupMessage>>>.broadcast();
  final _groupDetailsController = StreamController<GroupDetails>.broadcast();
  final _groupReadReceiptController =
      StreamController<Map<String, String>>.broadcast();
  final _messageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Message> get messages => _messageController.stream;
  Stream<Map<String, List<Message>>> get historyEvents =>
      _historyController.stream;
  Stream<List<Connection>> get connections => _connectionsController.stream;
  Stream<UserInfo> get joinEvents => _joinController.stream;
  Stream<String> get readReceipts => _readReceiptController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;
  Stream<void> get pongs => _pongController.stream;

  Stream<GroupListEvent> get groupListEvents => _groupListController.stream;
  Stream<GroupMessage> get groupMessages => _groupMessageController.stream;
  Stream<Map<String, List<GroupMessage>>> get groupHistoryEvents =>
      _groupHistoryController.stream;
  Stream<GroupDetails> get groupDetailsEvents =>
      _groupDetailsController.stream;
  /// `{ 'group_id': id, 'by_user_id': uid }`
  Stream<Map<String, String>> get groupReadReceipts =>
      _groupReadReceiptController.stream;
  Stream<Map<String, dynamic>> get messageDeletedEvents =>
      _messageDeletedController.stream;

  bool get isConnected => _channel != null && _joined;

  ChatService({this.wsUrl = 'ws://127.0.0.1:3001/ws'});

  Future<void> connect(String token) async {
    _token = token;
    _joined = false;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready.timeout(const Duration(seconds: 10));
      _connectionStateController.add(true);
      _channel!.stream.listen(
        _handleMessage,
        onError: (_) {
          _joined = false;
          _connectionStateController.add(false);
        },
        onDone: () {
          _joined = false;
          _connectionStateController.add(false);
        },
      );
      _send({'action': 'join', 'session_token': token});
    } catch (e) {
      _connectionStateController.add(false);
      _errorController.add('WebSocket connection failed: $e');
    }
  }

  Future<String> pingReachability() async {
    WebSocketChannel? probe;
    try {
      probe = WebSocketChannel.connect(Uri.parse(wsUrl));
      await probe.ready.timeout(const Duration(seconds: 8));
      await probe.sink.close();
      return 'Reachable (WebSocket open)';
    } catch (e) {
      return 'Failed: $e';
    } finally {
      try {
        await probe?.sink.close();
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
          _joinController.add(UserInfo(
            uuid: json['user_id'] as String,
            username: json['username'] as String,
          ));
          break;
        case 'message':
          _messageController.add(
              Message.fromJson(json['message'] as Map<String, dynamic>));
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
        case 'message_deleted':
          _messageDeletedController.add({
            'message_uuid': json['message_uuid'],
            'by_user_id': json['by_user_id'],
            'for_everyone': json['for_everyone'] ?? false,
          });
          break;
        case 'mark_read_result':
        case 'pong':
          if (type == 'pong') _pongController.add(null);
          break;
        case 'error':
          _errorController.add(json['message'] as String? ?? 'Unknown error');
          break;

        case 'groups':
          final list = (json['groups'] as List)
              .map((g) => GroupInfo.fromJson(g as Map<String, dynamic>))
              .toList();
          _groupListController.add(GroupListEvent.replace(list));
          break;
        case 'group_created':
        case 'group_updated':
          final g = GroupInfo.fromJson(
              json['group'] as Map<String, dynamic>);
          _groupListController.add(GroupListEvent.upsert(g));
          break;
        case 'group_deleted':
          _groupListController
              .add(GroupListEvent.remove(json['group_id'] as String));
          break;
        case 'group_info':
          _groupDetailsController.add(GroupDetails.fromJson(json));
          break;
        case 'group_message':
          _groupMessageController.add(
              GroupMessage.fromJson(json['message'] as Map<String, dynamic>));
          break;
        case 'group_history':
          final gid = json['group_id'] as String;
          final msgs = (json['messages'] as List)
              .map((m) => GroupMessage.fromJson(m as Map<String, dynamic>))
              .toList();
          _groupHistoryController.add({gid: msgs});
          break;
        case 'group_read_receipt':
          _groupReadReceiptController.add({
            'group_id': json['group_id'] as String,
            'by_user_id': json['by_user_id'] as String,
          });
          break;
        case 'group_member_added':
        case 'group_member_updated':
        case 'group_member_removed':
        case 'group_mark_read_result':
        case 'group_message_deleted':
          break;
      }
    } catch (e) {
      _errorController.add('Failed to parse server message: $e');
    }
  }

  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
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
    String? avatarId,
    bool? isPrivate,
    bool? isChannel,
    List<String>? memberIds,
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

  void groupInfo(String groupId) {
    _send({
      'action': 'group_info',
      'session_token': _token,
      'group_id': groupId,
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

  void requestGroupHistory(String groupId, {int limit = 100}) {
    _send({
      'action': 'group_history',
      'session_token': _token,
      'group_id': groupId,
      'limit': limit,
    });
  }

  void markGroupRead(String groupId) {
    _send({
      'action': 'mark_group_read',
      'session_token': _token,
      'group_id': groupId,
    });
  }

  void addGroupMember(String groupId, String userId, {String? role}) {
    _send({
      'action': 'add_group_member',
      'session_token': _token,
      'group_id': groupId,
      'user_id': userId,
      'role': role ?? 'member',
    });
  }

  void removeGroupMember(String groupId, String userId) {
    _send({
      'action': 'remove_group_member',
      'session_token': _token,
      'group_id': groupId,
      'user_id': userId,
    });
  }

  void leaveGroup(String groupId) {
    _send({
      'action': 'leave_group',
      'session_token': _token,
      'group_id': groupId,
    });
  }

  void disconnect() {
    _joined = false;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _historyController.close();
    _connectionsController.close();
    _joinController.close();
    _readReceiptController.close();
    _errorController.close();
    _connectionStateController.close();
    _pongController.close();
    _groupListController.close();
    _groupMessageController.close();
    _groupHistoryController.close();
    _groupDetailsController.close();
    _groupReadReceiptController.close();
    _messageDeletedController.close();
  }
}
