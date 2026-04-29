import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:messenger/features/chats/presentation/bloc/chats_bloc.dart';
import 'package:messenger/features/auth/presentation/bloc/auth_event.dart';
import 'package:messenger/features/network/presentation/bloc/network_bloc.dart';
import 'package:messenger/l10n/app_localizations.dart';
import 'core/network/configuration_error_state.dart';
import 'core/di/injection_container.dart' as di;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/navigation/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('.env file not found, falling back to environment variables');
  }
  final configurationError = await di.init();
  runApp(MessengerApp(configurationError: configurationError));
}

class MessengerApp extends StatelessWidget {
  final ConfigurationErrorState? configurationError;

  const MessengerApp({super.key, this.configurationError});

  @override
  Widget build(BuildContext context) {
    if (configurationError != null) {
      return MaterialApp(
        title: 'Messenger',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: ConfigurationErrorScreen(error: configurationError!),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<NetworkBloc>(create: (_) => di.sl<NetworkBloc>()),
        BlocProvider<AuthBloc>.value(
          value: di.sl<AuthBloc>()..add(CheckAuthStatus()),
        ),
        BlocProvider<ProfileBloc>(create: (_) => di.sl<ProfileBloc>()),
        BlocProvider<ChatsBloc>(create: (_) => di.sl<ChatsBloc>()),
      ],
      child: MaterialApp.router(
        title: 'Messenger',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru')],
      ),
    );
  }
}

class ConfigurationErrorScreen extends StatelessWidget {
  final ConfigurationErrorState error;

  const ConfigurationErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(error.message),
                if (error.missingKeys.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Missing or invalid values: ${error.missingKeys.join(', ')}',
                  ),
                ],
                if (error.affectedFlows.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Affected flows: ${error.affectedFlows.join(', ')}'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
