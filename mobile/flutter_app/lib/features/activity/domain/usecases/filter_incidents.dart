import '../../../incidents/domain/entities/incident.dart';

class FilterIncidents {
  const FilterIncidents();

  List<Incident> call(List<Incident> incidents, String filter) {
    return incidents.where((incident) {
      return switch (filter) {
        'Automatic' => incident.method == 'Automatic',
        'Manual' => incident.method == 'Manual',
        'Active' => incident.status != 'Resolved',
        'Resolved' => incident.status == 'Resolved',
        _ => true,
      };
    }).toList();
  }
}
