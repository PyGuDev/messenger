import 'package:flutter_bloc/flutter_bloc.dart';

class DeviceContactRecord {
  const DeviceContactRecord({
    required this.displayName,
    this.phones = const <String>[],
  });

  final String displayName;
  final List<String> phones;
}

class DeviceContactsResult {
  const DeviceContactsResult({
    required this.permissionGranted,
    this.contacts = const <DeviceContactRecord>[],
  });

  const DeviceContactsResult.denied()
    : permissionGranted = false,
      contacts = const <DeviceContactRecord>[];

  final bool permissionGranted;
  final List<DeviceContactRecord> contacts;
}

abstract interface class DeviceContactsGateway {
  Future<DeviceContactsResult> loadContacts();
}

abstract interface class MessengerUserLookup {
  Future<String?> findUserIdByPhone(String phone);
}

class MatchedContact {
  const MatchedContact({
    required this.name,
    required this.phone,
    required this.userId,
    required this.avatarIndex,
    this.isOnline = true,
  });

  final String name;
  final String phone;
  final String userId;
  final int avatarIndex;
  final bool isOnline;
}

sealed class MatchedContactsState {
  const MatchedContactsState();
}

class MatchedContactsInitial extends MatchedContactsState {
  const MatchedContactsInitial();
}

class MatchedContactsLoading extends MatchedContactsState {
  const MatchedContactsLoading();
}

class MatchedContactsLoaded extends MatchedContactsState {
  const MatchedContactsLoaded(this.contacts, {this.permissionDenied = false});

  final List<MatchedContact> contacts;
  final bool permissionDenied;
}

enum MatchedContactsFailureReason { deviceContactsUnavailable }

class MatchedContactsFailure extends MatchedContactsState {
  const MatchedContactsFailure(this.reason);

  final MatchedContactsFailureReason reason;
}

class MatchedContactsBloc extends Cubit<MatchedContactsState> {
  MatchedContactsBloc(this._deviceContacts, this._userLookup)
    : super(const MatchedContactsInitial());

  final DeviceContactsGateway _deviceContacts;
  final MessengerUserLookup _userLookup;

  Future<void> load() async {
    emit(const MatchedContactsLoading());

    try {
      final result = await _deviceContacts.loadContacts();
      if (!result.permissionGranted) {
        emit(
          const MatchedContactsLoaded(
            <MatchedContact>[],
            permissionDenied: true,
          ),
        );
        return;
      }

      final candidates = <_ContactCandidate>[];
      for (final contact in result.contacts) {
        if (contact.phones.isEmpty) continue;
        candidates.add(
          _ContactCandidate(
            name: contact.displayName,
            phone: contact.phones.first,
            avatarIndex: candidates.length,
          ),
        );
      }

      final matchedContacts = <MatchedContact>[];
      const chunkSize = 10;
      for (var offset = 0; offset < candidates.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, candidates.length);
        final matches = await Future.wait(
          candidates.sublist(offset, end).map(_matchContact),
        );
        matchedContacts.addAll(matches.whereType<MatchedContact>());
      }

      emit(
        MatchedContactsLoaded(
          List<MatchedContact>.unmodifiable(matchedContacts),
        ),
      );
    } catch (_) {
      emit(
        const MatchedContactsFailure(
          MatchedContactsFailureReason.deviceContactsUnavailable,
        ),
      );
    }
  }

  Future<MatchedContact?> _matchContact(_ContactCandidate contact) async {
    try {
      final normalizedPhone = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
      final userId = await _userLookup.findUserIdByPhone(normalizedPhone);
      if (userId == null || userId.isEmpty) return null;
      return MatchedContact(
        name: contact.name,
        phone: contact.phone,
        userId: userId,
        avatarIndex: contact.avatarIndex,
      );
    } catch (_) {
      return null;
    }
  }
}

class _ContactCandidate {
  const _ContactCandidate({
    required this.name,
    required this.phone,
    required this.avatarIndex,
  });

  final String name;
  final String phone;
  final int avatarIndex;
}
