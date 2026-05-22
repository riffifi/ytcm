import '../utils/timestamp.dart';

class ChatGroup {
  final String uuid;
  final String name;
  final String? description;
  final String? avatarId;
  final DateTime createdAt;
  final bool isPrivate;
  final bool isChannel;

  const ChatGroup({
    required this.uuid,
    required this.name,
    this.description,
    this.avatarId,
    required this.createdAt,
    required this.isPrivate,
    required this.isChannel,
  });

  factory ChatGroup.fromJson(Map<String, dynamic> json) => ChatGroup(
        uuid: json['uuid'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        avatarId: json['avatar_id'] as String?,
        createdAt: parseServerTimestamp(json['created_at']),
        isPrivate: json['is_private'] as bool? ?? false,
        isChannel: json['is_channel'] as bool? ?? false,
      );
}

class GroupMessage {
  final String uuid;
  final String groupId;
  final String senderId;
  final String? text;
  final String? fileId;
  final DateTime createdAt;
  final bool deletedForEveryone;
  final String status;

  const GroupMessage({
    required this.uuid,
    required this.groupId,
    required this.senderId,
    this.text,
    this.fileId,
    required this.createdAt,
    required this.deletedForEveryone,
    required this.status,
  });

  String get previewText {
    final t = text?.trim();
    if (t != null && t.isNotEmpty) return t;
    if (fileId != null && fileId!.isNotEmpty) return '📎 Attachment';
    return '';
  }

  factory GroupMessage.fromJson(Map<String, dynamic> json) => GroupMessage(
        uuid: json['uuid'] as String,
        groupId: json['group_id'] as String,
        senderId: json['sender_id'] as String,
        text: json['text'] as String?,
        fileId: json['file_id'] as String?,
        createdAt: parseServerTimestamp(json['created_at']),
        deletedForEveryone: json['deleted_for_everyone'] as bool? ?? false,
        status: json['status'] as String? ?? 'sent',
      );
}
