import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/emergency_contact.dart';
import '../../domain/entities/profile_settings.dart';
import '../../domain/repositories/profile_repository.dart';

class SharedPreferencesProfileRepository implements ProfileRepository {
  SharedPreferencesProfileRepository(this._preferences);

  static const _contactsKey = 'resqroad.profile.contacts.v1';
  static const _detectionKey = 'resqroad.profile.detection.v1';
  static const _notificationsKey = 'resqroad.profile.notifications.v1';
  static const _impactSoundKey = 'resqroad.profile.impactSound.v1';

  final SharedPreferences _preferences;

  @override
  Future<ProfileSettings> getSettings() async {
    final contactsJson = _preferences.getString(_contactsKey);
    final contacts = contactsJson == null
        ? <EmergencyContact>[]
        : (jsonDecode(contactsJson) as List)
              .map(
                (item) => EmergencyContact.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
    return ProfileSettings(
      contacts: contacts,
      accidentDetection: _preferences.getBool(_detectionKey) ?? true,
      notifications: _preferences.getBool(_notificationsKey) ?? true,
      impactSound: _preferences.getBool(_impactSoundKey) ?? false,
    );
  }

  @override
  Future<bool> hasSavedSettings() async =>
      _preferences.containsKey(_contactsKey) ||
      _preferences.containsKey(_detectionKey) ||
      _preferences.containsKey(_notificationsKey) ||
      _preferences.containsKey(_impactSoundKey);

  @override
  Future<void> saveSettings(ProfileSettings settings) async {
    final results = await Future.wait([
      _preferences.setString(
        _contactsKey,
        jsonEncode(
          settings.contacts.map((contact) => contact.toJson()).toList(),
        ),
      ),
      _preferences.setBool(_detectionKey, settings.accidentDetection),
      _preferences.setBool(_notificationsKey, settings.notifications),
      _preferences.setBool(_impactSoundKey, settings.impactSound),
    ]);
    if (results.any((saved) => !saved)) {
      throw StateError('Profile settings could not be saved to this device.');
    }
  }
}
