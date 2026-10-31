import '../../../incidents/domain/entities/incident.dart';

abstract interface class ActivityRepository {
  Future<List<Incident>> getIncidents();
}
