import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:messenger/core/di/injection_container.dart';

class ContactProfileScreen extends StatefulWidget {
  final String name;
  final String phone;
  final Color color;
  final bool isOnline;
  final bool inMessenger;
  final String? userId;

  const ContactProfileScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.color,
    required this.isOnline,
    required this.inMessenger,
    this.userId,
  });

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen> {
  bool _isLoadingChat = false;

  Future<void> _createAndNavigateToChat() async {
    debugPrint('[CHAT] _createAndNavigateToChat called. userId=${widget.userId}');
    if (widget.userId == null || widget.userId!.isEmpty) {
      debugPrint('[CHAT] userId is null or empty, returning early');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось определить ID пользователя')),
        );
      }
      return;
    }
    
    setState(() => _isLoadingChat = true);
    debugPrint('[CHAT] Starting request flow...');
    try {
      final dio = sl<Dio>(instanceName: 'chatDio');
      String? chatId;

      // 1. Try to find existing personal chat
      try {
        final response = await dio.get(
          '/chats/personal',
          queryParameters: {'user_id': widget.userId},
        );
        final data = response.data;
        debugPrint('[CHAT] GET /chats/personal response: $data');
        if (data != null && data['data'] != null) {
          chatId = (data['data']['chat_id'] ?? data['data']['id'])?.toString();
        }
        debugPrint('[CHAT] Found existing chatId: $chatId');
      } on DioException catch (e) {
        debugPrint('[CHAT] GET /chats/personal error: status=${e.response?.statusCode}, data=${e.response?.data}');
        if (e.response?.statusCode == 404) {
          debugPrint('[CHAT] Chat not found (404), will create new one');
        } else if (e.response?.statusCode == 422) {
          final errorMsg = e.response?.data?['error']?['message'] ?? 'Ошибка валидации';
          debugPrint('[CHAT] Validation error (422): $errorMsg');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg)),
            );
          }
          return;
        } else {
          rethrow;
        }
      }

      // 2. If no existing chat, create a new one
      if (chatId == null) {
        debugPrint('[CHAT] Creating new chat via POST /chats...');
        final createResponse = await dio.post('/chats', data: {
          'type': 1,
          'member_ids': [widget.userId],
        });
        final createData = createResponse.data;
        debugPrint('[CHAT] POST /chats response: $createData');
        if (createData != null && createData['data'] != null) {
          chatId = (createData['data']['chat_id'] ?? createData['data']['id'] ?? createData['data']['ID'])?.toString();
        }
        debugPrint('[CHAT] Created chatId: $chatId');
      }

      // 3. Navigate to dialog screen
      debugPrint('[CHAT] Final chatId=$chatId, mounted=$mounted');
      if (mounted && chatId != null) {
        debugPrint('[CHAT] Navigating to /chat/$chatId');
        context.push('/chat/$chatId', extra: widget.name);
      }
    } catch (e) {
      debugPrint('[CHAT] Outer catch error: $e');
      if (mounted) {
        String message = 'Не удалось открыть чат';
        if (e is DioException && e.response?.data != null) {
          message = e.response?.data?['error']?['message']?.toString() ?? message;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameParts = widget.name.split(' ').where((p) => p.isNotEmpty);
    final initials = nameParts.isEmpty ? '?' : nameParts.map((w) => w[0]).take(2).join().toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.accentBlue),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Контакт',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Divider(height: 1, color: AppColors.borderDefault),
              
              // Profile Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.textOnAccent,
                          fontFamily: 'Inter',
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: widget.isOnline ? AppColors.successGreen : AppColors.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isOnline ? 'В сети' : 'Не в сети',
                          style: TextStyle(
                            color: widget.isOnline ? AppColors.successGreen : AppColors.textTertiary,
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (widget.inMessenger) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlueLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.chat_bubble_outline, color: AppColors.accentBlue, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Есть в системе',
                              style: TextStyle(
                                color: AppColors.accentBlue,
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.borderDefault),

              // Actions
              if (widget.inMessenger) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      _buildActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'Написать',
                        onTap: _createAndNavigateToChat,
                        isLoading: _isLoadingChat,
                      ),
                      const SizedBox(width: 12),
                      _buildActionButton(
                        icon: Icons.phone_outlined,
                        label: 'Позвонить',
                        onTap: () {},
                      ),
                      const SizedBox(width: 12),
                      _buildActionButton(
                        icon: Icons.videocam_outlined,
                        label: 'Видео',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderDefault),
              ],

              // Info Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.phone_outlined, widget.phone),
                    const SizedBox(height: 20),
                    _buildInfoRow(Icons.mail_outline, 'Нет email'),
                    const SizedBox(height: 20),
                    _buildInfoRow(Icons.location_on_outlined, 'Нет адреса'),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.borderDefault),

              // Shared Media
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Медиа и файлы',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: const [
                        Text(
                          '0',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.accentBlueLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: AppColors.accentBlue, strokeWidth: 2),
                )
              else
                Icon(icon, color: AppColors.accentBlue, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.accentBlue,
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}
