import 'dart:convert';

import 'package:http/http.dart' as http;

class GifResult {
  final String id;
  final String previewUrl;
  final String gifUrl;

  const GifResult({
    required this.id,
    required this.previewUrl,
    required this.gifUrl,
  });
}

/// GIF search via Tenor v1 (public demo key; override with [tenorApiKey]).
class GifSearchService {
  /// Tenor's documented public test key for api.tenor.com/v1.
  static const tenorDemoKey = 'LIVDSRZULELA';

  final String? tenorApiKey;

  GifSearchService({this.tenorApiKey});

  String get _key {
    final custom = tenorApiKey?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return tenorDemoKey;
  }

  static const _timeout = Duration(seconds: 12);

  Future<List<GifResult>> search(String query, {int limit = 24}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    try {
      final fromTenor = await _searchTenorV1(q, limit: limit);
      if (fromTenor.isNotEmpty) return fromTenor;
    } catch (_) {}

    return _searchNekosFallback(q);
  }

  Future<List<GifResult>> _searchTenorV1(String query,
      {required int limit}) async {
    final uri = Uri.https('api.tenor.com', '/v1/search', {
      'key': _key,
      'q': query,
      'limit': '$limit',
      'contentfilter': 'medium',
      'media_filter': 'gif,tinygif,mediumgif,webp',
    });
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw GifSearchException('Tenor HTTP ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? [];
    final out = <GifResult>[];

    for (final raw in results) {
      if (raw is! Map<String, dynamic>) continue;
      final mediaList = raw['media'] as List<dynamic>?;
      if (mediaList == null || mediaList.isEmpty) continue;
      final media = mediaList.first;
      if (media is! Map<String, dynamic>) continue;

      final picked = _pickTenorFormat(media);
      if (picked == null) continue;

      final gifUrl = picked['url'] as String?;
      if (gifUrl == null || gifUrl.isEmpty) continue;

      final preview = (picked['preview'] as String?) ?? gifUrl;

      out.add(GifResult(
        id: raw['id']?.toString() ?? gifUrl,
        previewUrl: preview,
        gifUrl: gifUrl,
      ));
    }
    return out;
  }

  Map<String, dynamic>? _pickTenorFormat(Map<String, dynamic> media) {
    const keys = [
      'gif',
      'mediumgif',
      'tinygif',
      'nanogif',
      'webp',
    ];
    for (final key in keys) {
      final item = media[key];
      if (item is Map<String, dynamic> && item['url'] != null) {
        return item;
      }
    }
    return null;
  }

  /// Single-result fallback when Tenor is down or rate-limited.
  Future<List<GifResult>> _searchNekosFallback(String query) async {
    final action = _nekosActionForQuery(query);
    final uri = Uri.https('nekos.best', '/api/v2/$action');
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? [];
    final out = <GifResult>[];

    for (final raw in results.take(12)) {
      if (raw is! Map<String, dynamic>) continue;
      final url = raw['url'] as String?;
      if (url == null || url.isEmpty) continue;
      out.add(GifResult(
        id: url,
        previewUrl: url,
        gifUrl: url,
      ));
    }
    return out;
  }

  static const _nekosActions = [
    'happy',
    'dance',
    'laugh',
    'wave',
    'hug',
    'kiss',
    'pat',
    'cry',
    'angry',
    'bonk',
    'yeet',
    'smile',
    'wink',
    'nod',
    'run',
  ];

  String _nekosActionForQuery(String query) {
    final q = query.toLowerCase();
    for (final action in _nekosActions) {
      if (q.contains(action)) return action;
    }
    return _nekosActions[q.hashCode.abs() % _nekosActions.length];
  }
}

class GifSearchException implements Exception {
  final String message;
  GifSearchException(this.message);

  @override
  String toString() => message;
}
