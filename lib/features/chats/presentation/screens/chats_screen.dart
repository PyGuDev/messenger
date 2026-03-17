import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_bloc.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_event.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_state.dart';
import 'package:messenger/shared/widgets/custom_text_field.dart';
import 'package:messenger/shared/widgets/error_display.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<ChatsBloc>().add(LoadChats());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<ChatsBloc>().add(LoadMoreChats());
    }
  }

  void _showCreateChatDialog() {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController userIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgPrimary,
        title: Text(l10n.createChat, style: const TextStyle(color: AppColors.textPrimary)),
        content: CustomTextField(
          controller: userIdController,
          hintText: l10n.enterUserId,
          prefixIcon: Icons.person,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue),
            onPressed: () {
              if (userIdController.text.isNotEmpty) {
                context.read<ChatsBloc>().add(CreateChat(userIdController.text));
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.save, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays == 0) {
      return DateFormat.Hm().format(time); // HH:mm
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd.MM.yy').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(l10n.chats, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
      ),
      body: BlocConsumer<ChatsBloc, ChatsState>(
        listener: (context, state) {
          if (state is ChatCreatedSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chat created successfully!')),
            );
          } else if (state is ChatsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        buildWhen: (previous, current) => current is ChatsLoading || current is ChatsLoaded || current is ChatsError,
        builder: (context, state) {
          if (state is ChatsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ChatsLoaded) {
            if (state.chats.isEmpty) {
              return Center(
                child: Text(l10n.welcome, style: const TextStyle(color: AppColors.textSecondary)),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<ChatsBloc>().add(LoadChats());
              },
              child: ListView.separated(
                controller: _scrollController,
                itemCount: state.hasReachedMax ? state.chats.length : state.chats.length + 1,
                separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderDefault),
                itemBuilder: (context, index) {
                  if (index >= state.chats.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final chat = state.chats[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentBlueLight,
                      child: Text(
                        chat.displayName.isNotEmpty ? chat.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      chat.displayName,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    subtitle: chat.lastMessage != null
                        ? Text(
                            chat.lastMessage!.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary),
                          )
                        : null,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(chat.lastMessage?.createdAt),
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        ),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.accentBlue,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${chat.unreadCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      context.push('/chat/${chat.id}', extra: chat.displayName);
                    },
                  );
                },
              ),
            );
          } else if (state is ChatsError) {
            return ErrorDisplay(
              message: state.message,
              onRetry: () => context.read<ChatsBloc>().add(LoadChats()),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateChatDialog,
        backgroundColor: AppColors.accentBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
