import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_title.dart';
import '../../incidents/domain/entities/incident.dart';
import '../../incidents/presentation/widgets/incident_widgets.dart';
import '../../driving/domain/entities/driving_sensor_reading.dart';
import '../../driving/presentation/widgets/driving_monitor_panel.dart';
import '../../location/domain/entities/current_location.dart';
import '../../location/presentation/widgets/location_map.dart';
import '../domain/entities/home_summary.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.incidents,
    required this.summary,
    required this.location,
    required this.locationError,
    required this.locationLoading,
    required this.driving,
    required this.sensorReading,
    required this.drivingError,
    required this.onDrivingChanged,
    required this.onRefreshLocation,
    required this.onReport,
    required this.onSos,
    required this.onIncident,
    required this.onViewActivity,
  });

  final List<Incident> incidents;
  final Future<HomeSummary> summary;
  final CurrentLocation? location;
  final String? locationError;
  final bool locationLoading;
  final bool driving;
  final DrivingSensorReading? sensorReading;
  final String? drivingError;
  final ValueChanged<bool> onDrivingChanged;
  final VoidCallback onRefreshLocation;
  final VoidCallback onReport;
  final VoidCallback onSos;
  final ValueChanged<Incident> onIncident;
  final VoidCallback onViewActivity;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 48, bottom: 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BrandLogo(),
                    SizedBox(height: 18),
                    Text(
                      'GOOD MORNING',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Hello, Abdelmoumane',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const CircleAvatar(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                child: Text('AM'),
              ),
            ],
          ),
        ),
        _DriveCard(driving: driving, onChanged: onDrivingChanged),
        if (driving) ...[
          const SizedBox(height: 12),
          DrivingMonitorPanel(reading: sensorReading, error: drivingError),
        ],
        const SizedBox(height: 26),
        const SectionTitle('Quick actions'),
        Row(
          children: [
            Expanded(
              child: _QuickCard(
                title: 'Report accident',
                subtitle: 'Help someone on the road',
                icon: Icons.assignment_outlined,
                color: AppColors.orange,
                background: AppColors.orangeSoft,
                onTap: onReport,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _QuickCard(
                title: 'Emergency SOS',
                subtitle: 'Request urgent assistance',
                icon: Icons.sos_outlined,
                color: AppColors.red,
                background: AppColors.redSoft,
                onTap: onSos,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        SectionTitle(
          'Your location',
          action: locationLoading ? 'Locating…' : 'Refresh',
          onAction: locationLoading ? null : onRefreshLocation,
        ),
        LocationMap(
          location: location,
          onLocate: onRefreshLocation,
          showLocateButton: true,
        ),
        if (location != null) ...[
          const SizedBox(height: 8),
          Text(
            '${location!.address} · ${location!.coordinates} · ±${location!.accuracyMeters.round()} m',
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ] else if (locationError != null) ...[
          const SizedBox(height: 7),
          Text(
            locationError!,
            style: const TextStyle(color: AppColors.red, fontSize: 11),
          ),
        ] else ...[
          const SizedBox(height: 7),
          const Text(
            'Your current position will appear after location access is granted.',
            style: TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
        const SizedBox(height: 26),
        SectionTitle(
          'Recent activity',
          action: 'View all',
          onAction: onViewActivity,
        ),
        if (incidents.isEmpty)
          _EmptyRecent(onReport: onReport)
        else
          _RecentActivity(
            incidents: incidents.take(2).toList(),
            onIncident: onIncident,
          ),
        const SizedBox(height: 26),
        FutureBuilder<HomeSummary>(
          future: summary,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Could not load the report summary: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.red, fontSize: 10),
                ),
              );
            }
            if (!snapshot.hasData || incidents.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${snapshot.data!.active} active report(s) saved on this device.',
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            );
          },
        ),
        const _SafetyTip(),
      ],
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.white),
        ),
        const SizedBox(width: 9),
        const Text.rich(
          TextSpan(
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
            children: [
              TextSpan(text: 'ResQ'),
              TextSpan(
                text: 'Road',
                style: TextStyle(color: AppColors.orange),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriveCard extends StatelessWidget {
  const _DriveCard({required this.driving, required this.onChanged});

  final bool driving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: driving ? AppColors.orange : Colors.white12,
                child: Icon(
                  driving ? Icons.shield_outlined : Icons.directions_car,
                  color: driving ? Colors.white : const Color(0xFFFB923C),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driving ? 'MONITORING ACTIVE' : 'DRIVING MODE OFF',
                      style: const TextStyle(
                        color: Color(0xFFFDBA74),
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      driving
                          ? 'Monitoring is active'
                          : 'Ready for your next journey?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      driving
                          ? 'Android keeps monitoring with an ongoing notification, even when your screen is locked.'
                          : 'Turn on monitoring before you start driving.',
                      style: const TextStyle(
                        color: Color(0xFFB0B4BA),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => onChanged(!driving),
              child: Text(driving ? 'End driving mode' : 'Start driving mode'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: background,
              foregroundColor: color,
              child: Icon(icon),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.incidents, required this.onIncident});

  final List<Incident> incidents;
  final ValueChanged<Incident> onIncident;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: incidents
          .map(
            (incident) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: IncidentAvatar(incident: incident),
              title: Text(
                incident.type,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${incident.location} · ${_formatDate(incident.date)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => onIncident(incident),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent({required this.onReport});

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No reports saved yet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 5),
          const Text(
            'New reports you submit on this device will appear here.',
            style: TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          TextButton(onPressed: onReport, child: const Text('Create a report')),
        ],
      ),
    );
  }
}

class _SafetyTip extends StatelessWidget {
  const _SafetyTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        border: Border.all(color: const Color(0xFFFED7BD)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.orange,
            child: Icon(Icons.shield_outlined),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Keep your phone secured while driving. Background monitoring is an Android prototype, not a substitute for emergency services.',
              style: TextStyle(fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) => date.toLocal().toString().substring(0, 16);
