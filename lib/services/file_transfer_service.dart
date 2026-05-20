import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Minimal file-service WebSocket client (upload + grant_access + download).
class FileTransferService {
  FileTransferService({required this.wsUrl});

  final String wsUrl;

  Future<String> uploadBytes({
    required String sessionToken,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    await channel.ready.timeout(const Duration(seconds: 30));

    final init = jsonEncode({
      'message_type': 'upload',
      'data': {
        'session_token': sessionToken,
        'filename': filename,
        'mime_type': mimeType,
        'total_size': bytes.length,
        'chunk_index': 0,
        'total_chunks': 1,
      },
    });
    channel.sink.add(init);

    String? fileId;
    await for (final event in channel.stream) {
      if (event is String) {
        final map = jsonDecode(event) as Map<String, dynamic>;
        if (map['success'] == true && map['file_id'] != null) {
          fileId = map['file_id'] as String;
          final msg = map['message'] as String? ?? '';
          if (msg.contains('binary') ||
              msg.contains('Upload accepted') ||
              msg.contains('Upload started')) {
            break;
          }
        } else {
          await channel.sink.close();
          throw Exception(map['message'] ?? 'Upload rejected');
        }
      }
    }

    channel.sink.add(bytes);

    await for (final event in channel.stream) {
      if (event is String) {
        final map = jsonDecode(event) as Map<String, dynamic>;
        if (map['success'] == true) {
          final msg = map['message'] as String? ?? '';
          if (msg.contains('complete')) {
            await channel.sink.close();
            return (map['file_id'] as String?) ?? fileId!;
          }
        } else {
          await channel.sink.close();
          throw Exception(map['message'] ?? 'Upload failed');
        }
      }
    }

    await channel.sink.close();
    throw Exception('Upload did not complete');
  }

  Future<void> grantAccess({
    required String sessionToken,
    required String fileId,
    required String userId,
  }) async {
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    await channel.ready.timeout(const Duration(seconds: 15));
    final payload = jsonEncode({
      'message_type': 'grant_access',
      'data': {
        'session_token': sessionToken,
        'file_id': fileId,
        'user_id': userId,
      },
    });
    channel.sink.add(payload);
    await for (final event in channel.stream) {
      if (event is String) {
        final map = jsonDecode(event) as Map<String, dynamic>;
        await channel.sink.close();
        if (map['success'] != true) {
          throw Exception(map['message'] ?? 'grant_access failed');
        }
        return;
      }
    }
    await channel.sink.close();
    throw Exception('No response from grant_access');
  }

  /// Returns raw file bytes (concatenated binary frames after JSON header).
  Future<Uint8List> downloadFile({
    required String sessionToken,
    required String fileId,
  }) async {
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    await channel.ready.timeout(const Duration(seconds: 30));

    channel.sink.add(jsonEncode({
      'message_type': 'download',
      'data': {
        'session_token': sessionToken,
        'file_id': fileId,
      },
    }));

    int? totalChunks;
    final chunks = <Uint8List>[];

    await for (final event in channel.stream) {
      if (event is String) {
        final map = jsonDecode(event) as Map<String, dynamic>;
        if (map['success'] != true) {
          await channel.sink.close();
          throw Exception(map['message'] ?? 'download denied');
        }
        totalChunks = (map['total_chunks'] as num?)?.toInt() ?? 1;
      } else if (event is List<int>) {
        chunks.add(Uint8List.fromList(event));
        if (totalChunks != null && chunks.length >= totalChunks) {
          break;
        }
      } else if (event is Uint8List) {
        chunks.add(event);
        if (totalChunks != null && chunks.length >= totalChunks) {
          break;
        }
      }
    }

    await channel.sink.close();
    if (chunks.isEmpty) return Uint8List(0);
    final total = chunks.fold<int>(0, (a, b) => a + b.length);
    final out = Uint8List(total);
    var o = 0;
    for (final c in chunks) {
      out.setRange(o, o + c.length, c);
      o += c.length;
    }
    return out;
  }
}
