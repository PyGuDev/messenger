import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_bloc.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_event.dart';
import 'package:messenger/features/chats/presentation/bloc/contact_chat_launch_bloc.dart';

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
  Future<void> _createAndNavigateToChat() async {
    await context.read<ContactChatLaunchBloc>().launchConversation(
      userId: widget.userId ?? '',
      displayName: widget.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameParts = widget.name.split(' ').where((p) => p.isNotEmpty);
    final initials = nameParts.isEmpty
        ? '?'
        : nameParts.map((w) => w[0]).take(2).join().toUpperCase();

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
        child: BlocListener<ContactChatLaunchBloc, ContactChatLaunchState>(
          listener: (context, state) {
            if (state.status == ContactChatLaunchStatus.failed &&
                state.failureMessage != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.failureMessage!)));
            }

            if (state.status == ContactChatLaunchStatus.navigating &&
                state.resolvedChatId != null) {
              context.read<ChatsBloc>().add(LoadChats());
              context.read<ContactChatLaunchBloc>().clearOutcome();
              context.push('/chat/${state.resolvedChatId}', extra: widget.name);
            }
          },
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Divider(height: 1, color: AppColors.borderDefault),

                // Profile Section
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
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
                              color: widget.isOnline
                                  ? AppColors.successGreen
                                  : AppColors.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isOnline ? 'В сети' : 'Не в сети',
                            style: TextStyle(
                              color: widget.isOnline
                                  ? AppColors.successGreen
                                  : AppColors.textTertiary,
                              fontFamily: 'Inter',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (widget.inMessenger) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlueLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.chat_bubble_outline,
                                color: AppColors.accentBlue,
                                size: 16,
                              ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        _buildActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'Написать',
                          onTap: _createAndNavigateToChat,
                          isLoading: context
                              .select<ContactChatLaunchBloc, bool>(
                                (bloc) => bloc.state.isInFlight,
                              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
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
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.textTertiary,
                            size: 18,
                          ),
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
                  child: CircularProgressIndicator(
                    color: AppColors.accentBlue,
                    strokeWidth: 2,
                  ),
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
