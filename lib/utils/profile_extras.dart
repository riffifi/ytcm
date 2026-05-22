import 'dart:convert';

/// Bio and avatar file id stored in auth `additional_info` as JSON.
class ProfileExtras {
  final String? bio;
  final String? avatarFileId;

  const ProfileExtras({this.bio, this.avatarFileId});

  static String? _clean(String? value) {
    if (value == null) return null;
    final t = value.trim();
    if (t.isEmpty || t == 'null') return null;
    return t;
  }

  static ProfileExtras parse(String? additionalInfo) {
    final raw = _clean(additionalInfo);
    if (raw == null) return const ProfileExtras();

    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return ProfileExtras(
            bio: _clean(decoded['bio'] as String?),
            avatarFileId: _clean(decoded['avatar_file_id'] as String?),
          );
        }
      } catch (_) {}
    }

    return ProfileExtras(bio: raw);
  }

  String serialize({String? bio, String? avatarFileId}) {
    final b = _clean(bio) ?? this.bio;
    final a = _clean(avatarFileId) ?? this.avatarFileId;
    final map = <String, String>{};
    if (b != null) map['bio'] = b;
    if (a != null) map['avatar_file_id'] = a;
    if (map.isEmpty) return '';
    return jsonEncode(map);
  }
}
