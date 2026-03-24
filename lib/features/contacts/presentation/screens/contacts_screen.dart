import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get_it/get_it.dart';
import 'package:messenger/core/network/user_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<_ContactItem> _allContacts = [];
  bool _isLoadingContacts = true;

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
    
    // Process in paralell chunks to not spam the event loop but finish fast
    final chunks = <List<_ContactItem>>[];
    const chunkSize = 10;
    for (var i = 0; i < _allContacts.length; i += chunkSize) {
      final end = (i + chunkSize < _allContacts.length) ? i + chunkSize : _allContacts.length;
      chunks.add(_allContacts.sublist(i, end));
    }

    for (final chunk in chunks) {
      await Future.wait(chunk.map((item) async {
        try {
          // Keep + and digits
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
    _searchController.dispose();
    super.dispose();
  }

  List<_ContactItem> get _filteredContacts {
    final systemContacts = _allContacts.where((c) => c.inMessenger).toList();
    if (_searchQuery.isEmpty) return systemContacts;
    return systemContacts
        .where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Map<String, List<_ContactItem>> get _groupedContacts {
    final map = <String, List<_ContactItem>>{};
    for (final contact in _filteredContacts) {
      final letter = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';
      map.putIfAbsent(letter, () => []).add(contact);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
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
                    const Icon(Icons.search, color: AppColors.textTertiary, size: 18),
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
            Expanded(
              child: _isLoadingContacts 
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
                : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: _groupedContacts.entries.expand((entry) {
                  return [
                    // Section header
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
                    // Contacts in section
                    ...entry.value.map((contact) => _buildContactTile(contact)),
                  ];
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>('/create-contact');
          if (result == true && mounted) {
            setState(() => _isLoadingContacts = true);
            _fetchContacts();
          }
        },
        backgroundColor: AppColors.accentBlue,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContactTile(_ContactItem contact) {
    final nameParts = contact.name.split(' ').where((p) => p.isNotEmpty);
    final initials = nameParts.isEmpty ? '?' : nameParts.map((w) => w[0]).take(2).join().toUpperCase();
    final hasMessenger = contact.inMessenger;

    return GestureDetector(
      onTap: () {
        context.push('/contact-profile', extra: {
          'name': contact.name,
          'phone': contact.phone,
          'color': contact.color,
          'isOnline': contact.isOnline,
          'inMessenger': contact.inMessenger,
          'userId': contact.userId,
        });
      },
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: hasMessenger ? AppColors.accentBlueLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
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
              if (contact.isOnline && hasMessenger) const SizedBox(width: 8),
              if (hasMessenger)
                const Icon(Icons.chat_bubble, size: 16, color: AppColors.accentBlue),
            ],
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
