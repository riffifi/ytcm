import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

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

  Stream<Message> get messages => _messageController.stream;
  Stream<Map<String, List<Message>>> get historyEvents =>
      _historyController.stream;
  Stream<List<Connection>> get connections => _connectionsController.stream;
  Stream<UserInfo> get joinEvents => _joinController.stream;
  Stream<String> get readReceipts => _readReceiptController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;
  Stream<void> get pongs => _pongController.stream;

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
        case 'pong':
          _pongController.add(null);
          break;
        case 'error':
          _errorController.add(json['message'] as String? ?? 'Unknown error');
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
  }
}
