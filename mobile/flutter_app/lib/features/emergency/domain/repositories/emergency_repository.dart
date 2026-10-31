import '../../../incidents/domain/entities/incident.dart';
import '../../../location/domain/entities/current_location.dart';

abstract interface class EmergencyRepository {
  Future<Incident> recordSimulatedAlert(CurrentLocation? location);
}
