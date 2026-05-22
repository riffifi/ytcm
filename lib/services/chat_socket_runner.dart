import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/models.dart';
import 'conversation_store.dart';

/// Shared WebSocket frame handling for chat (main isolate + background service).
class ChatSocketRunner {
  static Future<void> listen({
    required String chatUrl,
    required String sessionToken,
    required Future<void> Function(Message message) onLiveMessage,
    Future<void> Function(Message message)? onHistoryMessage,
    required bool Function() shouldStop,
    List<String> historyPeerIds = const [],
    Duration maxDuration = const Duration(hours: 8),
  }) async {
    WebSocketChannel? channel;

    try {
      channel = WebSocketChannel.connect(Uri.parse(chatUrl));
      await channel.ready.timeout(const Duration(seconds: 15));

      final sub = channel.stream.listen(
        (raw) async {
          try {
            await _handleRaw(
              raw: raw,
              sessionToken: sessionToken,
              channel: channel!,
              historyPeerIds: historyPeerIds,
              onLiveMessage: onLiveMessage,
              onHistoryMessage: onHistoryMessage,
            );
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );

      channel.sink.add(jsonEncode({
        'action': 'join',
        'session_token': sessionToken,
      }));

      final end = DateTime.now().add(maxDuration);
      while (DateTime.now().isBefore(end)) {
        if (shouldStop()) break;
        await Future.delayed(const Duration(seconds: 2));
      }

      await sub.cancel();
    } finally {
      try {
        await channel?.sink.close();
      } catch (_) {}
    }
  }

  static Future<void> _handleRaw({
    required dynamic raw,
    required String sessionToken,
    required WebSocketChannel channel,
    required List<String> historyPeerIds,
    required Future<void> Function(Message message) onLiveMessage,
    Future<void> Function(Message message)? onHistoryMessage,
  }) async {
    final data = jsonDecode(raw as String) as Map<String, dynamic>;
    final eventType = data['type'] as String?;
    if (eventType == null) return;

    switch (eventType) {
      case 'joined':
        if (historyPeerIds.isNotEmpty) {
          for (final peerId in historyPeerIds) {
            channel.sink.add(jsonEncode({
              'action': 'history',
              'session_token': sessionToken,
              'with_user_id': peerId,
              'limit': 15,
            }));
          }
        }
        break;
      case 'message':
        final msg =
            Message.fromJson(data['message'] as Map<String, dynamic>);
        await onLiveMessage(msg);
        break;
      case 'history':
        if (onHistoryMessage == null) return;
        final msgs = (data['messages'] as List)
            .map((m) => Message.fromJson(m as Map<String, dynamic>))
            .toList();
        for (final msg in msgs) {
          await onHistoryMessage(msg);
        }
        break;
      default:
        break;
    }
  }

  static List<String> peerIdsFromStore(ConversationStore store, {int max = 20}) {
    return store.peerNames.keys.where(_looksLikeUuid).take(max).toList();
  }

  static bool _looksLikeUuid(String value) {
    final re = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return re.hasMatch(value.trim());
  }
}
