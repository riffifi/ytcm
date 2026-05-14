// models/message.dart
class Message {
  final String uuid;
  final String senderId;
  final String receiverId;
  final String dialogId;
  final String? text;
  final String? fileId;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final int status; // 0=pending, 1=delivered, 2=read

  Message({
    required this.uuid,
    required this.senderId,
    required this.receiverId,
    required this.dialogId,
    this.text,
    this.fileId,
    required this.createdAt,
    this.deliveredAt,
    required this.status,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        uuid: json['uuid'],
        senderId: json['sender_id'],
        receiverId: json['receiver_id'],
        dialogId: json['dialog_id'],
        text: json['text'],
        fileId: json['file_id'],
        createdAt: DateTime.parse(json['created_at']),
        deliveredAt: json['delivered_at'] != null
            ? DateTime.parse(json['delivered_at'])
            : null,
        status: json['status'] ?? 0,
      );

  Message copyWith({int? status}) => Message(
        uuid: uuid,
        senderId: senderId,
        receiverId: receiverId,
        dialogId: dialogId,
        text: text,
        fileId: fileId,
        createdAt: createdAt,
        deliveredAt: deliveredAt,
        status: status ?? this.status,
      );
}

class UserInfo {
  final String uuid;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? dateOfBirth;
  final String? additionalInfo;

  UserInfo({
    required this.uuid,
    required this.username,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.additionalInfo,
  });

  factory UserInfo.fromSessionJson(Map<String, dynamic> json) => UserInfo(
        uuid: json['uuid'],
        username: json['username'],
      );

  factory UserInfo.fromProfileJson(Map<String, dynamic> json, String uuid) =>
      UserInfo(
        uuid: uuid,
        username: json['username'],
        firstName: json['first_name'],
        lastName: json['last_name'],
        dateOfBirth: json['date_of_birth'],
        additionalInfo: json['additional_info'],
      );

  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) {
      return lastName != null && lastName!.isNotEmpty
          ? '$firstName $lastName'
          : firstName!;
    }
    return username;
  }

  String get initials {
    final name = displayName;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class Connection {
  final int number;
  final String uuid;
  final String username;

  Connection({required this.number, required this.uuid, required this.username});

  factory Connection.fromJson(Map<String, dynamic> json) => Connection(
        number: json['number'],
        uuid: json['uuid'],
        username: json['username'],
      );
}
