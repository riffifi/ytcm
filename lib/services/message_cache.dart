import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// On-device message history (documents dir). Survives app restarts on mobile.
class MessageCache {
  static const _fileName = 'messages_cache.json';
  static const maxMessagesPerPeer = 500;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<Map<String, List<Message>>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final out = <String, List<Message>>{};
      for (final entry in decoded.entries) {
        final list = entry.value;
        if (list is! List) continue;
        out[entry.key] = list
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, List<Message>> conversations) async {
    try {
      final payload = <String, dynamic>{};
      for (final entry in conversations.entries) {
        final msgs = entry.value;
        if (msgs.isEmpty) continue;
        final start = msgs.length > maxMessagesPerPeer
            ? msgs.length - maxMessagesPerPeer
            : 0;
        payload[entry.key] =
            msgs.sublist(start).map((m) => m.toJson()).toList();
      }
      final file = await _file();
      await file.writeAsString(jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
