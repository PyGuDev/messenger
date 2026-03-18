import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/chats/presentation/screens/create_chat_screen.dart';
import '../../features/contacts/presentation/screens/create_contact_screen.dart';
import 'main_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
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
        return MessagesScreen(chatId: chatId, title: title);
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
  ],
);
