import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../incidents/domain/entities/incident.dart';
import '../../location/domain/entities/current_location.dart';
import '../../location/presentation/widgets/location_map.dart';

class DetectionScreen extends StatelessWidget {
  const DetectionScreen({
    super.key,
    required this.countdown,
    required this.onCancel,
    this.sensorTriggered = false,
    this.contactName,
  });

  final int countdown;
  final VoidCallback onCancel;
  final bool sensorTriggered;
  final String? contactName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.orange),
                  Text(
                    'ACCIDENT DETECTION',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.red,
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 25),
              Text(
                sensorTriggered
                    ? 'POSSIBLE ACCIDENT DETECTED'
                    : 'EMERGENCY CHECK-IN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                sensorTriggered
                    ? countdown > 0
                          ? 'Opening ${contactName ?? 'your emergency contact'} dialer in $countdown seconds. Tap below if you are safe. You must still confirm the call on your phone.'
                          : 'The countdown has ended. Confirm the call in your phone app if you need help.'
                    : 'This is a prototype countdown only. It cannot detect crashes or contact emergency services.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 116,
                width: 116,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 116,
                      width: 116,
                      child: CircularProgressIndicator(
                        value: countdown / 15,
                        color: AppColors.orange,
                        backgroundColor: Colors.white12,
                        strokeWidth: 6,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$countdown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'SECONDS',
                          style: TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(
                'I’m safe — cancel alert',
                style: AppButtonStyle.secondary,
                icon: Icons.check,
                onPressed: onCancel,
              ),
              const SizedBox(height: 9),
              Text(
                sensorTriggered
                    ? 'A phone call is not placed automatically.'
                    : 'Prototype only · No real emergency services will be contacted.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SentScreen extends StatelessWidget {
  const SentScreen({
    super.key,
    required this.incident,
    required this.location,
    required this.onDetails,
    required this.onHome,
  });

  final Incident incident;
  final CurrentLocation? location;
  final VoidCallback onDetails;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final coordinateText = location?.coordinates ?? 'Unavailable';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.shield_outlined, color: AppColors.orange),
                Text(
                  'INCIDENT UPDATE',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.green,
              child: Icon(Icons.check, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 14),
            const Text(
              'SIMULATED ALERT SAVED',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Incident information recorded',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'This incident was saved to this device. No emergency service or remote server received it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Card(
              color: AppColors.canvas,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _IncidentInfo(label: 'Incident ID', value: incident.id),
                    _IncidentInfo(
                      label: 'Recorded',
                      value: incident.date.toLocal().toString(),
                    ),
                    _IncidentInfo(label: 'GPS location', value: coordinateText),
                    _IncidentInfo(
                      label: 'Accuracy',
                      value: location == null
                          ? 'Unavailable'
                          : '±${location!.accuracyMeters.round()} metres',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            LocationMap(location: location),
            const SizedBox(height: 14),
            const Text(
              'For an actual emergency, contact your local emergency services directly.',
              style: TextStyle(
                color: AppColors.red,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            AppButton('Add incident details', onPressed: onDetails),
            const SizedBox(height: 8),
            AppButton('Return to home', onPressed: onHome),
          ],
        ),
      ),
    );
  }
}

class _IncidentInfo extends StatelessWidget {
  const _IncidentInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog();

  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  String _injuries = 'Unknown';
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Additional incident details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Anyone visibly injured?'),
            Wrap(
              children: ['Yes', 'No', 'Unknown']
                  .map(
                    (answer) => ChoiceChip(
                      label: Text(answer),
                      selected: answer == _injuries,
                      onSelected: (_) => setState(() => _injuries = answer),
                    ),
                  )
                  .toList(),
            ),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Optional description',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop('Injuries: $_injuries. ${_description.text.trim()}');
          },
          child: const Text('Save locally'),
        ),
      ],
    );
  }
}

Future<String?> showEmergencyDetailsDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const _DetailsDialog(),
  );
}
