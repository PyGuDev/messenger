import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class MemberModel extends Equatable {
  final String userId;
  final String role;
  final DateTime addedAt;

  const MemberModel({
    required this.userId,
    required this.role,
    required this.addedAt,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      userId: (json['user_id'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'member',
      addedAt: DateTime.parse((json['added_at'] as String?) ?? DateTime.now().toIso8601String()),
    );
  }

  @override
  List<Object?> get props => [userId, role, addedAt];
}

class LastMessageModel extends Equatable {
  final String id;
  final String authorId;
  final String body;
  final DateTime createdAt;

  const LastMessageModel({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
  });

  factory LastMessageModel.fromJson(Map<String, dynamic> json) {
    return LastMessageModel(
      id: (json['id'] ?? json['ID'])?.toString() ?? '',
      authorId: (json['author_id'] ?? json['AuthorID'] ?? json['authorId'])?.toString() ?? '',
      body: (json['body'] ?? json['Body'])?.toString() ?? '',
      createdAt: DateTime.tryParse((json['created_at'] ?? json['CreatedAt'] ?? json['createdAt'])?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, authorId, body, createdAt];
}

class ChatModel extends Equatable {
  final String id;
  final int type; // 1 = personal, 2 = group
  final String? title; // null for personal chats
  final List<MemberModel> members;
  final LastMessageModel? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatModel({
    required this.id,
    required this.type,
    this.title,
    required this.members,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      type: json['type'] as int,
      title: json['title'] as String?,
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => MemberModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastMessage: () {
        final lm = json['last_message'] ?? json['LastMessage'] ?? json['lastMessage'];
        if (lm != null) {
          return LastMessageModel.fromJson(lm as Map<String, dynamic>);
        }
        debugPrint('ChatModel fromJson: No last_message found in $json');
        return null;
      }(),
      unreadCount: json['unread_count'] ?? json['UnreadCount'] ?? json['unreadCount'] as int? ?? 0,
      createdAt: DateTime.parse((json['created_at'] ?? json['CreatedAt'] ?? json['createdAt'] as String?) ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse((json['updated_at'] ?? json['UpdatedAt'] ?? json['updatedAt'] as String?) ?? (json['created_at'] ?? json['CreatedAt'] ?? json['createdAt'] as String?) ?? DateTime.now().toIso8601String()),
    );
  }

  ChatModel copyWith({
    String? id,
    int? type,
    String? title,
    List<MemberModel>? members,
    LastMessageModel? lastMessage,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper to get display name
  String get displayName {
    if (type == 2 && title != null) return title!;
    // For personal chats, we might need the other member's name, 
    // but for now we'll just return 'Chat' or similar if title is null
    return title ?? 'Private Chat';
  }

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        members,
        lastMessage,
        unreadCount,
        createdAt,
        updatedAt,
      ];
}

