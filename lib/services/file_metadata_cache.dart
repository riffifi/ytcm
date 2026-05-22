import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/messenger_file.dart';

/// Persists known file metadata (filename, mime) keyed by file_id.
class FileMetadataCache {
  static const _prefsKey = 'file_metadata_cache_v1';

  final Map<String, MessengerFileInfo> _byId = {};

  MessengerFileInfo? get(String fileId) => _byId[fileId];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        _byId[entry.key] = MessengerFileInfo.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    } catch (_) {}
  }

  Future<void> put(MessengerFileInfo info) async {
    _byId[info.fileId] = info;
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      for (final e in _byId.entries) e.key: e.value.toJson(),
    };
    await prefs.setString(_prefsKey, jsonEncode(payload));
  }

  static Future<String> downloadsDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = p.join(base.path, 'messenger_files');
    return dir;
  }

  static String localPathFor(String fileId, String filename) {
    final safeName = filename.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    return p.join(fileId, safeName);
  }
}
