import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_title.dart';
import '../../incidents/domain/entities/incident.dart';
import '../../incidents/presentation/incident_details_sheet.dart';
import '../../incidents/presentation/widgets/incident_widgets.dart';
import '../../reporting/domain/repositories/report_photo_repository.dart';
import '../domain/usecases/filter_incidents.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    required this.incidents,
    this.photoRepository,
  });

  final List<Incident> incidents;
  final ReportPhotoRepository? photoRepository;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const _filters = ['All', 'Automatic', 'Manual', 'Active', 'Resolved'];
  final _filterIncidents = const FilterIncidents();
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final shown = _filterIncidents(widget.incidents, _filter);
    final active = widget.incidents
        .where((item) => item.status != 'Resolved')
        .length;
    final resolved = widget.incidents.length - active;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
      children: [
        const SectionTitle('INCIDENT HISTORY'),
        const Text(
          'Your activity',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        const Text(
          'Reports are stored locally on this device until a backend is configured.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _Summary(
                value: '${widget.incidents.length}',
                label: 'Total reports',
              ),
              _Summary(value: '$active', label: 'Active'),
              _Summary(value: '$resolved', label: 'Resolved'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (shown.isEmpty)
          const _EmptyState()
        else
          ...shown.map(
            (incident) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _IncidentCard(
                incident: incident,
                onTap: () => showIncidentDetails(
                  context,
                  incident,
                  photoRepository: widget.photoRepository,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.onTap});

  final Incident incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  IncidentAvatar(incident: incident),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incident.id,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          incident.type,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              const Divider(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${incident.location}\n${incidentDate(incident.date)} · ${incident.method} report',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: IncidentStatusPill(incident: incident),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Icon(Icons.fact_check_outlined, color: AppColors.muted, size: 40),
          SizedBox(height: 12),
          Text(
            'No reports here',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Reports matching this filter will appear here.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
