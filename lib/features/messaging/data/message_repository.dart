import '../models/message.dart';

/// Contrat de messagerie. Architecture prête pour un flux WebSocket
/// (méthode [watchMessages] pourra être remplacée par un stream temps réel).
abstract class MessageRepository {
  Future<List<Conversation>> fetchConversations();
  Future<List<Message>> fetchMessages(String conversationId);
  Future<Message> sendMessage({required String conversationId, required String content});

  /// Récupère (ou crée) la conversation avec cet agent, à propos d'une
  /// propriété donnée, et retourne son id — à appeler avant de naviguer vers
  /// l'écran de conversation depuis "Contacter l'agent".
  Future<String> getOrCreateConversationId({required String agentId, String? propertyId});
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
    required String content,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final message = Message(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: 'user-1',
      receiverId: 'agent-1',
      content: content,
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
}
