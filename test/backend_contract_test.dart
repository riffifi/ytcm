import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ytcm/models/group_models.dart';
import 'package:ytcm/models/color_palette.dart';
import 'package:ytcm/models/models.dart';
import 'package:ytcm/services/auth_service.dart';
import 'package:ytcm/services/chat_service.dart';
import 'package:ytcm/services/chat_socket_runner.dart';
import 'package:ytcm/services/file_service.dart';
import 'package:ytcm/services/file_metadata_cache.dart';
import 'package:ytcm/services/notification_service.dart';

void main() {
  group('Rust backend contract', () {
    test('default visual theme follows the YeChat logo palette', () {
      final palette = ColorPaletteOption.presets.first;

      expect(palette.id, ColorPaletteOption.defaultId);
      expect(palette.name, 'Autumn');
      expect(palette.accent, isNot(palette.companion));
    });

    test('parses direct and group message payloads', () {
      final direct = Message.fromJson({
        'uuid': 'message-id',
        'sender_id': 'sender-id',
        'receiver_id': 'receiver-id',
        'dialog_id': 'dialog-id',
        'text': 'hello',
        'file_id': null,
        'created_at': '2026-09-16 12:34:56.123+00',
        'delivered_at': '2026-09-16 12:35:00+00',
        'status': 1,
      });
      final groupMessage = GroupMessage.fromJson({
        'uuid': 'group-message-id',
        'group_id': 'group-id',
        'sender_id': 'sender-id',
        'text': null,
        'file_id': 'file-id',
        'created_at': '2026-09-16 12:34:56+00',
        'who_delivered': <String>[],
        'who_read': <String>[],
        'deleted_for_everyone': false,
        'status': 'sent',
      });

      expect(direct.status, 1);
      expect(direct.createdAt.toUtc().year, 2026);
      expect(groupMessage.previewText, '📎 Attachment');
    });

    test('does not use a username where chat requires a UUID', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        if (request.uri.path == '/getuserinfo') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'username': 'alice',
              'first_name': 'Alice',
              'last_name': '',
              'date_of_birth': '',
              'additional_info': '',
            }));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      final auth = AuthService(
        baseUrl: 'http://${server.address.address}:${server.port}',
      );
      final lookup = await auth.lookupPeer(token: 'token', query: 'alice');

      expect(lookup.result, isNull);
      expect(
          lookup.failure?.message, contains('does not expose their user ID'));
    });

    test('uses the backend email-only registration route', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestUri = Completer<Uri>();
      final subscription = server.listen((request) async {
        requestUri.complete(request.uri);
        request.response
          ..statusCode = HttpStatus.ok
          ..write('ok');
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });
      final auth = AuthService(
        baseUrl: 'http://${server.address.address}:${server.port}',
      );

      final registered = await auth.register(
        username: 'alice',
        email: 'alice@example.com',
        password: 'secret',
        phoneNumber: '',
      );

      expect(registered, isTrue);
      final uri = await requestUri.future;
      expect(uri.path, '/adduserwithoutphone');
      expect(uri.queryParameters['email'], 'alice@example.com');
      expect(uri.queryParameters, isNot(contains('phone_number')));
    });

    test('chat sends join and consumes the backend joined event', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = Completer<List<Map<String, dynamic>>>();
      final events = <Map<String, dynamic>>[];
      final subscription = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((raw) {
          final event = jsonDecode(raw as String) as Map<String, dynamic>;
          events.add(event);
          if (event['action'] == 'join') {
            socket.add(jsonEncode({
              'type': 'joined',
              'user_id': 'user-id',
              'username': 'alice',
              'connection_number': 1,
            }));
          }
          if (events.length == 2 && !received.isCompleted) {
            received.complete(List.of(events));
            socket.add(jsonEncode({
              'type': 'message_deleted',
              'message_uuid': 'message-id',
              'by_user_id': 'user-id',
              'for_everyone': true,
            }));
          }
        });
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      final chat = ChatService(
        wsUrl: 'ws://${server.address.address}:${server.port}',
      );
      addTearDown(chat.dispose);
      final joined = chat.joinEvents.first;
      final deleted = chat.messageDeleted.first;
      chat.sendMessage(receiverId: 'receiver-id', text: 'queued message');

      await chat.connect('session-token');

      final sent = await received.future;
      expect(sent.first, {
        'action': 'join',
        'session_token': 'session-token',
      });
      expect(sent.last, {
        'action': 'send_message',
        'session_token': 'session-token',
        'receiver_id': 'receiver-id',
        'text': 'queued message',
        'file_id': null,
      });
      expect((await joined).uuid, 'user-id');
      expect((await deleted).messageUuid, 'message-id');
      expect(chat.isConnected, isTrue);
      await chat.disconnect();
    });

    test('background inbox check receives direct and group messages then exits',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((raw) {
          final event = jsonDecode(raw as String) as Map<String, dynamic>;
          if (event['action'] != 'join') return;
          socket
            ..add(jsonEncode({
              'type': 'joined',
              'user_id': 'receiver-id',
              'username': 'receiver',
              'connection_number': 1,
            }))
            ..add(jsonEncode({
              'type': 'message',
              'message': {
                'uuid': 'direct-id',
                'sender_id': 'sender-id',
                'receiver_id': 'receiver-id',
                'dialog_id': 'dialog-id',
                'text': 'direct hello',
                'file_id': null,
                'created_at': '2026-09-16 12:34:56+00',
                'delivered_at': '2026-09-16 12:34:57+00',
                'status': 1,
              },
            }))
            ..add(jsonEncode({
              'type': 'group_message',
              'message': {
                'uuid': 'group-id',
                'group_id': 'chat-group-id',
                'sender_id': 'sender-id',
                'text': 'group hello',
                'file_id': null,
                'created_at': '2026-09-16 12:34:56+00',
                'deleted_for_everyone': false,
                'status': 'sent',
              },
            }));
        });
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      final direct = <Message>[];
      final groups = <GroupMessage>[];
      final stopwatch = Stopwatch()..start();
      await ChatSocketRunner.listen(
        chatUrl: 'ws://${server.address.address}:${server.port}',
        sessionToken: 'session-token',
        maxDuration: const Duration(seconds: 3),
        stopAfterIdle: const Duration(milliseconds: 150),
        shouldStop: () => false,
        onLiveMessage: (message) async => direct.add(message),
        onGroupMessage: (message) async => groups.add(message),
      );
      stopwatch.stop();

      expect(direct.single.text, 'direct hello');
      expect(groups.single.text, 'group hello');
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('Android notification icon uses a drawable resource name', () {
      expect(NotificationService.androidSmallIcon, 'ic_stat_chat');
      expect(NotificationService.androidSmallIcon, isNot(contains('/')));
      expect(NotificationService.androidSmallIcon, isNot(startsWith('@')));
    });

    test('file ping explains a reverse-proxy 502', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      final files = FileService(
        wsUrl: 'ws://${server.address.address}:${server.port}/ws',
      );
      final result = await files.pingReachability();

      expect(result, contains('reverse proxy is online'));
      expect(result, contains('backend is unavailable'));
    });

    test('file connection errors are not masked by late subscription errors',
        () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      final files = FileService(wsUrl: 'ws://127.0.0.1:$port');

      await expectLater(
        files.listFiles('session-token'),
        throwsA(
          predicate<Object>(
            (error) =>
                error.runtimeType.toString() != 'LateInitializationError',
            'an original WebSocket connection error',
          ),
        ),
      );
    });

    test('download cache paths cannot escape their storage directory', () {
      final path = FileMetadataCache.localPathFor('../bad-id', '../../');

      expect(path, isNot(contains('..')));
      expect(path.split(Platform.pathSeparator).last, isNotEmpty);
    });
  });
}
