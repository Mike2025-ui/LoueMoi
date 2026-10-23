import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
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
    String content = '',
    String? attachmentPath,
    MessageAttachmentType attachmentType = MessageAttachmentType.text,
    int? duration,
  }) async {
    if (attachmentPath == null) {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.messages,
        data: {'conversation_id': conversationId, 'content': content},
      );
      return Message.fromJson(response.data!);
    }

    final xfile = XFile(attachmentPath);
    final bytes = await xfile.readAsBytes();
    var filename = xfile.name;
    if (!filename.contains('.')) {
      filename = switch (attachmentType) {
        MessageAttachmentType.image => 'photo.jpg',
        MessageAttachmentType.video => 'video.mp4',
        MessageAttachmentType.audio => 'voice.m4a',
        MessageAttachmentType.text => 'file.txt',
      };
    }

    final fields = <String, dynamic>{
      'conversation_id': conversationId,
      'content': content,
      'attachment_type': attachmentType.toJson(),
      'attachment': MultipartFile.fromBytes(bytes, filename: filename),
    };
    if (duration != null) fields['duration'] = duration;
    final formData = FormData.fromMap(fields);
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.messages,
      data: formData,
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
      data: {'agent': agentId, 'property': ?propertyId},
    );
    return response.data!['id'].toString();
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.conversationMarkRead(conversationId),
    );
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _apiClient.delete<void>(
      '${ApiEndpoints.conversations}$conversationId/',
    );
  }
}
