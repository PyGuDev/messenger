enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class AttachedContentModel {
  final String id;
  final String fileId;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String typeContent; // image | voice | video | document

  AttachedContentModel({
    required this.id,
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.typeContent,
  });

  factory AttachedContentModel.fromJson(Map<String, dynamic> json) {
    return AttachedContentModel(
      id: (json['id'] as String?) ?? '',
      fileId: (json['file_id'] as String?) ?? '',
      fileName: (json['file_name'] as String?) ?? '',
      fileSize: (json['file_size'] as int?) ?? 0,
      mimeType: (json['mime_type'] as String?) ?? '',
      typeContent: (json['type_content'] as String?) ?? 'document',
    );
  }
}

class MessageModel {
  final String id;
  final String chatId;
  final String authorId;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MessageStatus status;
  final String? clientMessageId;
  final String? replyToMessageId;
  final String? forwardedFromMessageId;
  final List<AttachedContentModel> attachedContent;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.authorId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.status = MessageStatus.sent,
    this.clientMessageId,
    this.replyToMessageId,
    this.forwardedFromMessageId,
    this.attachedContent = const [],
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: (json['id'] ?? json['ID'])?.toString() ?? '',
      chatId: (json['chat_id'] ?? json['ChatID'])?.toString() ?? '',
      authorId: (json['author_id'] ?? json['AuthorID'] ?? json['sender_id'] ?? '').toString(),
      text: (json['body'] ?? json['Body'])?.toString() ?? '',
      createdAt: DateTime.tryParse((json['created_at'] ?? json['CreatedAt'])?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? json['UpdatedAt'] ?? json['created_at'] ?? json['CreatedAt'])?.toString() ?? '') ?? DateTime.now(),
      // determine status from JSON fields
      status: (() {
        // 1. Explicit read status flags
        final isRead = json['is_read'] == true || 
                       json['IsRead'] == true || 
                       json['read_at'] != null || 
                       json['ReadAt'] != null ||
                       json['read'] == true ||
                       json['seen'] == true ||
                       (json['is_read'] is int && (json['is_read'] as int) > 0) ||
                       (json['read'] is int && (json['read'] as int) > 0);
        if (isRead) return MessageStatus.read;

        // 2. Status as int (common mapping: 1=sent, 2=delivered, 3=read)
        final rawStatus = json['status'] ?? json['Status'];
        if (rawStatus is int) {
          if (rawStatus == 3) return MessageStatus.read;
          if (rawStatus == 2) return MessageStatus.delivered;
          if (rawStatus == 1) return MessageStatus.sent;
          if (rawStatus == 0) return MessageStatus.sending;
          if (rawStatus == 4) return MessageStatus.failed;
          // fallback to index-based if it matches enum
          if (rawStatus >= 0 && rawStatus < MessageStatus.values.length) {
            return MessageStatus.values[rawStatus];
          }
        }

        // 3. Status as string
        if (rawStatus is String) {
          final normalized = rawStatus.toLowerCase();
          if (normalized == 'read' || normalized == 'seen') return MessageStatus.read;
          if (normalized == 'delivered') return MessageStatus.delivered;
          if (normalized == 'sent') return MessageStatus.sent;
          if (normalized == 'sending') return MessageStatus.sending;
          if (normalized == 'failed') return MessageStatus.failed;
          
          return MessageStatus.values.firstWhere(
            (e) => e.name.toLowerCase() == normalized, 
            orElse: () => MessageStatus.sent
          );
        }

        return MessageStatus.sent;
      })(), 
      clientMessageId: (json['client_message_id'] ?? json['ClientMessageID'])?.toString(),
      replyToMessageId: (json['reply_to_message_id'] ?? json['ReplyToMessageID'])?.toString(),
      forwardedFromMessageId: (json['forwarded_from_message_id'] ?? json['ForwardedFromMessageID'])?.toString(),
      attachedContent: ((json['attached_content'] ?? json['Attachments']) as List<dynamic>?)
              ?.map((e) => AttachedContentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? authorId,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
    MessageStatus? status,
    String? clientMessageId,
    String? replyToMessageId,
    String? forwardedFromMessageId,
    List<AttachedContentModel>? attachedContent,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      authorId: authorId ?? this.authorId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      forwardedFromMessageId: forwardedFromMessageId ?? this.forwardedFromMessageId,
      attachedContent: attachedContent ?? this.attachedContent,
    );
  }
}

