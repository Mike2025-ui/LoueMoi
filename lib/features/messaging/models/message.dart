import 'package:equatable/equatable.dart';

/// Type de contenu d'un message — correspond exactement aux valeurs
/// Message.ATTACHMENT_TYPE_CHOICES côté Django.
enum MessageAttachmentType {
  text,
  image,
  video,
  audio;

  static MessageAttachmentType fromString(String? value) => switch (value) {
        'image' => MessageAttachmentType.image,
        'video' => MessageAttachmentType.video,
        'audio' => MessageAttachmentType.audio,
        _ => MessageAttachmentType.text,
      };

  String toJson() => name;
}

class Message extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String content;
  final MessageAttachmentType attachmentType;

  /// URL de téléchargement protégée (jamais l'URL MEDIA_URL brute) — null
  /// pour un message texte simple.
  final String? attachmentUrl;

  /// Durée en secondes, pertinente uniquement pour audio/vidéo.
  final int? duration;

  final DateTime createdAt;
  final bool isRead;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.attachmentType = MessageAttachmentType.text,
    this.attachmentUrl,
    this.duration,
    required this.createdAt,
    this.isRead = false,
  });

  bool get hasAttachment => attachmentUrl != null;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      conversationId: json['conversation_id'].toString(),
      senderId: json['sender_id'].toString(),
      receiverId: json['receiver_id'].toString(),
      content: json['content'] as String? ?? '',
      attachmentType: MessageAttachmentType.fromString(json['attachment_type'] as String?),
      attachmentUrl: json['attachment_url'] as String?,
      duration: json['duration'] as int?,
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
        'attachment_type': attachmentType.toJson(),
        'attachment_url': attachmentUrl,
        'duration': duration,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
      };

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        receiverId,
        content,
        attachmentType,
        attachmentUrl,
        duration,
        createdAt,
        isRead,
      ];
}

/// Regroupe les messages d'une conversation avec un agent/utilisateur donné.
class Conversation extends Equatable {
  final String id;
  final String participantName;
  final String? participantPhoto;
  final Message? lastMessage;
  final int unreadCount;

  /// Propriété au sujet de laquelle la conversation a été ouverte (ex:
  /// "Contacter l'agent" depuis une fiche annonce) — null pour une
  /// conversation non liée à une annonce précise. Utilisé pour "Propriétés
  /// contactées" (voir features/profile/screens/contacted_properties_screen.dart) :
  /// jamais de données inventées, uniquement ce que Django a réellement
  /// enregistré sur Conversation.property.
  final String? propertyId;

  const Conversation({
    required this.id,
    required this.participantName,
    this.participantPhoto,
    this.lastMessage,
    this.unreadCount = 0,
    this.propertyId,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final lastMessageJson = json['last_message'] as Map<String, dynamic>?;
    return Conversation(
      id: json['id'].toString(),
      participantName: json['participant_name'] as String,
      participantPhoto: json['participant_photo'] as String?,
      lastMessage: lastMessageJson != null ? Message.fromJson(lastMessageJson) : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      propertyId: json['property']?.toString(),
    );
  }

  @override
  List<Object?> get props =>
      [id, participantName, participantPhoto, lastMessage, unreadCount, propertyId];
}
