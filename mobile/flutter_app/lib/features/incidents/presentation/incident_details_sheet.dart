import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/entities/incident.dart';
import '../../reporting/domain/repositories/report_photo_repository.dart';
import 'widgets/incident_photo.dart';
import 'widgets/incident_widgets.dart';
import '../../location/domain/entities/current_location.dart';
import '../../location/presentation/widgets/location_map.dart';

void showIncidentDetails(
  BuildContext context,
  Incident incident, {
  ReportPhotoRepository? photoRepository,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                incident.id,
                style: const TextStyle(color: AppColors.orange, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                incident.type,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              IncidentStatusPill(incident: incident),
              const SizedBox(height: 14),
              if (incident.latitude != null && incident.longitude != null)
                LocationMap(
                  height: 210,
                  location: CurrentLocation(
                    latitude: incident.latitude!,
                    longitude: incident.longitude!,
                    accuracyMeters: 0,
                    capturedAt: incident.date,
                    address: incident.location,
                  ),
                )
              else
                const Text(
                  'No GPS coordinates were attached to this report.',
                  style: TextStyle(color: AppColors.muted),
                ),
              const SizedBox(height: 12),
              _Detail(
                label: 'Reported',
                value: incident.date.toLocal().toString(),
              ),
              _Detail(label: 'Method', value: '${incident.method} report'),
              _Detail(label: 'Location', value: incident.location),
              _Detail(
                label: 'Vehicles involved',
                value: '${incident.vehicles}',
              ),
              if (incident.description.isNotEmpty)
                _Detail(label: 'Description', value: incident.description),
              if (incident.photoPath case final photoPath?)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attached photo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: IncidentPhoto(
                          key: const ValueKey('activity-incident-photo'),
                          path: photoPath,
                          photoRepository: photoRepository,
                          height: 220,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}
