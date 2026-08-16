// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Messenger';

  @override
  String get login => 'Вход';

  @override
  String get register => 'Регистрация';

  @override
  String get welcome => 'Добро пожаловать';

  @override
  String get email => 'Электронная почта';

  @override
  String get password => 'Пароль';

  @override
  String get firstName => 'Имя';

  @override
  String get lastName => 'Фамилия';

  @override
  String get phone => 'Номер телефона';

  @override
  String get profile => 'Профиль';

  @override
  String get chats => 'Чаты';

  @override
  String get messages => 'Сообщения';

  @override
  String get edit => 'Редактировать';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get logout => 'Выйти';

  @override
  String get logoutConfirmation => 'Вы уверены, что хотите выйти?';

  @override
  String get createChat => 'Создать чат';

  @override
  String get enterUserId => 'Введите ID пользователя';

  @override
  String get invalidCredentials => 'Не верное имя пользователя или пароль';

  @override
  String get unknownContact => 'Неизвестный контакт';

  @override
  String get contactsLoadFailed => 'Не удалось загрузить контакты';

  @override
  String get contactsPermissionDenied => 'Разрешите доступ к контактам';

  @override
  String get noMatchedContacts => 'Контакты Messenger не найдены';

  @override
  String get contactOnline => 'В сети';

  @override
  String get contactOffline => 'Не в сети';

  @override
  String get chatHistoryOfflineUnavailable => 'История чата недоступна без подключения до завершения первой синхронизации.';

  @override
  String get messageDraftHint => 'Сообщение...';
}
