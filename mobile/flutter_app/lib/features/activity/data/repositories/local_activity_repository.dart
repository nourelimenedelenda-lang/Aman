import '../../../incidents/domain/entities/incident.dart';
import '../../../incidents/domain/repositories/incident_repository.dart';
import '../../domain/repositories/activity_repository.dart';

class LocalActivityRepository implements ActivityRepository {
  const LocalActivityRepository(this._incidents);

  final IncidentRepository _incidents;

  @override
  Future<List<Incident>> getIncidents() => _incidents.getAll();
}
