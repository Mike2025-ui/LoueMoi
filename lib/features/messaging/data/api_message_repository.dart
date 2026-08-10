import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/message.dart';
import 'message_repository.dart';

/// Implémentation réelle, branchée sur `/api/conversations/` et
/// `/api/messages/`. Architecture prête pour un flux WebSocket plus tard
/// (il suffira d'ajouter un [Stream] à côté de [fetchMessages], sans changer
/// le contrat [MessageRepository]).
class ApiMessageRepository implements MessageRepository {
  ApiMessageRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<Conversation>> fetchConversations() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.conversations,
      query: {'page_size': 100},
    );
    final results = response.data!['results'] as List;
    return results
        .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Message>> fetchMessages(String conversationId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.messages,
      query: {'conversation': conversationId, 'page_size': 200},
    );
    final results = response.data!['results'] as List;
    return results
        .map((json) => Message.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Message> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.messages,
      data: {'conversation_id': conversationId, 'content': content},
    );
    return Message.fromJson(response.data!);
  }

  @override
  Future<String> getOrCreateConversationId({
    required String agentId,
    String? propertyId,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.conversations,
      data: {
        'agent': agentId,
        if (propertyId != null) 'property': propertyId,
      },
    );
    return response.data!['id'].toString();
  }
}
