import 'dart:async';
import 'package:go_router/go_router.dart';
import '../di/injection_container.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/chats/presentation/screens/create_chat_screen.dart';
import '../../features/contacts/presentation/screens/create_contact_screen.dart';
import '../../features/contacts/presentation/screens/contact_profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'main_screen.dart';
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(sl<AuthBloc>().stream),
  redirect: (context, state) {
    final authState = sl<AuthBloc>().state;
    
    // While checking auth status, stay on splash screen
    if (authState is AuthInitial || authState is AuthLoading) {
      if (state.matchedLocation != '/') return '/';
      return null;
    }

    final isAuthRoute = state.matchedLocation == '/welcome' || 
                        state.matchedLocation == '/login' || 
                        state.matchedLocation == '/register';

    if (authState is AuthAuthenticated) {
      // If logged in, don't allow auth routes or splash
      if (isAuthRoute || state.matchedLocation == '/') return '/chats';
    } else if (authState is AuthUnauthenticated) {
      // If not logged in, only allow auth routes
      if (!isAuthRoute) return '/welcome';
    }
    
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/chats',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) {
        final chatId = state.pathParameters['id']!;
        final title = state.extra as String? ?? 'Chat';
        final isGroup = state.uri.queryParameters['isGroup'] == 'true';
        return MessagesScreen(chatId: chatId, title: title, isGroup: isGroup);
      },
    ),
    GoRoute(
      path: '/create-chat',
      builder: (context, state) => const CreateChatScreen(),
    ),
    GoRoute(
      path: '/create-contact',
      builder: (context, state) => const CreateContactScreen(),
    ),
    GoRoute(
      path: '/contact-profile',
      builder: (context, state) {
        final Map<String, dynamic> extra = state.extra as Map<String, dynamic>? ?? {};
        return ContactProfileScreen(
          name: extra['name'] as String? ?? 'Unknown',
          phone: extra['phone'] as String? ?? '',
          color: extra['color'] as Color? ?? Colors.grey,
          isOnline: extra['isOnline'] as bool? ?? false,
          inMessenger: extra['inMessenger'] as bool? ?? false,
          userId: extra['userId'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
  ],
);
