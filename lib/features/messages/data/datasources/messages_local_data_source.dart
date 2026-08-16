import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/message_model.dart';
import '../../../../core/local/database_provider.dart';

abstract class MessagesLocalDataSource {
  Future<List<MessageModel>> getMessages(String chatId);
  Future<void> replaceMessagesForChat(
    String chatId,
    List<MessageModel> messages,
  );
  Future<void> saveMessages(List<MessageModel> messages);
  Future<void> saveMessage(MessageModel message);
  Future<void> updateMessageStatus(String messageId, MessageStatus status);
  Future<void> deleteMessage(String messageId);
}

class MessagesLocalDataSourceImpl implements MessagesLocalDataSource {
  final DatabaseProvider dbHelper;

  MessagesLocalDataSourceImpl(this.dbHelper);

  @override
  Future<List<MessageModel>> getMessages(String chatId) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return deserializeMessageRow(maps[i]);
    });
  }

  @override
  Future<void> replaceMessagesForChat(
    String chatId,
    List<MessageModel> messages,
  ) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    batch.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
    for (final message in messages.where((item) => item.chatId == chatId)) {
      batch.insert(
        'messages',
        serializeMessage(message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> saveMessages(List<MessageModel> messages) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    for (var message in messages) {
      batch.insert(
        'messages',
        _messageToMap(message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> saveMessage(MessageModel message) async {
    final db = await dbHelper.database;
    await db.insert(
      'messages',
      serializeMessage(message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    final db = await dbHelper.database;
    await db.update(
      'messages',
      {'status': status.index},
      where: 'id = ? OR client_message_id = ?',
      whereArgs: [messageId, messageId],
    );
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    final db = await dbHelper.database;
    await db.delete(
      'messages',
      where: 'id = ? OR client_message_id = ?',
      whereArgs: [messageId, messageId],
    );
  }

  Map<String, dynamic> _messageToMap(MessageModel message) {
    return serializeMessage(message);
  }

  static Map<String, dynamic> serializeMessage(MessageModel message) {
    return {
      'id': message.id,
      'chat_id': message.chatId,
      'author_id': message.authorId,
      'text': message.text,
      'created_at': message.createdAt.toIso8601String(),
      'updated_at': message.updatedAt.toIso8601String(),
      'status': message.status.index,
      'client_message_id': message.clientMessageId,
      'reply_to_message_id': message.replyToMessageId,
      'forwarded_from_message_id': message.forwardedFromMessageId,
      'attached_content': jsonEncode(
        message.attachedContent.map((e) => e.toJson()).toList(),
      ),
    };
  }

  static MessageModel deserializeMessageRow(Map<String, dynamic> row) {
    final item = Map<String, dynamic>.from(row);
    final attachedContentJson = item['attached_content']?.toString();
    List<dynamic> attachments = [];
    if (attachedContentJson != null && attachedContentJson.isNotEmpty) {
      attachments = jsonDecode(attachedContentJson) as List<dynamic>;
    }
    item['attached_content'] = attachments;
    item['body'] = item['body'] ?? item['text'];
    return MessageModel.fromJson(item);
  }
}
