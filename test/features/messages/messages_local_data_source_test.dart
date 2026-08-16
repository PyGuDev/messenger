import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/features/messages/data/datasources/messages_local_data_source.dart';
import 'package:messenger/features/messages/data/models/message_model.dart';

void main() {
  test('deserializes text and attachments from the local cache shape', () {
    final serializedRow = {
      'id': 'message-1',
      'chat_id': 'chat-1',
      'author_id': 'user-1',
      'text': 'cached body',
      'created_at': '2026-04-22T10:00:00.000Z',
      'updated_at': '2026-04-22T10:00:00.000Z',
      'status': 1,
      'attached_content':
          '[{"access_key":"file-key","type_content":"image","file_name":"image.png","file_size":10,"mime_type":"image/png","local_path":"/tmp/image.png"}]',
    };

    final message = MessagesLocalDataSourceImpl.deserializeMessageRow(
      serializedRow,
    );

    expect(message.text, 'cached body');
    expect(message.attachedContent.single.localPath, '/tmp/image.png');
  });

  test('serializes the canonical cache shape for local persistence', () {
    final message = MessageModel(
      id: 'message-1',
      chatId: 'chat-1',
      authorId: 'user-1',
      text: 'cached body',
      createdAt: DateTime.parse('2026-04-22T10:00:00Z'),
      updatedAt: DateTime.parse('2026-04-22T10:00:00Z'),
      attachedContent: [
        AttachedContentModel(
          id: 'attachment-1',
          fileName: 'image.png',
          fileSize: 10,
          mimeType: 'image/png',
          accessKey: 'file-key',
          typeContent: 'image',
          localPath: '/tmp/image.png',
        ),
      ],
    );

    final serialized = MessagesLocalDataSourceImpl.serializeMessage(message);

    expect(serialized['text'], 'cached body');
    expect(serialized['chat_id'], 'chat-1');
    expect(serialized['attached_content'], contains('image.png'));
  });
}
