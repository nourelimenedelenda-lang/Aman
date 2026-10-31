import 'package:shared_preferences/shared_preferences.dart';

import '../../../incidents/domain/repositories/incident_repository.dart';
import '../../../profile/domain/repositories/profile_repository.dart';

class LocalDataMigrator {
  LocalDataMigrator({
    required SharedPreferences preferences,
    required IncidentRepository localIncidents,
    required IncidentRepository cloudIncidents,
    required ProfileRepository localProfile,
    required ProfileRepository cloudProfile,
  }) : _preferences = preferences,
       _localIncidents = localIncidents,
       _cloudIncidents = cloudIncidents,
       _localProfile = localProfile,
       _cloudProfile = cloudProfile;

  final SharedPreferences _preferences;
  final IncidentRepository _localIncidents;
  final IncidentRepository _cloudIncidents;
  final ProfileRepository _localProfile;
  final ProfileRepository _cloudProfile;

  Future<void> migrate(String uid) async {
    const marker = 'resqroad.firestoreMigration.v2.completed';
    const ownerKey = 'resqroad.firebaseMigration.v1.ownerUid';
    if (_preferences.getBool(marker) == true) return;
    final previousOwner = _preferences.getString(ownerKey);
    if (previousOwner != null && previousOwner != uid) {
      throw StateError(
        'This device has local data from another account. Sign in with that account to sync it.',
      );
    }
    if (previousOwner == null && !await _preferences.setString(ownerKey, uid)) {
      throw StateError('The local-data sync could not be started.');
    }

    for (final incident in await _localIncidents.getAll()) {
      await _cloudIncidents.add(incident);
    }
    if (await _localProfile.hasSavedSettings() &&
        !await _cloudProfile.hasSavedSettings()) {
      await _cloudProfile.saveSettings(await _localProfile.getSettings());
    }
    if (!await _preferences.setBool(marker, true)) {
      throw StateError('The completed local-data sync could not be recorded.');
    }
  }
}
