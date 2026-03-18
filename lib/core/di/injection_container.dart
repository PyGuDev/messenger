import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../security/token_storage.dart';
import '../network/network_module.dart';
import '../network/user_service.dart';
import 'package:dio/dio.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../features/chats/presentation/bloc/chats_bloc.dart';
import '../../features/messages/presentation/bloc/messages_bloc.dart';
import '../../features/network/presentation/bloc/network_bloc.dart';
import '../network/websocket_service.dart';
import '../network/network_info.dart';

final sl = GetIt.instance; // sl stands for Service Locator


Future<void> init() async {
  // External
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => Connectivity());

  // Core
  sl.registerLazySingleton<TokenStorage>(
    () => TokenStorageImpl(sl()),
  );
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl()),
  );

  // Network
  sl.registerLazySingleton<Dio>(
    () => Dio(BaseOptions(baseUrl: NetworkModule.authBaseUrl)),
    instanceName: 'internalDio',
  );

  sl.registerLazySingleton<Dio>(
    () => NetworkModule.createAuthDio(sl(), sl(instanceName: 'internalDio')),
    instanceName: 'authDio',
  );

  sl.registerLazySingleton<Dio>(
    () => NetworkModule.createChatDio(
      sl(),
      sl(instanceName: 'internalDio'),
    ),
    instanceName: 'chatDio',
  );

  sl.registerLazySingleton<WebSocketService>(
    () => WebSocketService(sl<TokenStorage>(), sl<NetworkInfo>()),
  );

  // Services
  sl.registerLazySingleton<UserService>(
    () => UserService(sl<Dio>(instanceName: 'authDio')),
  );

  // Bloc
  sl.registerFactory<NetworkBloc>(
    () => NetworkBloc(sl()),
  );
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(sl(instanceName: 'authDio'), sl(), sl()),
  );
  sl.registerFactory<ProfileBloc>(
    () => ProfileBloc(sl(instanceName: 'authDio')),
  );
  sl.registerFactory<ChatsBloc>(
    () => ChatsBloc(sl(instanceName: 'chatDio'), sl(), sl<UserService>(), sl<TokenStorage>()),
  );
  sl.registerFactory<MessagesBloc>(
    () => MessagesBloc(sl(instanceName: 'chatDio'), sl(), sl(), sl<UserService>()),
  );
}




