import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/shared/theme/app_colors.dart';

class CreateChatScreen extends StatefulWidget {
  const CreateChatScreen({super.key});

  @override
  State<CreateChatScreen> createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends State<CreateChatScreen> {
  bool _isGroupMode = false;
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _selectedContacts = {0, 2}; // Pre-selected demo

  final List<_Contact> _contacts = [
    _Contact('Anna Kowalski', 'Online', const Color(0xFF3B82F6), true),
    _Contact('Dmitry Morozov', 'Last seen 2h ago', const Color(0xFF8B5CF6), false),
    _Contact('Elena Sokolova', 'Online', const Color(0xFFEC4899), true),
    _Contact('Maria Petrova', 'Last seen yesterday', const Color(0xFFF59E0B), false),
    _Contact('Ivan Volkov', 'Last seen 5h ago', const Color(0xFF10B981), false),
    _Contact('Olga Kuznetsova', 'Online', const Color(0xFF6366F1), false),
  ];

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<_Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    return _contacts
        .where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
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
          'New Chat',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 24),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: AppColors.borderDefault),
          // Chat Type Toggle
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildTypeButton('Regular', Icons.chat_bubble, !_isGroupMode, () {
                  setState(() => _isGroupMode = false);
                }),
                const SizedBox(width: 12),
                _buildTypeButton('Group', Icons.people, _isGroupMode, () {
                  setState(() => _isGroupMode = true);
                }),
              ],
            ),
          ),
          // Group Name (only in group mode)
          if (_isGroupMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Group Name',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _groupNameController,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter group name...',
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
          const Divider(height: 1, color: AppColors.borderDefault),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textTertiary, size: 18),
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
                      hintText: 'Search contacts...',
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
              'CONTACTS',
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
          Expanded(
            child: ListView.builder(
              itemCount: _filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = _filteredContacts[index];
                final originalIndex = _contacts.indexOf(contact);
                final isSelected = _selectedContacts.contains(originalIndex);
                return _buildContactTile(contact, isSelected, () {
                  setState(() {
                    if (isSelected) {
                      _selectedContacts.remove(originalIndex);
                    } else {
                      _selectedContacts.add(originalIndex);
                    }
                  });
                });
              },
            ),
          ),
          // Bottom action
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: GestureDetector(
              onTap: () {
                // TODO: create chat
                context.pop();
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add, color: AppColors.textOnAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Create Chat',
                      style: TextStyle(
                        color: AppColors.textOnAccent,
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive ? null : Border.all(color: AppColors.borderDefault, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? AppColors.textOnAccent : AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.textOnAccent : AppColors.textSecondary,
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactTile(_Contact contact, bool isSelected, VoidCallback onTap) {
    final isOnline = contact.status == 'Online';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: contact.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.status,
                    style: TextStyle(
                      color: isOnline ? AppColors.successGreen : AppColors.textTertiary,
                      fontFamily: 'Inter',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accentBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected ? null : Border.all(color: AppColors.borderDefault, width: 1.5),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: AppColors.textOnAccent, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Contact {
  final String name;
  final String status;
  final Color color;
  final bool isOnline;

  _Contact(this.name, this.status, this.color, this.isOnline);
}
