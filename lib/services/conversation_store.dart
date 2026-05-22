import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists known conversation peers (uuid → username) per account.
class ConversationStore {
  static const _legacyKey = 'conversation_peer_names';

  String? _userId;
  Map<String, String> _peerNames = {};

  Map<String, String> get peerNames => Map.unmodifiable(_peerNames);

  String? get userId => _userId;

  String _storageKey(String userId) => 'conversation_peer_names_$userId';

  /// Switches to an account's saved peers. Pass null to detach without deleting data.
  Future<void> setUserScope(String? userId) async {
    _userId = userId;
    _peerNames = {};
    if (userId != null && userId.isNotEmpty) {
      await load();
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _userId != null ? _storageKey(_userId!) : _legacyKey;
    final raw = prefs.getString(key);
    if (raw == null && _userId != null) {
      // Migrate legacy single-user key into scoped storage once.
      final legacy = prefs.getString(_legacyKey);
      if (legacy != null) {
        await prefs.setString(key, legacy);
        await _decode(legacy);
        return;
      }
    }
    if (raw == null) return;
    await _decode(raw);
  }

  Future<void> _decode(String raw) async {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _peerNames = decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      _peerNames = {};
    }
  }

  void setName(String userId, String username) {
    if (userId.isEmpty || username.isEmpty) return;
    _peerNames[userId] = username;
  }

  String? nameFor(String userId) => _peerNames[userId];

  Future<void> save() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(_userId!),
      jsonEncode(_peerNames),
    );
  }

  /// Clears in-memory peers only (keeps on-disk data for this account).
  void clearMemory() {
    _peerNames = {};
  }
}
