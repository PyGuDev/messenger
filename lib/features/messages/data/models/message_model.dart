enum MessageStatus { sending, sent, delivered, read, failed }

class AttachedContentModel {
  final String id;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String accessKey;
  final String typeContent; // image | voice | video | document
  final String? localPath;

  AttachedContentModel({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.accessKey,
    required this.typeContent,
    this.localPath,
  });

  factory AttachedContentModel.fromJson(Map<String, dynamic> json) {
    return AttachedContentModel(
      id: (json['id'] ?? json['ID'])?.toString() ?? '',
      fileName: (json['file_name'] ?? json['FileName'])?.toString() ?? '',
      fileSize: (json['file_size'] ?? json['FileSize']) as int? ?? 0,
      mimeType: (json['mime_type'] ?? json['MimeType'])?.toString() ?? '',
      accessKey: (json['access_key'] ?? json['AccessKey'] ?? '').toString(),
      typeContent:
          (json['type_content'] ?? json['TypeContent'])?.toString() ??
          'document',
      localPath: json['local_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_key': accessKey,
      'type_content': typeContent,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      if (localPath != null) 'local_path': localPath,
    };
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
    final createdAt =
        DateTime.tryParse(
          (json['created_at'] ?? json['CreatedAt'])?.toString() ?? '',
        ) ??
        DateTime.now();
    return MessageModel(
      id: (json['id'] ?? json['ID'])?.toString() ?? '',
      chatId: (json['chat_id'] ?? json['ChatID'])?.toString() ?? '',
      authorId: (json['author_id'] ?? json['AuthorID'])?.toString() ?? '',
      text:
          (json['body'] ?? json['Body'] ?? json['text'] ?? json['Text'])
              ?.toString() ??
          '',
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(
            (json['updated_at'] ?? json['UpdatedAt'])?.toString() ?? '',
          ) ??
          createdAt,
      status: (() {
        final rawStatus = json['status'] ?? json['Status'];
        if (rawStatus is int) {
          if (rawStatus == 3) return MessageStatus.read;
          if (rawStatus == 2) return MessageStatus.delivered;
          if (rawStatus == 1) return MessageStatus.sent;
          return MessageStatus.sending;
        }
        return MessageStatus.sent;
      })(),
      clientMessageId: (json['client_message_id'] ?? json['ClientMessageID'])
          ?.toString(),
      replyToMessageId:
          (json['reply_to_message_id'] ?? json['ReplyToMessageID'])?.toString(),
      forwardedFromMessageId:
          (json['forwarded_from_message_id'] ?? json['ForwardedFromMessageID'])
              ?.toString(),
      attachedContent:
          ((json['attached_content'] ?? json['Attachments']) as List?)
              ?.map(
                (e) => AttachedContentModel.fromJson(e as Map<String, dynamic>),
              )
              .toList()
              .cast<AttachedContentModel>() ??
          const <AttachedContentModel>[],
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
      forwardedFromMessageId:
          forwardedFromMessageId ?? this.forwardedFromMessageId,
      attachedContent: attachedContent ?? this.attachedContent,
    );
  }
}
