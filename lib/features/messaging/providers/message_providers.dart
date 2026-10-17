import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/api_message_repository.dart';
import '../data/message_repository.dart';
import '../models/message.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  if (Env.useMockData) return MockMessageRepository();
  return ApiMessageRepository(ref.watch(apiClientProvider));
});

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null && !Env.useMockData) return const [];
  final repository = ref.watch(messageRepositoryProvider);
  return repository.fetchConversations();
});

/// Badge de l'onglet "Conversations" de la barre de navigation — somme des
/// messages non lus toutes conversations confondues, jamais recalculée
/// autrement que via ce que Django renvoie déjà par conversation
/// (unread_count).
final totalUnreadConversationsCountProvider = Provider.autoDispose<int>((ref) {
  final conversations = ref.watch(conversationsProvider).valueOrNull ?? const [];
  return conversations.fold(0, (sum, c) => sum + c.unreadCount);
});

final messagesProvider =
    FutureProvider.family<List<Message>, String>((ref, conversationId) async {
  final repository = ref.watch(messageRepositoryProvider);
  return repository.fetchMessages(conversationId);
});

/// À appeler à l'ouverture d'une conversation : marque ses messages comme
/// lus côté serveur puis invalide [conversationsProvider], seule source du
/// badge non-lu de l'onglet Messages (voir totalUnreadConversationsCountProvider).
Future<void> markConversationRead(WidgetRef ref, String conversationId) async {
  final repository = ref.read(messageRepositoryProvider);
  await repository.markConversationRead(conversationId);
  ref.invalidate(conversationsProvider);
}

Future<void> sendMessage(
  WidgetRef ref, {
  required String conversationId,
  String content = '',
  String? attachmentPath,
  MessageAttachmentType attachmentType = MessageAttachmentType.text,
  int? duration,
}) async {
  final repository = ref.read(messageRepositoryProvider);
  await repository.sendMessage(
    conversationId: conversationId,
    content: content,
    attachmentPath: attachmentPath,
    attachmentType: attachmentType,
    duration: duration,
  );
  ref.invalidate(messagesProvider(conversationId));
  ref.invalidate(conversationsProvider);
}
