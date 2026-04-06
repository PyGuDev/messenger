import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/chat_model.dart';
import '../../../../core/local/database_helper.dart';

abstract class ChatsLocalDataSource {
  Future<List<ChatModel>> getChats();
  Future<void> saveChats(List<ChatModel> chats);
  Future<void> saveChat(ChatModel chat);
  Future<void> deleteChat(String chatId);
  Future<void> clearAll();
}

class ChatsLocalDataSourceImpl implements ChatsLocalDataSource {
  final DatabaseHelper dbHelper;

  ChatsLocalDataSourceImpl(this.dbHelper);

  @override
  Future<List<ChatModel>> getChats() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chats',
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) {
      final Map<String, dynamic> item = Map<String, dynamic>.from(maps[i]);

      final String? membersJson = item['members'];
      if (membersJson != null && membersJson.isNotEmpty) {
        item['members'] = jsonDecode(membersJson);
      } else {
        item['members'] = [];
      }

      final String? lastMessageJson = item['last_message'];
      if (lastMessageJson != null && lastMessageJson.isNotEmpty) {
        item['last_message'] = jsonDecode(lastMessageJson);
      }

      return ChatModel.fromJson(item);
    });
  }

  @override
  Future<void> saveChats(List<ChatModel> chats) async {
    if (chats.isEmpty) return;
    
    final db = await dbHelper.database;
    final batch = db.batch();
    for (var chat in chats) {
      batch.insert(
        'chats',
        _chatToMap(chat),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> saveChat(ChatModel chat) async {
    final db = await dbHelper.database;
    await db.insert(
      'chats',
      _chatToMap(chat),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteChat(String chatId) async {
    final db = await dbHelper.database;
    await db.delete(
      'chats',
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }

  @override
  Future<void> clearAll() async {
    final db = await dbHelper.database;
    await db.delete('chats');
  }

  Map<String, dynamic> _chatToMap(ChatModel chat) {
    return {
      'id': chat.id,
      'type': chat.type,
      'title': chat.title,
      'members': jsonEncode(
        chat.members.map((e) => {
          'user_id': e.userId,
          'role': e.role,
          'added_at': e.addedAt.toIso8601String(),
        }).toList(),
      ),
      'last_message': chat.lastMessage != null
          ? jsonEncode({
              'id': chat.lastMessage!.id,
              'author_id': chat.lastMessage!.authorId,
              'body': chat.lastMessage!.body,
              'created_at': chat.lastMessage!.createdAt.toIso8601String(),
            })
          : null,
      'unread_count': chat.unreadCount,
      'created_at': chat.createdAt.toIso8601String(),
      'updated_at': chat.updatedAt.toIso8601String(),
    };
  }
}
