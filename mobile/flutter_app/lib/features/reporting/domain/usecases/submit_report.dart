import '../../../incidents/domain/entities/incident.dart';
import '../repositories/report_submission_repository.dart';

class SubmitReport {
  const SubmitReport(this._repository);

  final ReportSubmissionRepository _repository;

  Future<void> call(Incident incident) => _repository.submit(incident);
}
