import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:messenger/features/messages/presentation/widgets/persistent_emoji_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/network/file_service.dart';
import '../../../../core/security/token_storage.dart';
import '../../../../core/cache/media_cache_service.dart';
import '../widgets/image_fullscreen_viewer.dart';
import 'package:intl/intl.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_event.dart';
import 'package:messenger/features/messages/presentation/bloc/messages_state.dart';
import 'package:messenger/features/messages/presentation/widgets/voice_recorder_widget.dart';
import 'package:messenger/features/messages/presentation/widgets/voice_message_bubble.dart';
import 'package:messenger/features/messages/presentation/widgets/video_recording_overlay.dart';
import 'package:messenger/features/messages/presentation/widgets/video_message_bubble.dart';
import '../../../../core/network/camera_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/models/message_model.dart';

import 'package:messenger/shared/widgets/error_display.dart';

enum RecordingMode { voice, video }

class MessagesScreen extends StatefulWidget {
  final String chatId;
  final String title;
  final bool isGroup;

  const MessagesScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.isGroup = false,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSendButtonActive = false;
  bool _emojiVisible = false;
  bool _isRecording = false;
  bool _isRecordingVideo = false;
  RecordingMode _recordingMode = RecordingMode.voice;
  final CameraService _cameraService = sl<CameraService>();
  MessageModel? _replyingToMessage;
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  Timer? _recordTimer;
  bool _recordTimerFired = false;
  bool _isVideoRecordingCanceled = false;

  DateTime? _lastReadSent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<MessagesBloc>().add(LoadMessages(widget.chatId));

    _textController.addListener(() {
      final isNotEmpty = _textController.text.trim().isNotEmpty;
      if (isNotEmpty != _isSendButtonActive) {
        setState(() {
          _isSendButtonActive = isNotEmpty;
        });
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<MessagesBloc>().add(LoadMoreMessages(widget.chatId));
      }
      if (_scrollController.position.pixels <= 50) {
        _markAsReadIfAtBottom();
      }
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markAsReadIfAtBottom();
    }
  }

