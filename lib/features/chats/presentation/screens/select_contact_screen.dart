import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_bloc.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_event.dart';
import 'package:messenger/features/chats/presentation/bloc/contact_chat_launch_bloc.dart';
import 'package:messenger/shared/contacts/matched_contacts_bloc.dart';
import 'package:messenger/shared/contacts/matched_contacts_view.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onContactSelected(MatchedContact contact) async {
    await context.read<ContactChatLaunchBloc>().launchConversation(
      userId: contact.userId,
      displayName: matchedContactDisplayName(context, contact),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        titleSpacing: 0,
        leadingWidth: 48,
        leading: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back, color: AppColors.accentBlue),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Личный чат',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: BlocListener<ContactChatLaunchBloc, ContactChatLaunchState>(
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
            // Pop selection screen and go to chat
            context.pop();
            context.push(
              '/chat/${state.resolvedChatId}',
              extra: 'Personal Chat',
            );
          }
        },
        child: Column(
          children: [
            const Divider(height: 1, color: AppColors.borderDefault),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Поиск контактов...',
                        hintStyle: TextStyle(
                          color: AppColors.textTertiary,
                          fontFamily: 'Inter',
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Contacts label
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: const Text(
                'ВЫБЕРИТЕ КОНТАКТ',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            // Contact list
            Expanded(child: _buildContacts()),
          ],
        ),
      ),
    );
  }

  Widget _buildContacts() {
    return MatchedContactsView(
      builder: (context, loadedContacts) {
        final contacts = filterMatchedContacts(
          context,
          loadedContacts,
          _searchQuery,
        );
        return MatchedContactsList(
          contacts: contacts,
          onContactTap: _onContactSelected,
        );
      },
    );
  }
}
