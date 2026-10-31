import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../features/incidents/domain/entities/incident.dart';
import '../../location/domain/entities/current_location.dart';
import '../../location/presentation/widgets/location_map.dart';
import '../domain/repositories/report_photo_repository.dart';
import '../domain/usecases/submit_report.dart';

String _newReportId() => 'RQR-${Random().nextInt(90000) + 10000}';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.location,
    required this.onLocate,
    required this.submitReport,
    required this.photoRepository,
    this.onReportSaved,
    this.pickImage,
  });

  final CurrentLocation? location;
  final VoidCallback onLocate;
  final SubmitReport submitReport;
  final ReportPhotoRepository photoRepository;
  final ValueChanged<Incident>? onReportSaved;
  final Future<XFile?> Function(ImageSource source)? pickImage;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const _types = ['Serious accident', 'Minor accident', 'Road hazard'];

  int _step = 1;
  String? _type;
  int _vehicles = 1;
  bool _saving = false;
  bool _photoLoading = false;
  String? _saveError;
  String? _photoError;
  Uint8List? _photoBytes;
  String? _photoFileName;
  String _draftId = _newReportId();
  String _injury = 'Unknown';
  String _blocked = 'Unknown';
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final location = widget.location;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final photoPath = _photoBytes == null
          ? null
          : await widget.photoRepository.savePhoto(
              incidentId: _draftId,
              bytes: _photoBytes!,
              fileName: _photoFileName ?? 'report-photo.jpg',
            );
      final incident = Incident(
        id: _draftId,
        type: _type ?? 'Manual report',
        date: DateTime.now(),
        location: location?.address ?? 'Location unavailable',
        method: 'Manual',
        status: 'Awaiting Review',
        color: 'orange',
        latitude: location?.latitude,
        longitude: location?.longitude,
        description: _description.text.trim(),
        vehicles: _vehicles,
        photoPath: photoPath,
      );
      await widget.submitReport(incident);
      widget.onReportSaved?.call(incident);
      if (mounted) {
        _description.clear();
        setState(() {
          _step = 1;
          _type = null;
          _vehicles = 1;
          _injury = 'Unknown';
          _blocked = 'Unknown';
          _photoBytes = null;
          _photoFileName = null;
          _draftId = _newReportId();
          _saveError = null;
          _photoError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report saved and added to your activity.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saveError = 'Could not save your report: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _selectPhoto(ImageSource source) async {
    setState(() {
      _photoLoading = true;
      _photoError = null;
    });
    try {
      final pickImage = widget.pickImage;
      final image = pickImage != null
          ? await pickImage(source)
          : await ImagePicker().pickImage(
              source: source,
              imageQuality: 85,
              maxWidth: 2000,
            );
      if (image == null) {
        return;
      }
      final fileName = image.name.isEmpty ? 'report-photo.jpg' : image.name;
      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() {
          _photoBytes = bytes;
          _photoFileName = fileName;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _photoError = 'Could not add photo: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _photoLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'What are you reporting?',
      'Tell us what happened',
      'Confirm the location',
      'Add helpful evidence',
      'Review your report',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
      children: [
        Text(
          'MANUAL REPORT',
          style: const TextStyle(
            color: AppColors.orange,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          titles[_step - 1],
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        const Text(
          'Quick, clear information helps responders assess the situation.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        Row(
          children: List.generate(
            5,
            (index) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index == 4 ? 0 : 6),
                decoration: BoxDecoration(
                  color: index < _step ? AppColors.orange : AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (_step == 1) _typeSelection(),
        if (_step == 2) _incidentDetails(),
        if (_step == 3) _locationStep(),
        if (_step == 4) _evidenceStep(),
        if (_step == 5) _reviewStep(),
        if (_saveError != null) ...[
          const SizedBox(height: 12),
          Text(_saveError!, style: const TextStyle(color: AppColors.red)),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            if (_step > 1) ...[
              Expanded(
                flex: 2,
                child: AppButton(
                  'Back',
                  style: AppButtonStyle.secondary,
                  onPressed: _saving ? null : () => setState(() => _step--),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 4,
              child: AppButton(
                _saving
                    ? 'Saving…'
                    : _step == 5
                    ? 'Submit report'
                    : 'Continue',
                onPressed: _saving || _photoLoading
                    ? null
                    : _step == 5
                    ? _submit
                    : () => setState(() => _step++),
                disabled: _step == 1 && _type == null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _typeSelection() {
    const descriptions = [
      'Multiple vehicles, injuries, or blocked road',
      'Low-impact collision with no visible danger',
      'Debris, broken signals, or unsafe conditions',
    ];
    const icons = [
      Icons.sos_outlined,
      Icons.directions_car_outlined,
      Icons.warning_amber_rounded,
    ];
    return Column(
      children: List.generate(_types.length, (index) {
        final type = _types[index];
        final selected = type == _type;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            color: selected ? const Color(0xFFFFFAF7) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: selected ? AppColors.orange : AppColors.line,
              ),
            ),
            child: ListTile(
              onTap: () => setState(() => _type = type),
              leading: Icon(
                icons[index],
                color: index == 0 ? AppColors.red : AppColors.orange,
              ),
              title: Text(
                type,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(descriptions[index]),
              trailing: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.orange : AppColors.muted,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _incidentDetails() {
    return _FormCard(
      children: [
        const Text(
          'Vehicles involved',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () =>
                  setState(() => _vehicles = max(1, _vehicles - 1)),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$_vehicles',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            IconButton(
              onPressed: () => setState(() => _vehicles++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        _choice(
          'Is anyone visibly injured?',
          ['Yes', 'No', 'Unknown'],
          _injury,
          (v) => setState(() => _injury = v),
        ),
        _choice(
          'Is the road blocked?',
          ['Fully blocked', 'Partially blocked', 'Not blocked', 'Unknown'],
          _blocked,
          (v) => setState(() => _blocked = v),
        ),
      ],
    );
  }

  Widget _locationStep() {
    final location = widget.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocationMap(
          location: location,
          height: 270,
          showLocateButton: true,
          onLocate: widget.onLocate,
        ),
        const SizedBox(height: 12),
        if (location != null)
          _FormCard(
            children: [
              Text(
                location.addressUnavailable
                    ? 'Address unavailable'
                    : location.address,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${location.coordinates} · ±${location.accuracyMeters.round()} m',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          )
        else
          _FormCard(
            children: [
              const Text(
                'Location has not been captured',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              const Text(
                'You can try GPS now or submit without attaching coordinates.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: widget.onLocate,
                icon: const Icon(Icons.my_location),
                label: const Text('Use current location'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _evidenceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_photoBytes case final photoBytes?)
          ClipRRect(
            key: const ValueKey('report-photo-preview'),
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(
              photoBytes,
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 110,
                alignment: Alignment.center,
                color: AppColors.redSoft,
                child: const Text('Saved photo preview is unavailable.'),
              ),
            ),
          )
        else
          Container(
            height: 125,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: _photoLoading
                  ? const CircularProgressIndicator()
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.orange,
                          size: 30,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add a photo of the incident',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Optional evidence',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _photoLoading
                  ? null
                  : () => _selectPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose photo'),
            ),
            OutlinedButton.icon(
              onPressed: _photoLoading
                  ? null
                  : () => _selectPhoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Take photo'),
            ),
            if (_photoBytes != null)
              TextButton.icon(
                onPressed: _photoLoading
                    ? null
                    : () => setState(() {
                        _photoBytes = null;
                        _photoFileName = null;
                      }),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
          ],
        ),
        if (_photoError != null)
          Text(
            _photoError!,
            style: const TextStyle(color: AppColors.red, fontSize: 12),
          ),
        const SizedBox(height: 18),
        const Text('Additional observations · Optional'),
        const SizedBox(height: 8),
        TextField(
          controller: _description,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText:
                'Describe details that may help, such as vehicle colors or nearby landmarks…',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final location = widget.location;
    return _FormCard(
      children: [
        _ReviewLine(label: 'Report type', value: _type ?? 'Manual report'),
        _ReviewLine(
          label: 'Location',
          value: location?.address ?? 'Not shared',
        ),
        _ReviewLine(label: 'Vehicles', value: '$_vehicles'),
        _ReviewLine(label: 'Visible injuries', value: _injury),
        _ReviewLine(label: 'Road status', value: _blocked),
        if (_photoBytes != null)
          const _ReviewLine(label: 'Photo', value: 'Attached'),
        const SizedBox(height: 8),
        const Text(
          'This report is saved on this device only. No emergency service or remote server is contacted.',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _choice(
    String label,
    List<String> options,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 5,
            children: options
                .map(
                  (option) => ChoiceChip(
                    label: Text(option, style: const TextStyle(fontSize: 10)),
                    selected: option == value,
                    onSelected: (_) => onChanged(option),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
