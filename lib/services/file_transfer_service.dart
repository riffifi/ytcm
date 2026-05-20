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
    void Function(int sent, int total)? onProgress,
  }) async {
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    await channel.ready.timeout(const Duration(seconds: 30));
    // split into chunks for progress reporting
    const chunkSize = 64 * 1024; // 64KB
    final total = bytes.length;
    final chunks = <List<int>>[];
    for (var offset = 0; offset < total; offset += chunkSize) {
      final end = (offset + chunkSize) > total ? total : offset + chunkSize;
      chunks.add(bytes.sublist(offset, end));
    }

    final init = jsonEncode({
      'message_type': 'upload',
      'data': {
        'session_token': sessionToken,
        'filename': filename,
        'mime_type': mimeType,
        'total_size': total,
        'chunk_index': 0,
        'total_chunks': chunks.length,
      },
    });
    channel.sink.add(init);

    String? fileId;
    final iterator = StreamIterator(channel.stream);
    try {
      // Wait for initial server response that accepts the upload
      while (await iterator.moveNext()) {
        final event = iterator.current;
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

      // send chunks sequentially
      var sent = 0;
      for (var i = 0; i < chunks.length; i++) {
        channel.sink.add(chunks[i]);
        sent += chunks[i].length;
        try {
          onProgress?.call(sent, total);
        } catch (_) {}
        // small yield to allow UI update
        await Future.delayed(const Duration(milliseconds: 1));
      }

      // Wait for completion message
      while (await iterator.moveNext()) {
        final event = iterator.current;
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
    } finally {
      try {
        await iterator.cancel();
      } catch (_) {}
      await channel.sink.close();
    }

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
        // Some servers may return metadata or may include the whole file as
        // base64-encoded payload in a JSON field like 'data'. Handle that.
        final map = jsonDecode(event) as Map<String, dynamic>;
        if (map['success'] != true) {
          await channel.sink.close();
          throw Exception(map['message'] ?? 'download denied');
        }
        // If server inlines file data as base64 string, decode and return.
        final maybeData = map['data'];
        if (maybeData is String && maybeData.isNotEmpty) {
          try {
            final decoded = base64Decode(maybeData);
            await channel.sink.close();
            return decoded;
          } catch (_) {
            // not base64 — continue to treat as metadata
          }
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
