import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/shared/contacts/matched_contacts_bloc.dart';

class _FakeDeviceContactsGateway implements DeviceContactsGateway {
  _FakeDeviceContactsGateway(this.result);

  final DeviceContactsResult result;

  @override
  Future<DeviceContactsResult> loadContacts() async => result;
}

class _FakeMessengerUserLookup implements MessengerUserLookup {
  _FakeMessengerUserLookup(
    this.matches, {
    this.throwingPhones = const <String>{},
  });

  final Map<String, String> matches;
  final Set<String> throwingPhones;
  final List<String> requestedPhones = <String>[];

  @override
  Future<String?> findUserIdByPhone(String phone) async {
    requestedPhones.add(phone);
    if (throwingPhones.contains(phone)) {
      throw StateError('lookup failed');
    }
    return matches[phone];
  }
}

class _ThrowingDeviceContactsGateway implements DeviceContactsGateway {
  @override
  Future<DeviceContactsResult> loadContacts() async {
    throw StateError('device contacts unavailable');
  }
}

void main() {
  test('loads only Matched Contacts and normalizes lookup phones', () async {
    final lookup = _FakeMessengerUserLookup(<String, String>{
      '+79991234567': 'user-1',
    });
    final bloc = MatchedContactsBloc(
      _FakeDeviceContactsGateway(
        const DeviceContactsResult(
          permissionGranted: true,
          contacts: <DeviceContactRecord>[
            DeviceContactRecord(
              displayName: 'Alice',
              phones: <String>['+7 (999) 123-45-67'],
            ),
            DeviceContactRecord(
              displayName: 'Bob',
              phones: <String>['+7 (999) 000-00-00'],
            ),
            DeviceContactRecord(displayName: 'No phone'),
          ],
        ),
      ),
      lookup,
    );

    await bloc.load();

    expect(lookup.requestedPhones, <String>['+79991234567', '+79990000000']);
    expect(bloc.state, isA<MatchedContactsLoaded>());
    final state = bloc.state as MatchedContactsLoaded;
    expect(state.permissionDenied, isFalse);
    expect(state.contacts, hasLength(1));
    expect(state.contacts.single.name, 'Alice');
    expect(state.contacts.single.phone, '+7 (999) 123-45-67');
    expect(state.contacts.single.userId, 'user-1');
    expect(state.contacts.single.avatarIndex, 0);

    await bloc.close();
  });

  test('reports permission denial without querying Messenger Users', () async {
    final lookup = _FakeMessengerUserLookup(const <String, String>{});
    final bloc = MatchedContactsBloc(
      _FakeDeviceContactsGateway(const DeviceContactsResult.denied()),
      lookup,
    );

    await bloc.load();

    final state = bloc.state as MatchedContactsLoaded;
    expect(state.permissionDenied, isTrue);
    expect(state.contacts, isEmpty);
    expect(lookup.requestedPhones, isEmpty);

    await bloc.close();
  });

  test('reports a semantic failure when Device Contacts cannot load', () async {
    final bloc = MatchedContactsBloc(
      _ThrowingDeviceContactsGateway(),
      _FakeMessengerUserLookup(const <String, String>{}),
    );

    await bloc.load();

    final state = bloc.state as MatchedContactsFailure;
    expect(
      state.reason,
      MatchedContactsFailureReason.deviceContactsUnavailable,
    );

    await bloc.close();
  });

  test('keeps successful matches when another lookup fails', () async {
    final lookup = _FakeMessengerUserLookup(
      const <String, String>{'+79991234567': 'user-1'},
      throwingPhones: const <String>{'+79990000000'},
    );
    final bloc = MatchedContactsBloc(
      _FakeDeviceContactsGateway(
        const DeviceContactsResult(
          permissionGranted: true,
          contacts: <DeviceContactRecord>[
            DeviceContactRecord(
              displayName: 'Alice',
              phones: <String>['+7 (999) 123-45-67'],
            ),
            DeviceContactRecord(
              displayName: 'Bob',
              phones: <String>['+7 (999) 000-00-00'],
            ),
          ],
        ),
      ),
      lookup,
    );

    await bloc.load();

    final state = bloc.state as MatchedContactsLoaded;
    expect(state.contacts.map((contact) => contact.name), <String>['Alice']);

    await bloc.close();
  });
}
