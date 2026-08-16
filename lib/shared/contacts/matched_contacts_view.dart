import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'matched_contacts_bloc.dart';

typedef MatchedContactsBuilder =
    Widget Function(BuildContext context, List<MatchedContact> contacts);

class MatchedContactsView extends StatelessWidget {
  const MatchedContactsView({super.key, required this.builder});

  final MatchedContactsBuilder builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MatchedContactsBloc, MatchedContactsState>(
      builder: (context, state) {
        return switch (state) {
          MatchedContactsInitial() || MatchedContactsLoading() => const Center(
            child: CircularProgressIndicator(color: AppColors.accentBlue),
          ),
          MatchedContactsFailure(:final reason) => Center(
            child: Text(_failureMessage(context, reason)),
          ),
          MatchedContactsLoaded(permissionDenied: true) => Center(
            child: Text(AppLocalizations.of(context)!.contactsPermissionDenied),
          ),
          MatchedContactsLoaded(:final contacts) when contacts.isEmpty =>
            Center(
              child: Text(AppLocalizations.of(context)!.noMatchedContacts),
            ),
          MatchedContactsLoaded(:final contacts) => builder(context, contacts),
        };
      },
    );
  }

  String _failureMessage(
    BuildContext context,
    MatchedContactsFailureReason reason,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return switch (reason) {
      MatchedContactsFailureReason.deviceContactsUnavailable =>
        l10n.contactsLoadFailed,
    };
  }
}

String matchedContactDisplayName(BuildContext context, MatchedContact contact) {
  return contact.name.isEmpty
      ? AppLocalizations.of(context)!.unknownContact
      : contact.name;
}

List<MatchedContact> filterMatchedContacts(
  BuildContext context,
  List<MatchedContact> contacts,
  String query,
) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return contacts;
  return contacts
      .where(
        (contact) => matchedContactDisplayName(
          context,
          contact,
        ).toLowerCase().contains(normalizedQuery),
      )
      .toList();
}

class MatchedContactAvatar extends StatelessWidget {
  const MatchedContactAvatar({super.key, required this.contact});

  final MatchedContact contact;

  @override
  Widget build(BuildContext context) {
    final displayName = matchedContactDisplayName(context, contact);
    final nameParts = displayName.split(' ').where((part) => part.isNotEmpty);
    final initials = nameParts.isEmpty
        ? '?'
        : nameParts.map((word) => word[0]).take(2).join().toUpperCase();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.contactAvatarColor(contact.avatarIndex),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.textOnAccent,
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class MatchedContactsList extends StatelessWidget {
  const MatchedContactsList({
    super.key,
    required this.contacts,
    required this.onContactTap,
    this.selectedUserIds,
  });

  final List<MatchedContact> contacts;
  final ValueChanged<MatchedContact> onContactTap;
  final Set<String>? selectedUserIds;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return MatchedContactRow(
          contact: contact,
          onTap: () => onContactTap(contact),
          isSelected: selectedUserIds?.contains(contact.userId),
        );
      },
    );
  }
}

class MatchedContactRow extends StatelessWidget {
  const MatchedContactRow({
    super.key,
    required this.contact,
    required this.onTap,
    this.isSelected,
  });

  final MatchedContact contact;
  final VoidCallback onTap;
  final bool? isSelected;

  @override
  Widget build(BuildContext context) {
    final displayName = matchedContactDisplayName(context, contact);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            MatchedContactAvatar(contact: contact),
            const SizedBox(width: 12),
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
                    contact.isOnline
                        ? AppLocalizations.of(context)!.contactOnline
                        : AppLocalizations.of(context)!.contactOffline,
                    style: TextStyle(
                      color: contact.isOnline
                          ? AppColors.successGreen
                          : AppColors.textTertiary,
                      fontFamily: 'Inter',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected case final selected?)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accentBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: selected
                      ? null
                      : Border.all(color: AppColors.borderDefault, width: 1.5),
                ),
                child: selected
                    ? const Icon(
                        Icons.check,
                        color: AppColors.textOnAccent,
                        size: 14,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
