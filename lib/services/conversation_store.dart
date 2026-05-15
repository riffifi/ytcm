import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists known conversation peers (uuid → username) across app restarts.
class ConversationStore {
  static const _keyPeerNames = 'conversation_peer_names';

  Map<String, String> _peerNames = {};

  Map<String, String> get peerNames => Map.unmodifiable(_peerNames);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPeerNames);
    if (raw == null) return;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPeerNames, jsonEncode(_peerNames));
  }

  void clear() {
    _peerNames = {};
  }
}
