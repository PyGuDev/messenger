import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_bloc.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_event.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_state.dart';

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
        title: Text(
          'Messenger',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textTertiary, size: 22),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: false,
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                  return SizedBox(
                    height: 72,
                    child: Center(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.accentBlueLight,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              chat.displayName.isNotEmpty ? chat.displayName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          chat.displayName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            fontSize: 16,
                          ),
                        ),
                        subtitle: chat.lastMessage != null
                            ? Text(
                                chat.lastMessage!.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                ),
                              )
                            : null,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatTime(chat.lastMessage?.createdAt),
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontFamily: 'Inter',
                                fontSize: 12,
                              ),
                            ),
                            if (chat.unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accentBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${chat.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          context.push('/chat/${chat.id}', extra: chat.displayName);
                        },
                      ),
                    ),
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
        onPressed: () => context.push('/create-chat'),
        backgroundColor: AppColors.accentBlue,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
