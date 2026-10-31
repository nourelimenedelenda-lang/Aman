import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/driving_sensor_reading.dart';

class DrivingMonitorPanel extends StatelessWidget {
  const DrivingMonitorPanel({
    super.key,
    required this.reading,
    required this.error,
  });

  final DrivingSensorReading? reading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final value = reading;
    final score = value?.confidence ?? 0;
    final response = value?.response ?? AccidentResponse.monitoring;
    final responseColor = switch (response) {
      AccidentResponse.monitoring => AppColors.green,
      AccidentResponse.suspicious => AppColors.orange,
      AccidentResponse.confirmation => AppColors.red,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Live sensor readings',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              if (value == null && error == null)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.sensors, color: AppColors.green, size: 19),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Android background service · prototype, not a certified crash detector',
            style: TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(color: AppColors.red, fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),
          _ReadingRow(
            icon: Icons.vibration,
            label: 'Accelerometer · impact',
            value: value == null
                ? 'Waiting for sensor'
                : '${value.accelerationMagnitude.toStringAsFixed(1)} m/s²',
            signal: value?.impactSignal,
          ),
          _ReadingRow(
            icon: Icons.screen_rotation_alt,
            label: 'Gyroscope · rotation',
            value: value == null
                ? 'Waiting for sensor'
                : '${value.gyroscopeMagnitude.toStringAsFixed(2)} rad/s',
            signal: value?.rotationSignal,
          ),
          _ReadingRow(
            icon: Icons.speed,
            label: 'GPS · vehicle speed',
            value: value?.speedMetersPerSecond == null
                ? 'Waiting for GPS'
                : '${(value!.speedMetersPerSecond! * 3.6).toStringAsFixed(1)} km/h',
            signal: value?.speedChangeSignal,
          ),
          _ReadingRow(
            icon: Icons.graphic_eq,
            label: 'Impact sound · supporting signal',
            value: 'Unavailable · microphone not enabled',
            signal: 0,
          ),
          if (value?.latitude != null && value?.longitude != null) ...[
            const SizedBox(height: 4),
            Text(
              'GPS ${value!.latitude!.toStringAsFixed(5)}, ${value.longitude!.toStringAsFixed(5)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Accident confidence',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
              Text(
                '$score / 100',
                style: TextStyle(
                  color: responseColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              color: responseColor,
              backgroundColor: AppColors.line,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _responseLabel(response, score),
            style: TextStyle(
              color: responseColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Weighted prototype score: 40% impact + 25% rotation + 25% speed change + 10% sound (currently unavailable).',
            style: TextStyle(color: AppColors.muted, fontSize: 9, height: 1.4),
          ),
        ],
      ),
    );
  }

  String _responseLabel(AccidentResponse response, int score) {
    return switch (response) {
      AccidentResponse.monitoring => 'Continue monitoring',
      AccidentResponse.suspicious =>
        'Suspicious event · collecting additional sensor evidence',
      AccidentResponse.confirmation =>
        'Possible accident · confirmation required ($score)',
    };
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.signal,
  });

  final IconData icon;
  final String label;
  final String value;
  final double? signal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          if (signal != null)
            Text(
              '${(signal! * 100).round()}% · $value',
              textAlign: TextAlign.end,
              style: const TextStyle(color: AppColors.muted, fontSize: 9),
            )
          else
            Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: AppColors.muted, fontSize: 9),
            ),
        ],
      ),
    );
  }
}
