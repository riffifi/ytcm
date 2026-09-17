import 'dart:convert';

/// Bio and avatar file id stored in auth `additional_info` as JSON.
class ProfileExtras {
  final String? bio;
  final String? avatarFileId;
  final Map<String, dynamic> extraFields;

  const ProfileExtras({
    this.bio,
    this.avatarFileId,
    this.extraFields = const {},
  });

  static String? _clean(dynamic value) {
    if (value == null) return null;
    final t = value.toString().trim();
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
            bio: _clean(decoded['bio']),
            avatarFileId:
                _clean(decoded['avatar_file_id'] ?? decoded['avatar_id']),
            extraFields: Map<String, dynamic>.from(decoded)
              ..remove('bio')
              ..remove('avatar_file_id')
              ..remove('avatar_id'),
          );
        }
      } catch (_) {}
    }

    return ProfileExtras(bio: raw);
  }

  String serialize({String? bio, String? avatarFileId}) {
    final b = _clean(bio) ?? this.bio;
    final a = _clean(avatarFileId) ?? this.avatarFileId;
    final map = <String, dynamic>{...extraFields};
    if (b != null) map['bio'] = b;
    if (a != null) map['avatar_file_id'] = a;
    if (map.isEmpty) return '';
    return jsonEncode(map);
  }
}
