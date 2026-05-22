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

  AuthService({required String baseUrl}) : baseUrl = _normalizeBaseUrl(baseUrl);

  static String _normalizeBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

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

  /// Resolves a peer via /resolvepeer and GET /getuserinfo (auth API).
  Future<({PeerLookupResult? result, PeerLookupFailure? failure})> lookupPeer({
    required String token,
    required String query,
  }) async {
    final normalized = _normalizeQuery(query);
    if (normalized.isEmpty) {
      return (result: null, failure: const PeerLookupFailure('Enter a username'));
    }

    if (_looksLikeUuid(normalized)) {
      final uuid = _normalizeUuid(normalized);
      return (
        result: PeerLookupResult(username: uuid, uuid: uuid),
        failure: null,
      );
    }

    PeerLookupFailure? lastFailure;
    String? profileUsername;

    for (final candidate in _queryCandidates(normalized)) {
      final resolved = await _resolvePeerOnce(token: token, query: candidate);
      if (resolved.result != null) {
        return (result: resolved.result, failure: null);
      }
      lastFailure = resolved.failure ?? lastFailure;
    }

    for (final candidate in _usernameCandidates(normalized)) {
      final attempt = await _getUserInfoOnce(token: token, username: candidate);
      if (attempt.result != null) {
        return (result: attempt.result, failure: null);
      }
      profileUsername = attempt.profileUsername ?? profileUsername;
      lastFailure = attempt.failure ?? lastFailure;
    }

    if (profileUsername != null) {
      for (final candidate in _usernameCandidates(profileUsername)) {
        final retry = await _resolvePeerOnce(token: token, query: candidate);
        if (retry.result != null) {
          return (result: retry.result, failure: null);
        }
        lastFailure = retry.failure ?? lastFailure;
      }

      // Auth confirmed the account; they do not need to be online. Chat server
      // resolves username → UUID on send when /resolvepeer is unavailable.
      return (
        result: PeerLookupResult(
          username: profileUsername,
          uuid: profileUsername,
        ),
        failure: null,
      );
    }

    return (
      result: null,
      failure: lastFailure ??
          PeerLookupFailure(
            'No user "$normalized" on the auth server — check username, email, '
            'and that Server settings → Auth URL matches where accounts were created.',
          ),
    );
  }

  Future<({PeerLookupResult? result, PeerLookupFailure? failure})> _resolvePeerOnce({
    required String token,
    required String query,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/resolvepeer').replace(
        queryParameters: {
          'session_tocken': token,
          'query': query,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 15));

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
        return (result: null, failure: null);
      }

      final parsed = _parsePeerJson(res.body, fallbackUsername: query);
      if (parsed == null) {
        return (
          result: null,
          failure: const PeerLookupFailure('Auth server returned no user UUID'),
        );
      }
      return (result: parsed, failure: null);
    } catch (e) {
      return (
        result: null,
        failure: PeerLookupFailure('Cannot reach auth server: $e'),
      );
    }
  }

  String _normalizeQuery(String raw) {
    var q = raw.trim();
    if (q.startsWith('@')) q = q.substring(1).trim();
    return q;
  }

  bool _looksLikeUuid(String value) {
    final v = value.trim();
    final dashed = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    final compact = RegExp(r'^[0-9a-f]{32}$', caseSensitive: false);
    return dashed.hasMatch(v) || compact.hasMatch(v);
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

  List<String> _queryCandidates(String query) {
    final seen = <String>{};
    final out = <String>[];
    void add(String s) {
      if (s.isNotEmpty && seen.add(s)) out.add(s);
    }

    add(query);
    add(query.toLowerCase());
    if (query.contains('@')) {
      final local = query.split('@').first.trim();
      add(local);
      add(local.toLowerCase());
    }
    return out;
  }

  Future<
      ({
        PeerLookupResult? result,
        PeerLookupFailure? failure,
        String? profileUsername,
      })> _getUserInfoOnce({
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
        return (result: null, failure: null, profileUsername: null);
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return (
          result: null,
          failure: const PeerLookupFailure('Session expired — sign in again'),
          profileUsername: null,
        );
      }
      if (res.statusCode != 200) {
        return (
          result: null,
          failure: PeerLookupFailure(
            'getuserinfo HTTP ${res.statusCode} — check auth URL in settings',
          ),
          profileUsername: null,
        );
      }

      final body = res.body.trim();
      var resolvedUsername = username;
      String? uuid;

      if (body.startsWith('{')) {
        try {
          final json = jsonDecode(body);
          if (json is Map<String, dynamic>) {
            final rawName = (json['username'] as String?)?.trim();
            if (rawName != null && rawName.isNotEmpty) {
              resolvedUsername = rawName;
            }
            uuid = _readUuid(json);
          }
        } catch (_) {}
      }

      uuid ??= _uuidFromRawBody(body);

      if (uuid != null) {
        return (
          result: PeerLookupResult(username: resolvedUsername, uuid: uuid),
          failure: null,
          profileUsername: resolvedUsername,
        );
      }

      if (body.startsWith('{') &&
          body.contains('"username"') &&
          !body.contains('uuid')) {
        return (
          result: null,
          failure: null,
          profileUsername: resolvedUsername,
        );
      }

      return (result: null, failure: null, profileUsername: null);
    } catch (e) {
      return (
        result: null,
        failure: PeerLookupFailure('Cannot reach auth server: $e'),
        profileUsername: null,
      );
    }
  }

  PeerLookupResult? _parsePeerJson(String body, {required String fallbackUsername}) {
    final trimmed = body.trim();
    if (!trimmed.startsWith('{')) {
      final uuid = _uuidFromRawBody(trimmed);
      if (uuid == null) return null;
      return PeerLookupResult(username: fallbackUsername, uuid: uuid);
    }

    try {
      final json = jsonDecode(trimmed);
      if (json is! Map<String, dynamic>) return null;
      final uuid = _readUuid(json) ?? _uuidFromRawBody(trimmed);
      if (uuid == null) return null;
      final username = (json['username'] as String?)?.trim();
      return PeerLookupResult(
        username: (username != null && username.isNotEmpty)
            ? username
            : fallbackUsername,
        uuid: uuid,
      );
    } catch (_) {
      final uuid = _uuidFromRawBody(trimmed);
      if (uuid == null) return null;
      return PeerLookupResult(username: fallbackUsername, uuid: uuid);
    }
  }

  String? _readUuid(Map<String, dynamic> json) {
    for (final key in ['uuid', 'user_id', 'user_uuid', 'id', 'UUID']) {
      final fromKey = _uuidFromDynamic(json[key]);
      if (fromKey != null) return fromKey;
    }
    return _scanForUuid(json);
  }

  String? _uuidFromDynamic(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (_looksLikeUuid(trimmed)) return _normalizeUuid(trimmed);
    return null;
  }

  String? _scanForUuid(dynamic value) {
    if (value is Map<String, dynamic>) {
      for (final entry in value.entries) {
        final fromKey = _uuidFromDynamic(entry.value);
        if (fromKey != null) return fromKey;
        final nested = _scanForUuid(entry.value);
        if (nested != null) return nested;
      }
    } else if (value is List) {
      for (final item in value) {
        final nested = _scanForUuid(item);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  String? _uuidFromRawBody(String body) {
    final match = RegExp(
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      caseSensitive: false,
    ).firstMatch(body);
    if (match == null) return null;
    return _normalizeUuid(match.group(0)!);
  }

  String _normalizeUuid(String value) {
    final v = value.trim().toLowerCase();
    if (v.contains('-')) return v;
    if (v.length == 32) {
      return '${v.substring(0, 8)}-${v.substring(8, 12)}-${v.substring(12, 16)}-'
          '${v.substring(16, 20)}-${v.substring(20)}';
    }
    return v;
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

  /// Checks whether /resolvepeer exists on this auth deployment.
  Future<String> pingResolvePeer(String token) async {
    try {
      final uri = Uri.parse('$baseUrl/resolvepeer').replace(
        queryParameters: {
          'session_tocken': token,
          'query': 'test-nonexistent-user-xyz',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 404) {
        return 'resolvepeer available (404 = user not found, route exists)';
      }
      if (res.statusCode == 200) {
        return 'resolvepeer available';
      }
      if (res.statusCode == 401) {
        return 'resolvepeer available (session check)';
      }
      return 'resolvepeer HTTP ${res.statusCode}';
    } catch (e) {
      return 'resolvepeer not reachable: $e';
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
