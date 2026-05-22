import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/group_models.dart';
import '../models/models.dart';
import 'messenger_log.dart';

class ChatService {
  final String wsUrl;
  final MessengerLog? log;
  WebSocketChannel? _channel;
  String? _token;
  bool _joined = false;

  final _messageController = StreamController<Message>.broadcast();
  final _historyController =
      StreamController<Map<String, List<Message>>>.broadcast();
  final _connectionsController =
      StreamController<List<Connection>>.broadcast();
  final _dialogPeersController = StreamController<List<String>>.broadcast();
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

  Stream<Message> get messages => _messageController.stream;
  Stream<Map<String, List<Message>>> get historyEvents =>
      _historyController.stream;
  Stream<List<Connection>> get connections => _connectionsController.stream;
  Stream<List<String>> get dialogPeers => _dialogPeersController.stream;
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

  bool get isConnected => _channel != null && _joined;

  ChatService({required this.wsUrl, this.log});

  Future<void> connect(String token) async {
    _token = token;
    _joined = false;
    log?.info('Connecting to chat…', category: 'chat');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready.timeout(const Duration(seconds: 10));
      _connectionStateController.add(true);
      log?.debug('Chat WebSocket open', category: 'chat', banner: false);
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
      log?.debug('Sent join', category: 'chat', banner: false);
    } catch (e) {
      _connectionStateController.add(false);
      final msg = 'WebSocket connection failed: $e';
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
          log?.info(
            'Joined as ${json['username']} (${json['connection_number']} connections)',
            category: 'chat',
          );
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
        case 'dialog_peers':
          final peers = (json['peer_ids'] as List)
              .map((id) => id.toString())
              .where((id) => id.isNotEmpty)
              .toList();
          log?.info(
            'Dialog peers from server (${peers.length})',
            category: 'chat',
            banner: false,
          );
          _dialogPeersController.add(peers);
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
        case 'group_message':
          _groupMessageController.add(GroupMessage.fromJson(
            json['message'] as Map<String, dynamic>,
          ));
          break;
        case 'group_history':
          final msgs = (json['messages'] as List)
              .map((m) =>
                  GroupMessage.fromJson(m as Map<String, dynamic>))
              .toList();
          _groupHistoryController.add({
            json['group_id'] as String: msgs,
          });
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

  void listDialogPeers({int limit = 200}) {
    _send({
      'action': 'list_dialog_peers',
      'session_token': _token,
      'limit': limit,
    });
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
  }) {
    _send({
      'action': 'create_group',
      'session_token': _token,
      'name': name,
      'description': description,
      'avatar_id': null,
      'is_private': isPrivate,
      'is_channel': isChannel,
      'member_ids': memberIds,
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

  void disconnect() {
    _joined = false;
    log?.info('Chat disconnected', category: 'chat');
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _historyController.close();
    _connectionsController.close();
    _dialogPeersController.close();
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
  }
}
