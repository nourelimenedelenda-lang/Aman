import '../../../incidents/domain/entities/incident.dart';
import '../../../incidents/domain/repositories/incident_repository.dart';
import '../../../location/domain/entities/current_location.dart';
import '../../domain/repositories/emergency_repository.dart';

class LocalEmergencyRepository implements EmergencyRepository {
  const LocalEmergencyRepository(this._incidents);

  final IncidentRepository _incidents;

  @override
  Future<Incident> recordSimulatedAlert(CurrentLocation? location) async {
    final incident = Incident(
      id: 'RQR-${DateTime.now().microsecondsSinceEpoch % 100000}',
      type: 'Impact detected',
      date: DateTime.now(),
      location: location?.address ?? 'Location unavailable',
      method: 'Automatic',
      status: 'Simulated alert recorded locally',
      color: 'red',
      latitude: location?.latitude,
      longitude: location?.longitude,
    );
    await _incidents.add(incident);
    return incident;
  }
}
