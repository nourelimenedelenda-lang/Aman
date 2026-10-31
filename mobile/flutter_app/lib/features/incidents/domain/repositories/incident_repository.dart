import '../entities/incident.dart';

abstract interface class IncidentRepository {
  Future<List<Incident>> getAll();

  Future<void> add(Incident incident);
}
