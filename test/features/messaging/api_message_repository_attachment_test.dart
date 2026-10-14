import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/network/api_client.dart';
import 'package:louemoi/features/messaging/data/api_message_repository.dart';
import 'package:louemoi/features/messaging/models/message.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<Map<String, dynamic>> _fakeResponse(Map<String, dynamic> data) {
  return Response(data: data, requestOptions: RequestOptions(path: '/'));
}

Map<String, dynamic> _messageJson({String attachmentType = 'text', String? attachmentUrl}) {
  return {
    'id': 1,
    'conversation_id': 5,
    'sender_id': 2,
    'receiver_id': 3,
    'content': '',
    'attachment_type': attachmentType,
    'attachment_url': attachmentUrl,
    'duration': null,
    'created_at': '2026-01-01T10:00:00Z',
    'is_read': false,
  };
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(FormData());
  });

  late MockApiClient apiClient;
  late ApiMessageRepository repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = ApiMessageRepository(apiClient);
  });

  test('sendMessage without an attachment posts plain JSON', () async {
    when(() => apiClient.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _fakeResponse(_messageJson()));

    await repository.sendMessage(conversationId: '5', content: 'Bonjour');

    final call = verify(
      () => apiClient.post<Map<String, dynamic>>(captureAny(), data: captureAny(named: 'data')),
    ).captured;
    expect(call[1], {'conversation_id': '5', 'content': 'Bonjour'});
  });

  test('sendMessage with an attachment uploads multipart FormData', () async {
    final tempFile = File('${Directory.systemTemp.path}/louemoi_test_msg_photo.jpg');
    await tempFile.writeAsBytes([0, 1, 2, 3]);
    addTearDown(() => tempFile.delete());

    when(() => apiClient.post<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => _fakeResponse(_messageJson(
        attachmentType: 'image',
        attachmentUrl: 'http://x/api/messages/1/attachment/',
      )),
    );

    final message = await repository.sendMessage(
      conversationId: '5',
      attachmentPath: tempFile.path,
      attachmentType: MessageAttachmentType.image,
    );

    expect(message.attachmentType, MessageAttachmentType.image);
    expect(message.attachmentUrl, isNotNull);
    final call = verify(
      () => apiClient.post<Map<String, dynamic>>(captureAny(), data: captureAny(named: 'data')),
    ).captured;
    expect(call[1], isA<FormData>());
  });

  test('sendMessage includes duration for an audio attachment', () async {
    final tempFile = File('${Directory.systemTemp.path}/louemoi_test_msg_voice.m4a');
    await tempFile.writeAsBytes([0, 1, 2, 3]);
    addTearDown(() => tempFile.delete());

    when(() => apiClient.post<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => _fakeResponse(_messageJson(
        attachmentType: 'audio',
        attachmentUrl: 'http://x/api/messages/2/attachment/',
      )),
    );

    await repository.sendMessage(
      conversationId: '5',
      attachmentPath: tempFile.path,
      attachmentType: MessageAttachmentType.audio,
      duration: 12,
    );

    final call = verify(
      () => apiClient.post<Map<String, dynamic>>(captureAny(), data: captureAny(named: 'data')),
    ).captured;
    final formData = call[1] as FormData;
    final durationField = formData.fields.firstWhere((f) => f.key == 'duration');
    expect(durationField.value, '12');
  });
}
