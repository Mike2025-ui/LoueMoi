import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/messaging/models/message.dart';

Map<String, dynamic> _messageJson({
  String content = '',
  String attachmentType = 'text',
  String? attachmentUrl,
  int? duration,
}) {
  return {
    'id': 1,
    'conversation_id': 5,
    'sender_id': 2,
    'receiver_id': 3,
    'content': content,
    'attachment_type': attachmentType,
    'attachment_url': attachmentUrl,
    'duration': duration,
    'created_at': '2026-01-01T10:00:00Z',
    'is_read': false,
  };
}

void main() {
  group('MessageAttachmentType.fromString', () {
    test('parses each known type', () {
      expect(MessageAttachmentType.fromString('image'), MessageAttachmentType.image);
      expect(MessageAttachmentType.fromString('video'), MessageAttachmentType.video);
      expect(MessageAttachmentType.fromString('audio'), MessageAttachmentType.audio);
      expect(MessageAttachmentType.fromString('text'), MessageAttachmentType.text);
    });

    test('falls back to text for null/unknown values', () {
      expect(MessageAttachmentType.fromString(null), MessageAttachmentType.text);
      expect(MessageAttachmentType.fromString('n_importe_quoi'), MessageAttachmentType.text);
    });
  });

  group('Message.fromJson', () {
    test('parses a plain text message with no attachment', () {
      final message = Message.fromJson(_messageJson(content: 'Bonjour'));
      expect(message.content, 'Bonjour');
      expect(message.attachmentType, MessageAttachmentType.text);
      expect(message.attachmentUrl, isNull);
      expect(message.hasAttachment, isFalse);
    });

    test('parses an image message using the protected attachment_url, never MEDIA_URL', () {
      final message = Message.fromJson(_messageJson(
        attachmentType: 'image',
        attachmentUrl: 'http://api.louemoi.example.com/api/messages/1/attachment/',
      ));
      expect(message.attachmentType, MessageAttachmentType.image);
      expect(message.attachmentUrl, contains('/api/messages/1/attachment/'));
      expect(message.hasAttachment, isTrue);
    });

    test('parses an audio message with a duration', () {
      final message = Message.fromJson(_messageJson(
        attachmentType: 'audio',
        attachmentUrl: 'http://api.louemoi.example.com/api/messages/2/attachment/',
        duration: 14,
      ));
      expect(message.attachmentType, MessageAttachmentType.audio);
      expect(message.duration, 14);
    });

    test('a message without a content key parses cleanly as empty text', () {
      final json = _messageJson()..remove('content');
      final message = Message.fromJson(json);
      expect(message.content, '');
    });
  });

  test('Message.toJson round-trips attachment fields', () {
    final original = Message.fromJson(_messageJson(
      attachmentType: 'video',
      attachmentUrl: 'http://x/api/messages/9/attachment/',
      duration: 30,
    ));
    final roundTripped = Message.fromJson(original.toJson());
    expect(roundTripped, original);
  });
}
