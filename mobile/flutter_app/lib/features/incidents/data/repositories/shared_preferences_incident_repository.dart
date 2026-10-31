import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/incident.dart';
import '../../domain/repositories/incident_repository.dart';

class SharedPreferencesIncidentRepository implements IncidentRepository {
  SharedPreferencesIncidentRepository(this._preferences);

  static const _storageKey = 'resqroad.incidents.v1';
  final SharedPreferences _preferences;

  @override
  Future<List<Incident>> getAll() async {
    final encoded = _preferences.getString(_storageKey);
    if (encoded == null) return const [];

    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException(
        'Stored incident list has an invalid format.',
      );
    }
    return decoded.map((item) {
      if (item is! Map) {
        throw const FormatException('Stored incident has an invalid format.');
      }
      return Incident.fromJson(Map<String, Object?>.from(item));
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> add(Incident incident) async {
    final incidents = await getAll();
    final updated = [
      incident,
      ...incidents.where((item) => item.id != incident.id),
    ];
    final saved = await _preferences.setString(
      _storageKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('The incident could not be saved to this device.');
    }
  }
}
