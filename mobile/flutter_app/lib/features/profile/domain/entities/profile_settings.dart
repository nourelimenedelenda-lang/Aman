import 'emergency_contact.dart';

class ProfileSettings {
  const ProfileSettings({
    required this.contacts,
    required this.accidentDetection,
    required this.notifications,
    required this.impactSound,
  });

  final List<EmergencyContact> contacts;
  final bool accidentDetection;
  final bool notifications;
  final bool impactSound;

  ProfileSettings copyWith({
    List<EmergencyContact>? contacts,
    bool? accidentDetection,
    bool? notifications,
    bool? impactSound,
  }) {
    return ProfileSettings(
      contacts: contacts ?? this.contacts,
      accidentDetection: accidentDetection ?? this.accidentDetection,
      notifications: notifications ?? this.notifications,
      impactSound: impactSound ?? this.impactSound,
    );
  }

  static const empty = ProfileSettings(
    contacts: [],
    accidentDetection: true,
    notifications: true,
    impactSound: false,
  );
}
