import 'package:equatable/equatable.dart';

class Message extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      conversationId: json['conversation_id'].toString(),
      senderId: json['sender_id'].toString(),
      receiverId: json['receiver_id'].toString(),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
      };

  @override
  List<Object?> get props =>
      [id, conversationId, senderId, receiverId, content, createdAt, isRead];
}

/// Regroupe les messages d'une conversation avec un agent/utilisateur donné.
class Conversation extends Equatable {
  final String id;
  final String participantName;
  final String? participantPhoto;
  final Message? lastMessage;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.participantName,
    this.participantPhoto,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final lastMessageJson = json['last_message'] as Map<String, dynamic>?;
    return Conversation(
      id: json['id'].toString(),
      participantName: json['participant_name'] as String,
      participantPhoto: json['participant_photo'] as String?,
      lastMessage: lastMessageJson != null ? Message.fromJson(lastMessageJson) : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [id, participantName, participantPhoto, lastMessage, unreadCount];
}
