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
  final _historyController = StreamController<Map<String, List<Message>>>.broadcast();
  final _connectionsController = StreamController<List<Connection>>.broadcast();
  final _joinController = StreamController<UserInfo>.broadcast();
  final _readReceiptController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<Message> get messages => _messageController.stream;
  Stream<Map<String, List<Message>>> get historyEvents => _historyController.stream;
  Stream<List<Connection>> get connections => _connectionsController.stream;
  Stream<UserInfo> get joinEvents => _joinController.stream;
  Stream<String> get readReceipts => _readReceiptController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;

  bool get isConnected => _channel != null && _joined;

  ChatService({this.wsUrl = 'ws://127.0.0.1:3001/ws'});

  Future<void> connect(String token) async {
    _token = token;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
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
      // Send join
      _send({'action': 'join', 'session_token': token});
    } catch (e) {
      _connectionStateController.add(false);
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = json['type'] as String?;
      switch (type) {
        case 'joined':
          _joined = true;
          _joinController.add(UserInfo(
            uuid: json['user_id'],
            username: json['username'],
          ));
          break;
        case 'message':
          _messageController.add(Message.fromJson(json['message']));
          break;
        case 'history':
          final msgs = (json['messages'] as List)
              .map((m) => Message.fromJson(m))
              .toList();
          _historyController.add({json['with_user_id']: msgs});
          break;
        case 'connections':
          final conns = (json['connections'] as List)
              .map((c) => Connection.fromJson(c))
              .toList();
          _connectionsController.add(conns);
          break;
        case 'read_receipt':
          _readReceiptController.add(json['by_user_id']);
          break;
        case 'error':
          _errorController.add(json['message'] ?? 'Unknown error');
          break;
      }
    } catch (_) {}
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
  }
}
