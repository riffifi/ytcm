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
    return (response['files'] as List? ?? [])
        .map((f) => MessengerFileInfo.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  /// One WebSocket, one stream listener for the whole upload (init JSON + binary chunks).
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
    final totalChunks =
        totalSize == 0 ? 1 : (totalSize + chunkSize - 1) ~/ chunkSize;

    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    late StreamSubscription<dynamic> sub;

    try {
      await channel.ready.timeout(const Duration(seconds: 15));

      final completer = Completer<String>();
      var chunksAcked = 0;
      var nextChunkToSend = 0;
      var uploadStarted = false;
      String? uploadedFileId;

      void sendChunk(int index) {
        final start = index * chunkSize;
        final end =
            (start + chunkSize > totalSize) ? totalSize : start + chunkSize;
        channel.sink.add(bytes.sublist(start, end));
      }

      sub = channel.stream.listen(
        (raw) {
          if (completer.isCompleted) return;
          if (raw is! String) return;

          try {
            final json = jsonDecode(raw) as Map<String, dynamic>;

            if (!uploadStarted) {
              if (json['success'] != true) {
                completer.completeError(FileServiceException(
                  json['message'] as String? ?? 'Upload rejected',
                ));
                return;
              }
              final fileId = json['file_id'] as String?;
              if (fileId == null || fileId.isEmpty) {
                completer.completeError(const FileServiceException(
                  'Upload started without file_id',
                ));
                return;
              }
              uploadStarted = true;
              uploadedFileId = fileId;
              sendChunk(0);
              nextChunkToSend = 1;
              return;
            }

            if (json['success'] != true) {
              completer.completeError(FileServiceException(
                json['message'] as String? ?? 'Chunk upload failed',
              ));
              return;
            }

            chunksAcked++;
            onProgress?.call(chunksAcked / totalChunks);

            final message = json['message'] as String? ?? '';
            if (message == 'Upload complete') {
              completer.complete(uploadedFileId ?? '');
              return;
            }

            if (nextChunkToSend < totalChunks) {
              sendChunk(nextChunkToSend);
              nextChunkToSend++;
            }
          } catch (e) {
            if (!completer.isCompleted) completer.completeError(e);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.completeError(const FileServiceException(
              'File connection closed before upload finished',
            ));
          }
        },
        cancelOnError: true,
      );

      channel.sink.add(jsonEncode({
        'message_type': 'upload',
        'data': {
          'session_token': sessionToken,
          'filename': filename,
          'mime_type': mimeType,
          'total_size': totalSize,
          'chunk_index': 0,
          'total_chunks': totalChunks,
        },
      }));

      final fileId = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw const FileServiceException('Upload timed out');
        },
      );

      if (fileId.isEmpty) {
        throw const FileServiceException('Upload finished without file_id');
      }
      return fileId;
    } finally {
      await sub.cancel();
      try {
        await channel.sink.close();
      } catch (_) {}
    }
  }

  Future<DownloadedFile> downloadFile({
    required String sessionToken,
    required String fileId,
    void Function(double progress)? onProgress,
  }) async {
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    late StreamSubscription<dynamic> sub;

    try {
      await channel.ready.timeout(const Duration(seconds: 15));

      final completer = Completer<DownloadedFile>();
      final buffer = BytesBuilder(copy: false);
      String? filename;
      int? expectedSize;
      int expectedChunks = 1;
      var receivedChunks = 0;
      var gotMetadata = false;

      Future<void> finish() async {
        if (completer.isCompleted) return;
        final name = filename ?? fileId;
        final fileBytes = buffer.toBytes();
        if (expectedSize != null && fileBytes.length != expectedSize) {
          completer.completeError(FileServiceException(
            'Download size mismatch (${fileBytes.length} vs $expectedSize)',
          ));
          return;
        }
        final localPath = await _saveToDisk(fileId, name, fileBytes);
        completer.complete(DownloadedFile(
          fileId: fileId,
          filename: name,
          bytes: fileBytes,
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
      );
    } finally {
      await sub.cancel();
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
    late StreamSubscription<dynamic> sub;

    try {
      await channel.ready.timeout(const Duration(seconds: 15));
      final completer = Completer<Map<String, dynamic>>();

      sub = channel.stream.listen(
        (raw) {
          if (completer.isCompleted) return;
          if (raw is String) {
            try {
              completer.complete(jsonDecode(raw) as Map<String, dynamic>);
            } catch (e) {
              completer.completeError(e);
            }
          }
        },
        onError: completer.completeError,
        onDone: () {
          if (!completer.isCompleted) {
            completer.completeError(const FileServiceException(
              'Connection closed before response',
            ));
          }
        },
        cancelOnError: true,
      );

      channel.sink.add(jsonEncode(payload));
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
      try {
        await channel.sink.close();
      } catch (_) {}
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
