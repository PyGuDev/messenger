import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../shared/contacts/matched_contacts_bloc.dart';
import '../network/user_service.dart';

class FlutterDeviceContactsGateway implements DeviceContactsGateway {
  const FlutterDeviceContactsGateway();

  @override
  Future<DeviceContactsResult> loadContacts() async {
    final permission = await Permission.contacts.request();
    if (!permission.isGranted) return const DeviceContactsResult.denied();

    final contacts = await FlutterContacts.getAll(
      properties: <ContactProperty>{ContactProperty.phone},
    );
    return DeviceContactsResult(
      permissionGranted: true,
      contacts: contacts
          .map(
            (contact) => DeviceContactRecord(
              displayName: contact.displayName ?? '',
              phones: contact.phones.map((phone) => phone.number).toList(),
            ),
          )
          .toList(),
    );
  }
}

class UserServiceMessengerUserLookup implements MessengerUserLookup {
  const UserServiceMessengerUserLookup(this._userService);

  final UserService _userService;

  @override
  Future<String?> findUserIdByPhone(String phone) async {
    final profiles = await _userService.searchUser(phone: phone);
    return profiles.isEmpty ? null : profiles.first.id;
  }
}
