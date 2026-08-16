import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:messenger/shared/contacts/matched_contacts_bloc.dart';
import 'package:messenger/shared/contacts/matched_contacts_view.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<MatchedContact>> _groupedContacts(
    BuildContext context,
    List<MatchedContact> contacts,
  ) {
    final map = <String, List<MatchedContact>>{};
    for (final contact in filterMatchedContacts(
      context,
      contacts,
      _searchQuery,
    )) {
      final displayName = matchedContactDisplayName(context, contact);
      final letter = displayName[0].toUpperCase();
      map.putIfAbsent(letter, () => []).add(contact);
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Контакты',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      color: AppColors.textTertiary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
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
                          hintText: 'Поиск',
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
            ),
            // Contact list
            Expanded(child: _buildContacts()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>('/create-contact');
          if (!context.mounted) return;
          if (result == true) {
            await context.read<MatchedContactsBloc>().load();
          }
        },
        backgroundColor: AppColors.accentBlue,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContacts() {
    return MatchedContactsView(
      builder: (context, contacts) {
        final groupedContacts = _groupedContacts(context, contacts);
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: groupedContacts.entries.expand((entry) {
            return <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ...entry.value.map(_buildContactTile),
            ];
          }).toList(),
        );
      },
    );
  }

  Widget _buildContactTile(MatchedContact contact) {
    final displayName = matchedContactDisplayName(context, contact);
    final color = AppColors.contactAvatarColor(contact.avatarIndex);

    return GestureDetector(
      onTap: () {
        context.push(
          '/contact-profile',
          extra: {
            'name': displayName,
            'phone': contact.phone,
            'color': color,
            'isOnline': contact.isOnline,
            'inMessenger': true,
            'userId': contact.userId,
          },
        );
      },
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: AppColors.accentBlueLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Avatar
            MatchedContactAvatar(contact: contact),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.phone,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Inter',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Right indicators
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (contact.isOnline)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.successGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (contact.isOnline) const SizedBox(width: 8),
                const Icon(
                  Icons.chat_bubble,
                  size: 16,
                  color: AppColors.accentBlue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
