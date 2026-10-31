import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/emergency_contact.dart';
import '../../domain/entities/profile_settings.dart';
import '../../domain/repositories/profile_repository.dart';

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({
    required FirebaseAuth authentication,
    required FirebaseFirestore firestore,
  }) : _authentication = authentication,
       _firestore = firestore;

  final FirebaseAuth _authentication;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _profile {
    final user = _authentication.currentUser;
    if (user == null) {
      throw StateError('Sign in before accessing profile settings.');
    }
    return _firestore.collection('users').doc(user.uid);
  }

  @override
  Future<ProfileSettings> getSettings() async {
    final snapshot = await _profile.get();
    final data = snapshot.data()?['settings'];
    if (data is! Map) return ProfileSettings.empty;
    final settings = Map<String, dynamic>.from(data);
    final rawContacts = settings['contacts'];
    final contacts = rawContacts is List
        ? rawContacts
              .whereType<Map>()
              .map(
                (contact) => EmergencyContact.fromJson(
                  Map<String, dynamic>.from(contact),
                ),
              )
              .toList()
        : <EmergencyContact>[];
    return ProfileSettings(
      contacts: contacts,
      accidentDetection: settings['accidentDetection'] as bool? ?? true,
      notifications: settings['notifications'] as bool? ?? true,
      impactSound: settings['impactSound'] as bool? ?? false,
    );
  }

  @override
  Future<bool> hasSavedSettings() async {
    final snapshot = await _profile.get();
    return snapshot.data()?['settings'] is Map;
  }

  @override
  Future<void> saveSettings(ProfileSettings settings) async {
    await _profile.set({
      'settings': {
        'contacts': settings.contacts
            .map((contact) => contact.toJson())
            .toList(),
        'accidentDetection': settings.accidentDetection,
        'notifications': settings.notifications,
        'impactSound': settings.impactSound,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
