import '../../../incidents/domain/entities/incident.dart';
import '../../../incidents/domain/repositories/incident_repository.dart';
import '../../domain/repositories/report_submission_repository.dart';

class LocalReportSubmissionRepository implements ReportSubmissionRepository {
  const LocalReportSubmissionRepository(this._incidents);

  final IncidentRepository _incidents;

  @override
  Future<void> submit(Incident incident) => _incidents.add(incident);
}
