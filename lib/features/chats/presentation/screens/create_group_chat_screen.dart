import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get_it/get_it.dart';
import 'package:messenger/core/network/user_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_bloc.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_event.dart';

class CreateGroupChatScreen extends StatefulWidget {
  const CreateGroupChatScreen({super.key});

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  List<_ContactItem> _allContacts = [];
  bool _isLoadingContacts = true;
  final Set<String> _selectedUserIds = {}; // Only users with a backend ID can be selected

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    final permissionStatus = await Permission.contacts.request();
    if (!permissionStatus.isGranted) {
      if (mounted) setState(() => _isLoadingContacts = false);
      return;
    }
    
    final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
    final List<_ContactItem> items = [];
    final colors = [
      AppColors.accentBlue,
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFFF97316),
      const Color(0xFF0EA5E9),
    ];

    int colorIndex = 0;
    for (final contact in contacts) {
      if (contact.phones.isEmpty) continue;
      
      final phone = contact.phones.first.number;
      final name = (contact.displayName != null && contact.displayName!.isNotEmpty) 
          ? contact.displayName! 
          : 'Unknown';
      
      items.add(_ContactItem(name, phone, colors[colorIndex % colors.length], false, false));
      colorIndex++;
    }
    
    _allContacts = items;
    if (mounted) {
      setState(() {});
    }
    
    if (items.isNotEmpty) {
      await _syncWithBackend();
    }

    if (mounted) {
      setState(() {
        _isLoadingContacts = false;
      });
    }
  }

  Future<void> _syncWithBackend() async {
    final userService = GetIt.I<UserService>();
    
    final chunks = <List<_ContactItem>>[];
    const chunkSize = 10;
    for (var i = 0; i < _allContacts.length; i += chunkSize) {
      final end = (i + chunkSize < _allContacts.length) ? i + chunkSize : _allContacts.length;
      chunks.add(_allContacts.sublist(i, end));
    }

    for (final chunk in chunks) {
      await Future.wait(chunk.map((item) async {
        try {
          final cleanPhone = item.phone.replaceAll(RegExp(r'[^\d+]'), '');
          final profiles = await userService.searchUser(phone: cleanPhone);
          if (profiles.isNotEmpty) {
            if (mounted) {
              setState(() {
                final index = _allContacts.indexOf(item);
                if (index != -1) {
                  _allContacts[index] = _ContactItem(item.name, item.phone, item.color, true, true, profiles.first.id);
                }
              });
            }
          }
        } catch (_) {}
      }));
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<_ContactItem> get _filteredContacts {
    final systemContacts = _allContacts.where((c) => c.inMessenger && c.userId != null).toList();
    if (_searchQuery.isEmpty) return systemContacts;
    return systemContacts
        .where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _createChat() {
    final title = _groupNameController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    context.read<ChatsBloc>().add(CreateGroupChat(title, _selectedUserIds.toList()));
    context.pop();
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
          'Создать группу',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: AppColors.borderDefault),
          // Group Name
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Название группы',
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
                      hintText: 'Введите название группы...',
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
              'КОНТАКТЫ',
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
            child: _isLoadingContacts 
              ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
              : ListView.builder(
              itemCount: _filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = _filteredContacts[index];
                final isSelected = _selectedUserIds.contains(contact.userId);
                return _buildContactTile(contact, isSelected, () {
                  setState(() {
                    if (isSelected) {
                      _selectedUserIds.remove(contact.userId!);
                    } else {
                      _selectedUserIds.add(contact.userId!);
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
              onTap: _createChat,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check, color: AppColors.textOnAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Создать чат',
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

  Widget _buildContactTile(_ContactItem contact, bool isSelected, VoidCallback onTap) {
    final nameParts = contact.name.split(' ').where((p) => p.isNotEmpty);
    final initials = nameParts.isEmpty ? '?' : nameParts.map((w) => w[0]).take(2).join().toUpperCase();
    final isOnline = contact.isOnline;

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
                    isOnline ? 'В сети' : 'Не в сети',
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

class _ContactItem {
  final String name;
  final String phone;
  final Color color;
  final bool isOnline;
  final bool inMessenger;
  final String? userId;

  _ContactItem(this.name, this.phone, this.color, this.isOnline, this.inMessenger, [this.userId]);
}
