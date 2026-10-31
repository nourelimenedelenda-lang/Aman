import '../../../incidents/domain/entities/incident.dart';

abstract interface class ReportSubmissionRepository {
  Future<void> submit(Incident incident);
}
