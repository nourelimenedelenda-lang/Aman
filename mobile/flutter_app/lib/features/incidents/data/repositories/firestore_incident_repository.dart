import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/incident.dart';
import '../../domain/repositories/incident_repository.dart';

class FirestoreIncidentRepository implements IncidentRepository {
  FirestoreIncidentRepository({
    required FirebaseAuth authentication,
    required FirebaseFirestore firestore,
    required IncidentRepository localIncidents,
  }) : _authentication = authentication,
       _firestore = firestore,
       _localIncidents = localIncidents;

  final FirebaseAuth _authentication;
  final FirebaseFirestore _firestore;
  final IncidentRepository _localIncidents;

  CollectionReference<Map<String, dynamic>> get _incidents {
    final user = _authentication.currentUser;
    if (user == null) {
      throw StateError('Sign in before accessing incident history.');
    }
    return _firestore.collection('users').doc(user.uid).collection('incidents');
  }

  @override
  Future<List<Incident>> getAll() async {
    final localById = {
      for (final incident in await _localIncidents.getAll())
        incident.id: incident,
    };
    final snapshot = await _incidents.orderBy('date', descending: true).get();
    return snapshot.docs.map((document) {
      final data = Map<String, Object?>.from(document.data());
      data['id'] = document.id;
      final date = data['date'];
      if (date is Timestamp) data['date'] = date.toDate().toIso8601String();
      final incident = Incident.fromJson(data);
      return Incident(
        id: incident.id,
        type: incident.type,
        date: incident.date,
        location: incident.location,
        method: incident.method,
        status: incident.status,
        color: incident.color,
        latitude: incident.latitude,
        longitude: incident.longitude,
        description: incident.description,
        vehicles: incident.vehicles,
        photoPath: localById[incident.id]?.photoPath,
      );
    }).toList();
  }

  @override
  Future<void> add(Incident incident) async {
    await _localIncidents.add(incident);
    final data = incident.toJson();
    data.remove('photoPath');
    data['date'] = Timestamp.fromDate(incident.date);
    await _incidents.doc(incident.id).set(data);
  }
}
