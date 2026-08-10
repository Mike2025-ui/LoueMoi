import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../data/api_message_repository.dart';
import '../data/message_repository.dart';
import '../models/message.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  if (Env.useMockData) return MockMessageRepository();
  return ApiMessageRepository(ref.watch(apiClientProvider));
});

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final repository = ref.watch(messageRepositoryProvider);
  return repository.fetchConversations();
});

final messagesProvider =
    FutureProvider.family<List<Message>, String>((ref, conversationId) async {
  final repository = ref.watch(messageRepositoryProvider);
  return repository.fetchMessages(conversationId);
});

Future<void> sendMessage(WidgetRef ref, {required String conversationId, required String content}) async {
  final repository = ref.read(messageRepositoryProvider);
  await repository.sendMessage(conversationId: conversationId, content: content);
  ref.invalidate(messagesProvider(conversationId));
  ref.invalidate(conversationsProvider);
}
