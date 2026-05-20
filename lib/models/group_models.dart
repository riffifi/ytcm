import '../utils/timestamp.dart';

/// Server `StoredGroup` (snake_case JSON).
class GroupInfo {
  final String uuid;
  final String name;
  final String? description;
  final String? avatarId;
  final DateTime createdAt;
  final bool isPrivate;
  final bool isChannel;

  GroupInfo({
    required this.uuid,
    required this.name,
    this.description,
    this.avatarId,
    required this.createdAt,
    required this.isPrivate,
    required this.isChannel,
  });

  factory GroupInfo.fromJson(Map<String, dynamic> json) => GroupInfo(
        uuid: json['uuid'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        avatarId: json['avatar_id'] as String?,
        createdAt: parseServerTimestamp(json['created_at']),
        isPrivate: json['is_private'] as bool? ?? false,
        isChannel: json['is_channel'] as bool? ?? false,
      );
}

class GroupMember {
  final String groupId;
  final String userId;
  final String role;
  final DateTime joinedAt;

  GroupMember({
    required this.groupId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        groupId: json['group_id'] as String,
        userId: json['user_id'] as String,
        role: json['role'] as String? ?? 'member',
        joinedAt: parseServerTimestamp(json['joined_at']),
      );
}

class GroupDetails {
  final GroupInfo group;
  final List<GroupMember> members;

  GroupDetails({required this.group, required this.members});

  factory GroupDetails.fromJson(Map<String, dynamic> json) {
    final details = json['details'] as Map<String, dynamic>? ??
        (throw FormatException('missing details'));
    final g = details['group'] as Map<String, dynamic>? ??
        (throw FormatException('missing group'));
    final members = (details['members'] as List? ?? [])
        .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
        .toList();
    return GroupDetails(
      group: GroupInfo.fromJson(g),
      members: members,
    );
  }
}

/// Server `StoredGroupMessage`.
class GroupMessage {
  final String uuid;
  final String groupId;
  final String senderId;
  final String? text;
  final String? fileId;
  final DateTime createdAt;
  final List<String> whoDelivered;
  final List<String> whoRead;
  final bool deletedForEveryone;
  final String status;

  GroupMessage({
    required this.uuid,
    required this.groupId,
    required this.senderId,
    this.text,
    this.fileId,
    required this.createdAt,
    required this.whoDelivered,
    required this.whoRead,
    required this.deletedForEveryone,
    required this.status,
  });

  factory GroupMessage.fromJson(Map<String, dynamic> json) => GroupMessage(
        uuid: json['uuid'] as String,
        groupId: json['group_id'] as String,
        senderId: json['sender_id'] as String,
        text: json['text'] as String?,
        fileId: json['file_id'] as String?,
        createdAt: parseServerTimestamp(json['created_at']),
        whoDelivered: (json['who_delivered'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        whoRead: (json['who_read'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        deletedForEveryone: json['deleted_for_everyone'] as bool? ?? false,
        status: json['status'] as String? ?? 'sent',
      );

  String get previewText {
    final t = text?.trim();
    if (t != null && t.isNotEmpty) return t;
    if (fileId != null && fileId!.isNotEmpty) return 'Attachment';
    return '';
  }

  bool isReadBy(String userId) => whoRead.contains(userId);
}

enum GroupListKind { replace, upsert, remove }

class GroupListEvent {
  final GroupListKind kind;
  final List<GroupInfo>? groups;
  final GroupInfo? group;
  final String? groupId;

  const GroupListEvent.replace(this.groups)
      : kind = GroupListKind.replace,
        group = null,
        groupId = null;

  const GroupListEvent.upsert(this.group)
      : kind = GroupListKind.upsert,
        groups = null,
        groupId = null;

  const GroupListEvent.remove(this.groupId)
      : kind = GroupListKind.remove,
        groups = null,
        group = null;
}
