import '../models/message.dart';

/// Contrat de messagerie. Architecture prête pour un flux WebSocket
/// (méthode [watchMessages] pourra être remplacée par un stream temps réel).
abstract class MessageRepository {
  Future<List<Conversation>> fetchConversations();
  Future<List<Message>> fetchMessages(String conversationId);

  /// Envoie un message texte et/ou une pièce jointe (image/vidéo/audio).
  /// [attachmentPath] null => message texte simple ; sinon un fichier local
  /// (photo/vidéo sélectionnée, ou vocal enregistré) est uploadé en
  /// multipart, et [attachmentType] doit être renseigné en conséquence.
  Future<Message> sendMessage({
    required String conversationId,
    String content = '',
    String? attachmentPath,
    MessageAttachmentType attachmentType = MessageAttachmentType.text,
    int? duration,
  });

  /// Récupère (ou crée) la conversation avec cet agent, à propos d'une
  /// propriété donnée, et retourne son id — à appeler avant de naviguer vers
  /// l'écran de conversation depuis "Contacter l'agent".
  Future<String> getOrCreateConversationId({required String agentId, String? propertyId});

  /// Marque comme lus tous les messages reçus dans cette conversation — à
  /// appeler à l'ouverture de l'écran de conversation, jamais recalculé
  /// côté Flutter (unread_count reste calculé par Django).
  Future<void> markConversationRead(String conversationId);
}

class MockMessageRepository implements MessageRepository {
  final Map<String, List<Message>> _messages = {
    'conv-1': [
      Message(
        id: 'm1',
        conversationId: 'conv-1',
        senderId: 'agent-1',
        receiverId: 'user-1',
        content: 'Bonjour, l’appartement est-il toujours disponible ?',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: true,
      ),
      Message(
        id: 'm2',
        conversationId: 'conv-1',
        senderId: 'user-1',
        receiverId: 'agent-1',
        content: 'Oui il est disponible, souhaitez-vous une visite ?',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        isRead: true,
      ),
    ],
  };

  @override
  Future<List<Conversation>> fetchConversations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Conversation(
        id: 'conv-1',
        participantName: 'Mme Kouakou',
        lastMessage: _messages['conv-1']?.last,
        unreadCount: 0,
      ),
    ];
  }

  @override
  Future<List<Message>> fetchMessages(String conversationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_messages[conversationId] ?? []);
  }

  @override
  Future<Message> sendMessage({
    required String conversationId,
    String content = '',
    String? attachmentPath,
    MessageAttachmentType attachmentType = MessageAttachmentType.text,
    int? duration,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final message = Message(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: 'user-1',
      receiverId: 'agent-1',
      content: content,
      attachmentType: attachmentType,
      // En mode mock, le chemin local sert directement d'URL — même
      // convention que le reste de l'app (ex: aperçu photo en publication)
      // pour afficher un fichier local sans backend.
      attachmentUrl: attachmentPath,
      duration: duration,
      createdAt: DateTime.now(),
      isRead: false,
    );
    _messages.putIfAbsent(conversationId, () => []).add(message);
    return message;
  }

  @override
  Future<String> getOrCreateConversationId({
    required String agentId,
    String? propertyId,
  }) async {
    // En mode démo, une seule conversation mock existe ('conv-1') ; l'id de
    // l'agent sert directement d'id de conversation pour toute autre entrée.
    return agentId;
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    final messages = _messages[conversationId];
    if (messages == null) return;
    for (var i = 0; i < messages.length; i++) {
      if (!messages[i].isRead) {
        messages[i] = Message.fromJson({...messages[i].toJson(), 'is_read': true});
      }
    }
  }
}
