import 'package:aman/features/incidents/data/repositories/shared_preferences_incident_repository.dart';
import 'package:aman/features/incidents/domain/entities/incident.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists and restores reports with their GPS coordinates', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesIncidentRepository(preferences);
    final reportedAt = DateTime(2026, 10, 30, 12);
    final incident = Incident(
      id: 'RQR-81234',
      type: 'Road hazard',
      date: reportedAt,
      location: 'Casablanca',
      method: 'Manual',
      status: 'Awaiting Review',
      color: 'orange',
      latitude: 33.5899,
      longitude: -7.6039,
      description: 'Debris in the road',
    );

    await repository.add(incident);

    final restored = await repository.getAll();
    expect(restored, hasLength(1));
    expect(restored.single.id, incident.id);
    expect(restored.single.latitude, incident.latitude);
    expect(restored.single.longitude, incident.longitude);
    expect(restored.single.description, incident.description);
    expect(restored.single.date, reportedAt);
  });
}
