// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Messenger';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get welcome => 'Welcome';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get phone => 'Phone Number';

  @override
  String get profile => 'Profile';

  @override
  String get chats => 'Chats';

  @override
  String get messages => 'Messages';

  @override
  String get edit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirmation => 'Are you sure you want to logout?';

  @override
  String get createChat => 'Create Chat';

  @override
  String get enterUserId => 'Enter User ID';

  @override
  String get invalidCredentials => 'Invalid email or password';

  @override
  String get unknownContact => 'Unknown';

  @override
  String get contactsLoadFailed => 'Could not load contacts';

  @override
  String get contactsPermissionDenied => 'Contact permission is required';

  @override
  String get noMatchedContacts => 'No Messenger contacts found';

  @override
  String get contactOnline => 'Online';

  @override
  String get contactOffline => 'Offline';
}
