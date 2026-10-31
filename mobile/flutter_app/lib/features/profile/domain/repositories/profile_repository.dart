import '../entities/profile_settings.dart';

abstract interface class ProfileRepository {
  Future<ProfileSettings> getSettings();

  Future<bool> hasSavedSettings();

  Future<void> saveSettings(ProfileSettings settings);
}
