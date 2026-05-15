import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class PeerLookupResult {
  final String username;
  final String uuid;

  const PeerLookupResult({required this.username, required this.uuid});
}

class PeerLookupFailure {
  final String message;
  const PeerLookupFailure(this.message);
}

class AuthService {
  final String baseUrl;

  AuthService({this.baseUrl = 'http://127.0.0.1:3000'});

  Future<String?> login({
    required String loginDetails,
    required String password,
    String loginType = 'email',
    int liveTime = 86400,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'login_type': loginType,
              'login_details': loginDetails,
              'password': password,
              'live_time': liveTime,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return res.body.trim();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/adduser').replace(queryParameters: {
        'username': username,
        'email': email,
        'password': password,
        'phone_number': phoneNumber,
      });
      final res =
          await http.get(uri).timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Uses built-in GET /getuserinfo (existing auth API) to resolve a peer.
  Future<({PeerLookupResult? result, PeerLookupFailure? failure})> lookupPeer({
    required String token,
    required String query,
  }) async {
    final normalized = _normalizeQuery(query);
    if (normalized.isEmpty) {
      return (result: null, failure: const PeerLookupFailure('Enter a username'));
    }

    if (_looksLikeUuid(normalized)) {
      return (
        result: PeerLookupResult(username: normalized, uuid: normalized),
        failure: null,
      );
    }

    PeerLookupFailure? lastFailure;
    for (final candidate in _usernameCandidates(normalized)) {
      final attempt = await _getUserInfoOnce(token: token, username: candidate);
      if (attempt.result != null) {
        return (result: attempt.result, failure: null);
      }
      lastFailure = attempt.failure ?? lastFailure;
    }

    return (
      result: null,
      failure: lastFailure ??
          PeerLookupFailure('No user "$normalized" on auth server (getuserinfo 404).'),
    );
  }

  String _normalizeQuery(String raw) {
    var q = raw.trim();
    if (q.startsWith('@')) q = q.substring(1).trim();
    return q;
  }

  bool _looksLikeUuid(String value) {
    final re = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return re.hasMatch(value);
  }

  List<String> _usernameCandidates(String query) {
    final seen = <String>{};
    final out = <String>[];
    void add(String s) {
      if (s.isNotEmpty && seen.add(s)) out.add(s);
    }

    add(query);
    add(query.toLowerCase());
    return out;
  }

  Future<({PeerLookupResult? result, PeerLookupFailure? failure})> _getUserInfoOnce({
    required String token,
    required String username,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/getuserinfo').replace(
        queryParameters: {
          'session_tocken': token,
          'username': username,
        },
      );
      final res =
          await http.get(uri).timeout(const Duration(seconds: 15));

      if (res.statusCode == 404) {
        return (result: null, failure: null);
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return (
          result: null,
          failure: const PeerLookupFailure('Session expired — sign in again'),
        );
      }
      if (res.statusCode != 200) {
        return (
          result: null,
          failure: PeerLookupFailure(
            'getuserinfo HTTP ${res.statusCode} — check auth URL in settings',
          ),
        );
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final rawName = (json['username'] as String?)?.trim();
      final resolvedUsername =
          (rawName != null && rawName.isNotEmpty) ? rawName : username;

      // Prefer uuid when server includes it; otherwise use username as receiver_id
      // (some deployments accept username on send_message / match on delivery).
      final uuid = _readUuid(json) ?? resolvedUsername;

      return (
        result: PeerLookupResult(username: resolvedUsername, uuid: uuid),
        failure: null,
      );
    } catch (e) {
      return (
        result: null,
        failure: PeerLookupFailure('Cannot reach auth server: $e'),
      );
    }
  }

  String? _readUuid(Map<String, dynamic> json) {
    for (final key in ['uuid', 'user_id', 'user_uuid', 'id']) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty && _looksLikeUuid(v.trim())) {
        return v.trim();
      }
    }
    return null;
  }

  Future<UserInfo?> getSessionInfo(String token) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/sessionuserinfo'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_tocken': token}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return UserInfo.fromSessionJson(jsonDecode(res.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String> ping() async {
    try {
      final uri = Uri.parse(baseUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      return 'Reachable (HTTP ${res.statusCode})';
    } catch (e) {
      return 'Failed: $e';
    }
  }

  Future<void> setOnline(String token) async {
    try {
      await http
          .get(Uri.parse('$baseUrl/online').replace(
            queryParameters: {'session_tocken': token},
          ))
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> setOffline(String token) async {
    try {
      await http
          .get(Uri.parse('$baseUrl/offline').replace(
            queryParameters: {'session_tocken': token},
          ))
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<bool> changeUsername(String token, String newUsername) async {
    try {
      final uri =
          Uri.parse('$baseUrl/changeusername').replace(queryParameters: {
        'session_tocken': token,
        'new_value': newUsername,
      });
      final res =
          await http.get(uri).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changeFirstName(String token, String value) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/changefirstname'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_tocken': token, 'new_value': value}),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changeLastName(String token, String value) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/changelastname'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_tocken': token, 'new_value': value}),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
