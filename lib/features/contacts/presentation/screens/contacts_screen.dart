import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/shared/theme/app_colors.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Demo contacts data grouped by first letter
  final List<_ContactItem> _allContacts = [
    _ContactItem('Алексей Иванов', '+7 (903) 555-12-34', const Color(0xFF3B82F6), true, true),
    _ContactItem('Анна Петрова', '+7 (916) 233-45-67', const Color(0xFF8B5CF6), false, false),
    _ContactItem('Виктор Смирнов', '+7 (926) 111-22-33', const Color(0xFF10B981), false, true),
    _ContactItem('Дарья Козлова', '+7 (905) 987-65-43', const Color(0xFFF59E0B), true, false),
    _ContactItem('Елена Волкова', '+7 (917) 444-55-66', const Color(0xFFEF4444), true, true),
    _ContactItem('Кирилл Новиков', '+7 (925) 777-88-99', const Color(0xFF6366F1), false, false),
    _ContactItem('Мария Лебедева', '+7 (909) 321-54-76', const Color(0xFFEC4899), false, true),
    _ContactItem('Михаил Фёдоров', '+7 (912) 654-32-10', const Color(0xFF14B8A6), true, false),
    _ContactItem('Наталья Соколова', '+7 (910) 888-77-66', const Color(0xFFF97316), false, false),
    _ContactItem('Олег Морозов', '+7 (903) 222-33-44', const Color(0xFF0EA5E9), true, true),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ContactItem> get _filteredContacts {
    if (_searchQuery.isEmpty) return _allContacts;
    return _allContacts
        .where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Map<String, List<_ContactItem>> get _groupedContacts {
    final map = <String, List<_ContactItem>>{};
    for (final contact in _filteredContacts) {
      final letter = contact.name[0].toUpperCase();
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
                  GestureDetector(
                    onTap: () => context.push('/create-contact'),
                    child: const Icon(Icons.add, color: AppColors.textTertiary, size: 22),
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
              child: ListView(
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
    );
  }

  Widget _buildContactTile(_ContactItem contact) {
    final initials = contact.name.split(' ').map((w) => w[0]).take(2).join();
    final hasMessenger = contact.inMessenger;

    return Container(
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
    );
  }
}

class _ContactItem {
  final String name;
  final String phone;
  final Color color;
  final bool isOnline;
  final bool inMessenger;

  _ContactItem(this.name, this.phone, this.color, this.isOnline, this.inMessenger);
}