  void _markAsReadIfAtBottom() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels <= 50) {
      final now = DateTime.now();
      if (_lastReadSent == null ||
          now.difference(_lastReadSent!).inSeconds > 2) {
        _lastReadSent = now;
        context.read<MessagesBloc>().add(
          MarkMessagesAsRead(chatId: widget.chatId, upTo: now),
        );
      }
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      context.read<MessagesBloc>().add(
        SendMessage(
          chatId: widget.chatId,
          text: text,
          replyToMessageId: _replyingToMessage?.id,
        ),
      );
      _textController.clear();
      setState(() {
        _replyingToMessage = null;
      });
      _scrollToBottom();
    }
  }

  void _initiateReply(MessageModel message) {
    setState(() {
      _replyingToMessage = message;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
      _highlightMessage(messageId);
    } else {
      final blocState = context.read<MessagesBloc>().state;
      if (blocState is MessagesLoaded) {
        final index = blocState.messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          // Estimate offset based on average item height
          final estimatedOffset = index * 80.0;
          final maxExtent = _scrollController.position.maxScrollExtent;
          final target = estimatedOffset > maxExtent
              ? maxExtent
              : estimatedOffset;

          _scrollController
              .animateTo(
                target,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              )
              .then((_) {
                // After rough scroll, the item might be built. Try ensuring visibility exactly.
                Future.delayed(const Duration(milliseconds: 50), () {
                  final newKey = _messageKeys[messageId];
                  if (newKey != null && newKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      newKey.currentContext!,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: 0.5,
                    );
                  }
                  _highlightMessage(messageId);
                });
              });
        }
      }
    }
  }

  void _highlightMessage(String messageId) {
    setState(() {
      _highlightedMessageId = messageId;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  Future<void> _startVideoRecording() async {
    _isVideoRecordingCanceled = false;
    setState(() {
      _isRecordingVideo = true;
    });
    try {
      await _cameraService.initialize();
      if (_isVideoRecordingCanceled) {
        _cameraService.dispose();
        return;
      }
      await _cameraService.startRecording();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecordingVideo = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _stopVideoRecording(bool send) async {
    _isVideoRecordingCanceled = true;
    final file = await _cameraService.stopRecording();
    setState(() {
      _isRecordingVideo = false;
    });
    if (send && file != null) {
      // ignore: use_build_context_synchronously
      context.read<MessagesBloc>().add(
        SendVideoMessage(
          chatId: widget.chatId,
          filePath: file.path,
          duration: const Duration(seconds: 0),
          replyToMessageId: _replyingToMessage?.id,
        ),
      );
      setState(() {
        _replyingToMessage = null;
      });
    }
    _cameraService.dispose();
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppColors.bgPrimary,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: AppColors.accentBlue),
                title: const Text(
                  'Image',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                  );
                  _handleFilePickerResult(result, 'image');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.insert_drive_file,
                  color: AppColors.accentBlue,
                ),
                title: const Text(
                  'Document',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.any,
                  );
                  _handleFilePickerResult(result, 'document');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleFilePickerResult(FilePickerResult? result, String typeContent) {
    if (result != null && result.files.single.path != null) {
      context.read<MessagesBloc>().add(
        SendFileMessage(
          chatId: widget.chatId,
          filePath: result.files.single.path!,
          fileName: result.files.single.name,
          typeContent: typeContent,
          replyToMessageId: _replyingToMessage?.id,
        ),
      );
      setState(() {
        _replyingToMessage = null;
      });
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat.Hm().format(time); // HH:mm
  }

  Widget _buildMessageStatus(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(
          Icons.access_time,
          size: 12,
          color: AppColors.textOnAccent,
        );
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: AppColors.textOnAccent);
      case MessageStatus.delivered:
        return const Icon(
          Icons.done_all,
          size: 12,
          color: AppColors.textOnAccent,
        );
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: Colors.blueAccent);
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 12,
          color: Colors.redAccent,
        );
    }
  }

  Widget _buildMessageStatusOnImage(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 12, color: Colors.white);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.white);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Colors.white);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: Colors.blueAccent);
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 12,
          color: Colors.redAccent,
        );
    }
  }

  Widget _buildMessageBubble(
    MessageModel message,
    String currentUserId,
    Map<String, String> userNames,
    MessageModel? repliedMessage,
    GlobalKey? key,
  ) {
    final isMine =
        message.authorId.trim() == currentUserId.trim() &&
        currentUserId.isNotEmpty;

    if (foundation.kDebugMode) {
      foundation.debugPrint(
        'Message ID: ${message.id}, Author: ${message.authorId}, CurrentUser: $currentUserId, isMine: $isMine',
      );
    }

    final authorName = userNames[message.authorId] ?? 'User';

    final hasVideo = message.attachedContent.any(
      (c) => c.typeContent == 'video',
    );
    final hasImage = message.attachedContent.any(
      (c) => c.typeContent == 'image',
    );
    final hasText = message.text.isNotEmpty;
    final hasReplied = repliedMessage != null;
    final hasAuthorName = !isMine && widget.isGroup;

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight: isMine
          ? const Radius.circular(4)
          : const Radius.circular(16),
    );

    final bubble = Align(
      key: key,
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: (hasVideo || hasImage)
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: _highlightedMessageId == message.id
              ? AppColors.bgHighlight
              : ((hasVideo || hasImage)
                    ? Colors.transparent
                    : (isMine
                          ? AppColors.bgMessageOut
                          : AppColors.bgMessageIn)),
          borderRadius: bubbleRadius,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine && widget.isGroup) ...[
              Padding(
                padding: hasImage
                    ? const EdgeInsets.fromLTRB(14, 10, 14, 0)
                    : EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
            if (repliedMessage != null) ...[
              Padding(
                padding: hasImage
                    ? const EdgeInsets.fromLTRB(14, 10, 14, 0)
                    : EdgeInsets.zero,
                child: GestureDetector(
                  onTap: () => _scrollToMessage(repliedMessage.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isMine
                          ? const Color(
                              0xFF6B58FF,
                            ) // Slightly lighter purple for replied box inside purple bubble
                          : const Color(
                              0xFFE4E4E5,
                            ), // Slightly darker gray for replied box inside gray bubble
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: isMine
                                  ? AppColors.accentBlueLight
                                  : AppColors.accentBlue,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  userNames[repliedMessage.authorId] ?? 'User',
                                  style: TextStyle(
                                    color: isMine
                                        ? AppColors.accentBlueLight
                                        : AppColors.accentBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  repliedMessage.text,
                                  style: TextStyle(
                                    color: isMine
                                        ? AppColors.textOnAccent
                                        : AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (message.attachedContent.any(
              (c) => c.typeContent == 'voice',
            )) ...[
              VoiceMessageBubble(
                accessKey: message.attachedContent
                    .firstWhere((c) => c.typeContent == 'voice')
                    .accessKey,
                localPath: message.attachedContent
                    .firstWhere((c) => c.typeContent == 'voice')
                    .localPath,
                isMe: isMine,
              ),
            ] else if (message.attachedContent.any(
              (c) => c.typeContent == 'video',
            )) ...[
              VideoMessageBubble(
                accessKey: message.attachedContent
                    .firstWhere((c) => c.typeContent == 'video')
                    .accessKey,
                localPath: message.attachedContent
                    .firstWhere((c) => c.typeContent == 'video')
                    .localPath,
                isMe: isMine,
              ),
            ] else if (message.attachedContent.any(
              (c) => c.typeContent == 'image',
            )) ...[
              Builder(
                builder: (context) {
                  final content = message.attachedContent.firstWhere(
                    (c) => c.typeContent == 'image',
                  );
                  final hasLocalPath =
                      content.localPath != null &&
                      content.localPath!.isNotEmpty;
                  final fileUrl = content.accessKey.isNotEmpty
                      ? sl<FileService>().getDownloadUrl(content.accessKey)
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius:
                                (hasText || hasReplied || hasAuthorName)
                                ? const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  )
                                : bubbleRadius,
                            child: FutureBuilder<String?>(
                              future: sl<TokenStorage>().getAccessToken(),
                              builder: (context, snapshot) {
                                final headers = snapshot.data != null
                                    ? {
                                        'Authorization':
                                            'Bearer ${snapshot.data}',
                                      }
                                    : <String, String>{};

                                Widget imageWidget;
                                if (hasLocalPath) {
                                  imageWidget = Image.file(
                                    File(content.localPath!),
                                    width: double.infinity,
                                    height: 250,
                                    fit: BoxFit.cover,
                                  );
                                } else if (fileUrl != null) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    imageWidget = Container(
                                      width: double.infinity,
                                      height: 250,
                                      color: Colors.grey[800],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  } else {
                                    imageWidget = CachedNetworkImage(
                                      imageUrl: fileUrl,
                                      httpHeaders: headers,
                                      width: double.infinity,
                                      height: 250,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: double.infinity,
                                        height: 250,
                                        color: Colors.grey[800],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            width: double.infinity,
                                            height: 250,
                                            color: Colors.grey[800],
                                            child: const Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                    );
                                  }
                                } else {
                                  imageWidget = Container(
                                    width: double.infinity,
                                    height: 250,
                                    color: Colors.grey[800],
                                    child: const Center(
                                      child: Icon(
                                        Icons.image,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      PageRouteBuilder(
                                        opaque: false,
                                        pageBuilder: (context, animation, _) =>
                                            ImageFullscreenViewer(
                                              localFile: hasLocalPath
                                                  ? File(content.localPath!)
                                                  : null,
                                              imageUrl: hasLocalPath
                                                  ? null
                                                  : fileUrl,
                                              headers: headers,
                                            ),
                                        transitionsBuilder:
                                            (context, animation, _, child) =>
                                                FadeTransition(
                                                  opacity: animation,
                                                  child: child,
                                                ),
                                      ),
                                    );
                                  },
                                  child: imageWidget,
                                );
                              },
                            ),
                          ),
                          if (!hasText)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTime(message.createdAt),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (isMine) ...[
                                      const SizedBox(width: 4),
                                      _buildMessageStatusOnImage(
                                        message.status,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (message.text.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                          child: Text(
                            message.text,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ] else if (message.attachedContent.any(
              (c) => c.typeContent == 'document',
            )) ...[
              _DocumentBubble(
                content: message.attachedContent.firstWhere(
                  (c) => c.typeContent == 'document',
                ),
                isMine: isMine,
              ),
              if (message.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message.text,
                  style: TextStyle(
                    color: isMine
                        ? AppColors.textOnAccent
                        : AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ],
            ] else
              Text(
                message.text,
                style: TextStyle(
                  color: isMine
                      ? AppColors.textOnAccent
                      : AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            const SizedBox(height: 4),
            if (hasImage && !hasText)
              const SizedBox.shrink()
            else
              Padding(
                padding: hasImage
                    ? const EdgeInsets.fromLTRB(14, 0, 14, 10)
                    : EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color: (hasImage && !hasText)
                            ? Colors.white
                            : (isMine
                                  ? (hasImage
                                        ? AppColors.textPrimary
                                        : AppColors.textOnAccent)
                                  : AppColors.textSecondary),
                        fontSize: 10,
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      if (message.status == MessageStatus.failed)
                        GestureDetector(
                          onTap: () {
                            context.read<MessagesBloc>().add(
                              ResendMessage(
                                chatId: widget.chatId,
                                clientMessageId: message.clientMessageId ?? '',
                              ),
                            );
                          },
                          child: const Row(
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 12,
                                color: Colors.redAccent,
                              ),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _buildMessageStatus(message.status),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: Key('msg_${message.clientMessageId ?? message.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.1},
      confirmDismiss: (direction) async {
        _initiateReply(message);
        return false;
      },
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.reply, color: AppColors.textTertiary),
      ),
      background: Container(),
      child: bubble,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: 48,
        leading: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back, color: AppColors.accentBlue),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(
                      color: AppColors.successGreen,
                      fontFamily: 'Inter',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.phone,
              color: AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderDefault, height: 1),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: BlocConsumer<MessagesBloc, MessagesState>(
                  listener: (context, state) {
                    if (state is MessagesLoaded) {
                      if (_lastReadSent == null) {
                        _lastReadSent = DateTime.now();
                        context.read<MessagesBloc>().add(
                          MarkMessagesAsRead(
                            chatId: widget.chatId,
                            upTo: _lastReadSent!,
                          ),
                        );
                      } else {
                        _markAsReadIfAtBottom();
                      }
                    }
                  },
                  builder: (context, state) {
                    if (state is MessagesLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is MessagesOfflineUnavailable) {
                      return ErrorDisplay(
                        message:
                            'История чата недоступна без подключения к сети',
                        onRetry: () => context.read<MessagesBloc>().add(
                          LoadMessages(widget.chatId),
                        ),
                      );
                    } else if (state is MessagesLoaded) {
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            state.messages.length +
                            (state.hasReachedMax ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (index >= state.messages.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final message = state.messages[index];
                          final repliedMessage =
                              message.replyToMessageId != null
                              ? state.messages.cast<MessageModel?>().firstWhere(
                                  (m) => m?.id == message.replyToMessageId,
                                  orElse: () => null,
                                )
                              : null;
                          final key = _messageKeys.putIfAbsent(
                            message.id,
                            () => GlobalKey(),
                          );
                          return _buildMessageBubble(
                            message,
                            state.currentUserId,
                            state.userNames,
                            repliedMessage,
                            key,
                          );
                        },
                      );
                    } else if (state is MessagesError) {
                      return ErrorDisplay(
                        message: state.message,
                        onRetry: () => context.read<MessagesBloc>().add(
                          LoadMessages(widget.chatId),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              _buildMessageInput(),
              PersistentEmojiPicker(
                textEditingController: _textController,
                isVisible: _emojiVisible,
                onEmojiSelected: () {
                  setState(() {
                    _isSendButtonActive = _textController.text
                        .trim()
                        .isNotEmpty;
                  });
                },
              ),
            ],
          ),
          if (_isRecordingVideo)
            Positioned.fill(
              child: VideoRecordingOverlay(
                onCancel: () => _stopVideoRecording(false),
                onSend: () => _stopVideoRecording(true),
                onSwitchCamera: () async {
                  if (_cameraService.isSwitching) return;
                  setState(() {}); // Show loading
                  await _cameraService.switchCamera();
                  if (mounted) setState(() {}); // Show new preview
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    if (_isRecording) {
      return VoiceRecorderWidget(
        onSend: (path, duration) {
          context.read<MessagesBloc>().add(
            SendVoiceMessage(
              chatId: widget.chatId,
              filePath: path,
              duration: duration,
              replyToMessageId: _replyingToMessage?.id,
            ),
          );
          setState(() {
            _isRecording = false;
            _replyingToMessage = null;
          });
        },
        onCancel: () {
          setState(() => _isRecording = false);
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingToMessage != null) _buildReplyPreview(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.bgPrimary,
            border: Border(top: BorderSide(color: AppColors.borderDefault)),
          ),
          child: SafeArea(
            bottom: !_emojiVisible,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: _showAttachmentOptions,
                    child: const Icon(
                      Icons.attach_file,
                      color: AppColors.textTertiary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 44,
                      maxHeight: 150,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _emojiVisible = !_emojiVisible;
                              });
                              if (_emojiVisible) {
                                FocusScope.of(context).unfocus();
                              }
                            },
                            child: Icon(
                              _emojiVisible
                                  ? Icons.keyboard
                                  : Icons.sentiment_satisfied_alt,
                              color: _emojiVisible
                                  ? AppColors.accentBlue
                                  : AppColors.textTertiary,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            onSubmitted: (_) => _sendMessage(),
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              hintText: 'Message...',
                              hintStyle: TextStyle(
                                color: AppColors.textTertiary,
                                fontFamily: 'Inter',
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontFamily: 'Inter',
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTapDown: _isSendButtonActive
                      ? null
                      : (_) {
                          _recordTimerFired = false;
                          _recordTimer?.cancel();
                          _recordTimer = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              _recordTimerFired = true;
                              if (_recordingMode == RecordingMode.voice) {
                                setState(() => _isRecording = true);
                              } else {
                                _startVideoRecording();
                              }
                            },
                          );
                        },
                  onTapUp: _isSendButtonActive
                      ? null
                      : (_) {
                          _recordTimer?.cancel();
                          if (!_recordTimerFired) {
                            setState(() {
                              _recordingMode =
                                  _recordingMode == RecordingMode.voice
                                  ? RecordingMode.video
                                  : RecordingMode.voice;
                            });
                          }
                        },
                  onTapCancel: _isSendButtonActive
                      ? null
                      : () {
                          _recordTimer?.cancel();
                        },
                  onTap: _isSendButtonActive ? _sendMessage : null,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isSendButtonActive
                          ? AppColors.accentBlue
                          : AppColors.borderDefault,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _isSendButtonActive
                            ? Icons.send
                            : (_recordingMode == RecordingMode.voice
                                  ? Icons.mic
                                  : Icons.videocam),
                        color: _isSendButtonActive
                            ? Colors.white
                            : AppColors.textTertiary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    final blocState = context.read<MessagesBloc>().state;
    String authorName = 'User';
    if (blocState is MessagesLoaded && _replyingToMessage != null) {
      authorName = blocState.userNames[_replyingToMessage!.authorId] ?? 'User';
    }

    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 0),
      color: AppColors.bgPrimary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.reply, color: AppColors.accentBlue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: const TextStyle(
                            color: AppColors.accentBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyingToMessage!.text,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              color: AppColors.textTertiary,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }
}

/// Виджет отображения документа с открытием через стандартные средства ОС
class _DocumentBubble extends StatefulWidget {
  final AttachedContentModel content;
  final bool isMine;

  const _DocumentBubble({required this.content, required this.isMine});

  @override
  State<_DocumentBubble> createState() => _DocumentBubbleState();
}

class _DocumentBubbleState extends State<_DocumentBubble> {
  bool _isLoading = false;

  Future<void> _openFile() async {
    // Если файл уже есть локально — открываем сразу (расширение сохранено)
    if (widget.content.localPath != null &&
        widget.content.localPath!.isNotEmpty) {
      final file = File(widget.content.localPath!);
      if (await file.exists()) {
        await OpenFilex.open(widget.content.localPath!);
        return;
      }
    }

    // Скачиваем через кеш
    setState(() => _isLoading = true);
    try {
      final fileInfo = await sl<MediaCacheService>().downloadFile(
        widget.content.accessKey,
      );

      // flutter_cache_manager сохраняет файл без расширения →
      // iOS не определяет тип. Копируем с правильным именем во temp.
      final fileName = widget.content.fileName.isNotEmpty
          ? widget.content.fileName
          : 'file';
      final tempDir = await getTemporaryDirectory();
      final destPath = '${tempDir.path}/$fileName';
      final destFile = File(destPath);
      await fileInfo.file.copy(destPath);

      final result = await OpenFilex.open(destFile.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMine = widget.isMine;
    return GestureDetector(
      onTap: _openFile,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF6B58FF) : const Color(0xFFE4E4E5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.insert_drive_file,
                color: isMine ? Colors.white : AppColors.accentBlue,
                size: 28,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.content.fileName,
                    style: TextStyle(
                      color: isMine
                          ? AppColors.textOnAccent
                          : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isLoading)
                    Text(
                      'Загрузка...',
                      style: TextStyle(
                        color: isMine
                            ? AppColors.textOnAccent
                            : AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    )
                  else
                    Text(
                      'Нажмите, чтобы открыть',
                      style: TextStyle(
                        color: isMine
                            ? AppColors.textOnAccent
                            : AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
