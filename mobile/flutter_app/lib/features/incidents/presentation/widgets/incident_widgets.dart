import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/incident.dart';

class IncidentAvatar extends StatelessWidget {
  const IncidentAvatar({super.key, required this.incident, this.size = 40});

  final Incident incident;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (color, background, icon) = switch (incident.color) {
      'red' => (AppColors.red, AppColors.redSoft, Icons.sensors),
      'green' => (AppColors.green, AppColors.greenSoft, Icons.check),
      _ => (
        AppColors.orange,
        AppColors.orangeSoft,
        Icons.directions_car_outlined,
      ),
    };
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: background,
      foregroundColor: color,
      child: Icon(icon, size: size * 0.52),
    );
  }
}

class IncidentStatusPill extends StatelessWidget {
  const IncidentStatusPill({super.key, required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (incident.color) {
      'red' => (AppColors.red, AppColors.redSoft),
      'green' => (AppColors.green, AppColors.greenSoft),
      _ => (AppColors.orange, AppColors.orangeSoft),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          incident.status,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String incidentDate(DateTime date) =>
    date.toLocal().toString().substring(0, 16);
