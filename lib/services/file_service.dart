import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/messenger_file.dart';
import 'file_metadata_cache.dart';

class FileServiceException implements Exception {
  final String message;
  const FileServiceException(this.message);

  @override
  String toString() => message;
}

class FileService {
  static const chunkSize = 64 * 1024;

  final String wsUrl;

  FileService({required String wsUrl}) : wsUrl = wsUrl.trim();

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

  Future<List<MessengerFileInfo>> listFiles(String sessionToken) async {
    final response = await _requestJson(
      {
        'message_type': 'list_files',
        'data': sessionToken,
      },
      timeout: const Duration(seconds: 20),
    );
    if (response['success'] != true) {
      throw FileServiceException(
        response['message'] as String? ?? 'Failed to list files',
      );
    }
    final files = (response['files'] as List? ?? [])
        .map((f) => MessengerFileInfo.fromJson(f as Map<String, dynamic>))
        .toList();
    return files;
  }

  Future<String> uploadFile({
    required String sessionToken,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw const FileServiceException('Cannot upload an empty file');
    }

    final totalSize = bytes.length;
    final totalChunks = totalSize == 0
        ? 1
        : (totalSize + chunkSize - 1) ~/ chunkSize;

    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    try {
      await channel.ready.timeout(const Duration(seconds: 15));

      final initResponse = await _sendAndWaitJson(
        channel,
        {
          'message_type': 'upload',
          'data': {
            'session_token': sessionToken,
            'filename': filename,
            'mime_type': mimeType,
            'total_size': totalSize,
            'chunk_index': 0,
            'total_chunks': totalChunks,
          },
        },
        timeout: const Duration(seconds: 30),
      );

      if (initResponse['success'] != true) {
        throw FileServiceException(
          initResponse['message'] as String? ?? 'Upload rejected',
        );
      }

      final fileId = initResponse['file_id'] as String?;
      if (fileId == null || fileId.isEmpty) {
        throw const FileServiceException('Upload started without file_id');
      }

      for (var i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize > totalSize) ? totalSize : start + chunkSize;
        final chunk = bytes.sublist(start, end);
        channel.sink.add(chunk);

        final chunkResponse = await _waitForJson(
          channel,
          timeout: const Duration(minutes: 2),
        );

        if (chunkResponse['success'] != true) {
          throw FileServiceException(
            chunkResponse['message'] as String? ?? 'Chunk upload failed',
          );
        }

        onProgress?.call((i + 1) / totalChunks);

        final message = chunkResponse['message'] as String? ?? '';
        if (message == 'Upload complete') {
          return fileId;
        }
      }

      throw const FileServiceException('Upload finished without confirmation');
    } finally {
      await channel.sink.close();
    }
  }

  Future<DownloadedFile> downloadFile({
    required String sessionToken,
    required String fileId,
    void Function(double progress)? onProgress,
  }) async {
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    try {
      await channel.ready.timeout(const Duration(seconds: 15));

      final completer = Completer<DownloadedFile>();
      final buffer = BytesBuilder(copy: false);
      String? filename;
      int? expectedSize;
      int expectedChunks = 1;
      var receivedChunks = 0;
      var gotMetadata = false;

      late StreamSubscription<dynamic> sub;
      Future<void> finish() async {
        if (completer.isCompleted) return;
        final name = filename ?? fileId;
        final bytes = buffer.toBytes();
        if (expectedSize != null && bytes.length != expectedSize) {
          completer.completeError(FileServiceException(
            'Download size mismatch (${bytes.length} vs $expectedSize)',
          ));
          return;
        }
        final localPath = await _saveToDisk(fileId, name, bytes);
        completer.complete(DownloadedFile(
          fileId: fileId,
          filename: name,
          bytes: bytes,
          localPath: localPath,
        ));
      }

      sub = channel.stream.listen(
        (raw) async {
          try {
            if (raw is String) {
              final json = jsonDecode(raw) as Map<String, dynamic>;
              if (!gotMetadata) {
                gotMetadata = true;
                if (json['success'] != true) {
                  if (!completer.isCompleted) {
                    completer.completeError(FileServiceException(
                      json['message'] as String? ?? 'Download denied',
                    ));
                  }
                  return;
                }
                filename = json['filename'] as String? ?? fileId;
                expectedSize = (json['total_size'] as num?)?.toInt();
                expectedChunks =
                    (json['total_chunks'] as num?)?.toInt() ?? 1;
                if (expectedChunks <= 0) expectedChunks = 1;
                return;
              }
              if (json['success'] == false && !completer.isCompleted) {
                completer.completeError(FileServiceException(
                  json['message'] as String? ?? 'Download failed',
                ));
              }
              return;
            }

            if (raw is List<int>) {
              buffer.add(raw);
              receivedChunks++;
              onProgress?.call(receivedChunks / expectedChunks);
              if (receivedChunks >= expectedChunks) {
                await finish();
              }
            }
          } catch (e) {
            if (!completer.isCompleted) completer.completeError(e);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      channel.sink.add(jsonEncode({
        'message_type': 'download',
        'data': {
          'session_token': sessionToken,
          'file_id': fileId,
        },
      }));

      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw const FileServiceException('Download timed out');
        },
      ).whenComplete(() async {
        await sub.cancel();
        await channel.sink.close();
      });
    } finally {
      try {
        await channel.sink.close();
      } catch (_) {}
    }
  }

  Future<void> grantAccess({
    required String sessionToken,
    required String fileId,
    required String userId,
  }) async {
    final response = await _requestJson({
      'message_type': 'grant_access',
      'data': {
        'session_token': sessionToken,
        'file_id': fileId,
        'user_id': userId,
      },
    });
    if (response['success'] != true) {
      throw FileServiceException(
        response['message'] as String? ?? 'Failed to grant access',
      );
    }
  }

  Future<Map<String, dynamic>> _requestJson(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    try {
      await channel.ready.timeout(const Duration(seconds: 15));
      return await _sendAndWaitJson(channel, payload, timeout: timeout);
    } finally {
      await channel.sink.close();
    }
  }

  Future<Map<String, dynamic>> _sendAndWaitJson(
    WebSocketChannel channel,
    Map<String, dynamic> payload, {
    required Duration timeout,
  }) async {
    channel.sink.add(jsonEncode(payload));
    return _waitForJson(channel, timeout: timeout);
  }

  Future<Map<String, dynamic>> _waitForJson(
    WebSocketChannel channel, {
    required Duration timeout,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    late StreamSubscription<dynamic> sub;

    sub = channel.stream.listen(
      (raw) {
        if (raw is String) {
          try {
            final json = jsonDecode(raw) as Map<String, dynamic>;
            if (!completer.isCompleted) completer.complete(json);
          } catch (e) {
            if (!completer.isCompleted) completer.completeError(e);
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            const FileServiceException('Connection closed before response'),
          );
        }
      },
      cancelOnError: true,
    );

    try {
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  static Future<String> _saveToDisk(
    String fileId,
    String filename,
    List<int> bytes,
  ) async {
    final base = await FileMetadataCache.downloadsDirectory();
    final rel = FileMetadataCache.localPathFor(fileId, filename);
    final fullPath = p.join(base, rel);
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return fullPath;
  }

  static Future<String?> cachedPath(String fileId, String filename) async {
    final base = await FileMetadataCache.downloadsDirectory();
    final fullPath =
        p.join(base, FileMetadataCache.localPathFor(fileId, filename));
    final file = File(fullPath);
    if (await file.exists()) return fullPath;
    return null;
  }
}
