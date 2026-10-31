import '../../../incidents/domain/repositories/incident_repository.dart';
import '../../domain/entities/home_summary.dart';
import '../../domain/repositories/home_repository.dart';

class IncidentHomeRepository implements HomeRepository {
  IncidentHomeRepository(this._incidents);

  final IncidentRepository _incidents;

  @override
  Future<HomeSummary> getSummary() async {
    final incidents = await _incidents.getAll();
    return HomeSummary(
      total: incidents.length,
      active: incidents
          .where((incident) => incident.status != 'Resolved')
          .length,
    );
  }
}
