import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/l10n/app_localizations.dart';
import 'package:messenger/shared/contacts/matched_contacts_bloc.dart';
import 'package:messenger/shared/contacts/matched_contacts_view.dart';

class _FailingDeviceContactsGateway implements DeviceContactsGateway {
  @override
  Future<DeviceContactsResult> loadContacts() async {
    throw StateError('unavailable');
  }
}

class _ResultDeviceContactsGateway implements DeviceContactsGateway {
  const _ResultDeviceContactsGateway(this.result);

  final DeviceContactsResult result;

  @override
  Future<DeviceContactsResult> loadContacts() async => result;
}

class _UnusedMessengerUserLookup implements MessengerUserLookup {
  @override
  Future<String?> findUserIdByPhone(String phone) async => null;
}

void main() {
  for (final testCase in <(Locale, String)>[
    (const Locale('en'), 'Could not load contacts'),
    (const Locale('ru'), 'Не удалось загрузить контакты'),
  ]) {
    testWidgets(
      'renders the Matched Contacts failure in ${testCase.$1.languageCode}',
      (tester) async {
        final bloc = MatchedContactsBloc(
          _FailingDeviceContactsGateway(),
          _UnusedMessengerUserLookup(),
        );
        await bloc.load();

        await tester.pumpWidget(_app(bloc, testCase.$1));

        expect(find.text(testCase.$2), findsOneWidget);
        await bloc.close();
      },
    );
  }

  for (final testCase in <(Locale, String)>[
    (const Locale('en'), 'Contact permission is required'),
    (const Locale('ru'), 'Разрешите доступ к контактам'),
  ]) {
    testWidgets('renders permission denial in ${testCase.$1.languageCode}', (
      tester,
    ) async {
      final bloc = MatchedContactsBloc(
        const _ResultDeviceContactsGateway(DeviceContactsResult.denied()),
        _UnusedMessengerUserLookup(),
      );
      await bloc.load();

      await tester.pumpWidget(_app(bloc, testCase.$1));

      expect(find.text(testCase.$2), findsOneWidget);
      await bloc.close();
    });
  }

  for (final testCase in <(Locale, String)>[
    (const Locale('en'), 'No Messenger contacts found'),
    (const Locale('ru'), 'Контакты Messenger не найдены'),
  ]) {
    testWidgets(
      'renders the empty Matched Contacts state in ${testCase.$1.languageCode}',
      (tester) async {
        final bloc = MatchedContactsBloc(
          const _ResultDeviceContactsGateway(
            DeviceContactsResult(permissionGranted: true),
          ),
          _UnusedMessengerUserLookup(),
        );
        await bloc.load();

        await tester.pumpWidget(_app(bloc, testCase.$1));

        expect(find.text(testCase.$2), findsOneWidget);
        await bloc.close();
      },
    );
  }
}

Widget _app(MatchedContactsBloc bloc, Locale locale) {
  return BlocProvider<MatchedContactsBloc>.value(
    value: bloc,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('en'), Locale('ru')],
      home: MatchedContactsView(builder: (_, _) => const SizedBox.shrink()),
    ),
  );
}
