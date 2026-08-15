import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../security/token_storage.dart';
import '../network/network_module.dart';
import '../network/runtime_environment_profile.dart';
import '../network/configuration_error_state.dart';
import '../network/user_service.dart';
import 'package:dio/dio.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../features/chats/presentation/bloc/chats_bloc.dart';
import '../../features/chats/presentation/bloc/contact_chat_launch_bloc.dart';
import '../../features/messages/presentation/bloc/messages_bloc.dart';
import '../../features/network/presentation/bloc/network_bloc.dart';
import '../network/websocket_service.dart';
import '../network/network_info.dart';
import '../network/file_service.dart';
import '../network/voice_recorder_service.dart';
import '../network/camera_service.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/messages/data/datasources/messages_local_data_source.dart';
import '../../features/chats/data/datasources/chats_local_data_source.dart';
import '../local/database_provider.dart';
import '../local/database_helper.dart';
import '../cache/media_cache_service.dart';
import '../cache/profile_cache.dart';
import '../contacts/matched_contacts_adapters.dart';
import '../../shared/contacts/matched_contacts_bloc.dart';

import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance; // sl stands for Service Locator

Future<ConfigurationErrorState?> init() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => Connectivity());

  // Core
  sl.registerLazySingleton<TokenStorage>(() => TokenStorageImpl(sl()));
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());
  sl.registerLazySingleton<DatabaseProvider>(() => sl<DatabaseHelper>());
  sl.registerLazySingleton<ProfileCache>(
    () => SharedPreferencesProfileCache(sl()),
  );

  final environmentProfile = RuntimeEnvironmentProfile.fromEnvironment();
  final configurationError = environmentProfile.validate();
  sl.registerLazySingleton(() => environmentProfile);

  if (configurationError != null) {
    sl.registerLazySingleton(() => configurationError);
    return configurationError;
  }

  // Network
  sl.registerLazySingleton<Dio>(
    () =>
        Dio(BaseOptions(baseUrl: sl<RuntimeEnvironmentProfile>().authBaseUrl)),
    instanceName: 'internalDio',
  );

  sl.registerLazySingleton<Dio>(
    () => NetworkModule.createAuthDio(
      sl<RuntimeEnvironmentProfile>(),
      sl(),
      sl(instanceName: 'internalDio'),
      onTokenExpired: () => sl<AuthBloc>().add(LogoutRequested()),
    ),
    instanceName: 'authDio',
  );

  sl.registerLazySingleton<Dio>(
    () => NetworkModule.createChatDio(
      sl<RuntimeEnvironmentProfile>(),
      sl(),
      sl(instanceName: 'internalDio'),
      onTokenExpired: () => sl<AuthBloc>().add(LogoutRequested()),
    ),
    instanceName: 'chatDio',
  );

  sl.registerLazySingleton<Dio>(
    () => NetworkModule.createFileDio(
      sl<RuntimeEnvironmentProfile>(),
      sl(),
      sl(instanceName: 'internalDio'),
      onTokenExpired: () => sl<AuthBloc>().add(LogoutRequested()),
    ),
    instanceName: 'fileDio',
  );

  sl.registerLazySingleton<WebSocketService>(
    () => WebSocketService(
      sl<TokenStorage>(),
      sl<NetworkInfo>(),
      sl<RuntimeEnvironmentProfile>(),
    ),
  );

  // Services
  sl.registerLazySingleton<UserService>(
    () => UserService(sl<Dio>(instanceName: 'authDio')),
  );
  sl.registerLazySingleton<DeviceContactsGateway>(
    () => const FlutterDeviceContactsGateway(),
  );
  sl.registerLazySingleton<MessengerUserLookup>(
    () => UserServiceMessengerUserLookup(sl<UserService>()),
  );
  sl.registerLazySingleton<FileService>(
    () => FileService(sl<Dio>(instanceName: 'fileDio'), sl()),
  );
  sl.registerLazySingleton<VoiceRecorderService>(() => VoiceRecorderService());
  sl.registerLazySingleton<CameraService>(() => CameraService());
  sl.registerLazySingleton<MessagesLocalDataSource>(
    () => MessagesLocalDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<ChatsLocalDataSource>(
    () => ChatsLocalDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<MediaCacheService>(
    () => MediaCacheService(sl<FileService>(), sl<TokenStorage>()),
  );

  // Bloc
  sl.registerFactory<NetworkBloc>(() => NetworkBloc(sl()));
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(sl(instanceName: 'authDio'), sl(), sl(), sl()),
  );
  sl.registerFactory<ProfileBloc>(
    () => ProfileBloc(sl(instanceName: 'authDio'), sl(), sl()),
  );
  sl.registerLazySingleton<ChatsBloc>(
    () => ChatsBloc(
      sl(instanceName: 'chatDio'),
      sl(),
      sl<UserService>(),
      sl<TokenStorage>(),
      sl<ChatsLocalDataSource>(),
    ),
  );
  sl.registerFactory<ContactChatLaunchBloc>(
    () => ContactChatLaunchBloc(
      sl<Dio>(instanceName: 'chatDio'),
      sl<ChatsBloc>(),
    ),
  );
  sl.registerFactory<MatchedContactsBloc>(
    () => MatchedContactsBloc(
      sl<DeviceContactsGateway>(),
      sl<MessengerUserLookup>(),
    ),
  );
  sl.registerFactory<MessagesBloc>(
    () => MessagesBloc(
      sl(instanceName: 'chatDio'),
      sl(),
      sl(),
      sl(),
      sl<UserService>(),
      sl<FileService>(),
      sl<MessagesLocalDataSource>(),
    ),
  );

  return null;
}
