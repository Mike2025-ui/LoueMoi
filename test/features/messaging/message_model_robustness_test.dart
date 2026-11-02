import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/messaging/models/message.dart';

void main() {
  group('Message and Conversation Robustness Tests', () {
    test('Message.fromJson handles null IDs, double duration, and integer booleans', () {
      final json = <String, dynamic>{
        'id': 1,
        'conversation_id': 2,
        'sender_id': 3,
        'receiver_id': 4,
        'content': 'Bonjour !',
        'attachment_type': 'audio',
        'attachment_url': '/media/audio.m4a',
        'duration': 14.8,
        'is_delivered': 1,
        'is_read': 0,
      };

      final message = Message.fromJson(json);
      expect(message.id, equals('1'));
      expect(message.conversationId, equals('2'));
      expect(message.senderId, equals('3'));
      expect(message.receiverId, equals('4'));
      expect(message.content, equals('Bonjour !'));
      expect(message.duration, equals(14));
      expect(message.isDelivered, isTrue);
      expect(message.isRead, isFalse);
    });

    test('Conversation.fromJson handles null participantName and double unreadCount', () {
      final json = <String, dynamic>{
        'id': 99,
        'participant_name': null,
        'participant_is_online': 1,
        'unread_count': 3.0,
        'can_access': 1,
      };

      final conv = Conversation.fromJson(json);
      expect(conv.id, equals('99'));
      expect(conv.participantName, equals('Contact'));
      expect(conv.participantIsOnline, isTrue);
      expect(conv.unreadCount, equals(3));
      expect(conv.canAccess, isTrue);
    });
  });
}

