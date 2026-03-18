import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger/features/network/presentation/bloc/network_bloc.dart';
import 'package:messenger/features/network/presentation/bloc/network_state.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:messenger/features/chats/presentation/screens/chats_screen.dart';
import 'package:messenger/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:messenger/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:messenger/features/auth/presentation/bloc/auth_state.dart';
import 'package:messenger/features/profile/presentation/screens/profile_screen.dart';
import 'package:go_router/go_router.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // Start on Chats tab

  final List<Widget> _screens = [
    const ContactsScreen(),
    const ChatsScreen(),
    const _CallsPlaceholder(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go('/');
        }
      },
      child: Scaffold(
        body: Column(
        children: [
          BlocBuilder<NetworkBloc, NetworkState>(
            builder: (context, state) {
              if (state is NetworkDisconnected) {
                return Container(
                  width: double.infinity,
                  color: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: const Text(
                    'No Internet Connection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(21, 12, 21, 21),
        child: Container(
          height: 62,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            children: [
              _buildNavItem(0, Icons.people_outline, Icons.people, 'CONTACTS'),
              _buildNavItem(1, Icons.chat_bubble_outline, Icons.chat_bubble, 'CHATS'),
              _buildNavItem(2, Icons.phone_outlined, Icons.phone, 'CALLS'),
              _buildNavItem(3, Icons.settings_outlined, Icons.settings, 'SETTINGS'),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppColors.textOnAccent : AppColors.textTertiary,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.textOnAccent : AppColors.textTertiary,
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder for Calls tab
class _CallsPlaceholder extends StatelessWidget {
  const _CallsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.phone_outlined, size: 64, color: AppColors.textTertiary),
              SizedBox(height: 16),
              Text(
                'Звонки',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Скоро будет доступно',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
