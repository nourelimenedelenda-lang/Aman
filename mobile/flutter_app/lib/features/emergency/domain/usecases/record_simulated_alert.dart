import '../../../incidents/domain/entities/incident.dart';
import '../../../location/domain/entities/current_location.dart';
import '../repositories/emergency_repository.dart';

class RecordSimulatedAlert {
  const RecordSimulatedAlert(this._repository);

  final EmergencyRepository _repository;

  Future<Incident> call(CurrentLocation? location) =>
      _repository.recordSimulatedAlert(location);
}
