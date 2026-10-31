import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../activity/data/repositories/local_activity_repository.dart';
import '../../activity/presentation/activity_screen.dart';
import '../../emergency/data/repositories/local_emergency_repository.dart';
import '../../emergency/domain/usecases/record_simulated_alert.dart';
import '../../emergency/presentation/emergency_screens.dart';
import '../../driving/domain/entities/driving_monitor_event.dart';
import '../../driving/domain/entities/driving_sensor_reading.dart';
import '../../driving/domain/repositories/driving_monitor_repository.dart';
import '../../home/data/repositories/incident_home_repository.dart';
import '../../home/presentation/home_screen.dart';
import '../../home/domain/entities/home_summary.dart';
import '../../authentication/domain/entities/authenticated_user.dart';
import '../../incidents/domain/entities/incident.dart';
import '../../incidents/domain/repositories/incident_repository.dart';
import '../../incidents/presentation/incident_details_sheet.dart';
import '../../location/domain/entities/current_location.dart';
import '../../location/domain/repositories/location_repository.dart';
import '../../profile/domain/repositories/profile_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../reporting/data/repositories/local_report_submission_repository.dart';
import '../../reporting/data/repositories/local_report_photo_repository.dart';
import '../../reporting/domain/repositories/report_photo_repository.dart';
import '../../reporting/domain/usecases/submit_report.dart';
import '../../reporting/presentation/report_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.incidents,
    required this.locations,
    required this.profile,
    required this.drivingMonitor,
    this.account,
    this.onSignOut,
    this.launchDialer,
    this.reportPhotoRepository,
    this.pickReportImage,
  });

  final IncidentRepository incidents;
  final LocationRepository locations;
  final ProfileRepository profile;
  final DrivingMonitorRepository drivingMonitor;
  final AuthenticatedUser? account;
  final Future<void> Function()? onSignOut;
  final Future<bool> Function(Uri uri)? launchDialer;
  final ReportPhotoRepository? reportPhotoRepository;
  final Future<XFile?> Function(ImageSource source)? pickReportImage;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _driving = false;
  bool _appInForeground = true;
  bool _accidentCountdown = false;
  bool _locationLoading = false;
  bool _handlingAccidentTimeout = false;
  int _countdown = 15;
  String _emergency = 'idle';
  String? _emergencyFailureMessage;
  String? _primaryContactName;
  String? _pendingDialerPhone;
  String? _locationError;
  String? _drivingError;
  String? _dataError;
  CurrentLocation? _location;
  Incident? _lastAlert;
  List<Incident> _incidents = const [];
  DrivingSensorReading? _sensorReading;
  StreamSubscription<DrivingMonitorEvent>? _drivingSubscription;
  DateTime? _lastSensorUiUpdate;
  late final _activityRepository = LocalActivityRepository(widget.incidents);
  late final _homeRepository = IncidentHomeRepository(widget.incidents);
  late Future<HomeSummary> _homeSummary;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeSummary = _homeRepository.getSummary();
    unawaited(_loadIncidents());
    unawaited(_refreshLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_drivingSubscription?.cancel());
    unawaited(widget.drivingMonitor.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (_appInForeground && _emergency == 'dialing' && mounted) {
      setState(() => _emergency = 'idle');
    }
    final phone = _pendingDialerPhone;
    if (_appInForeground && phone != null) {
      _pendingDialerPhone = null;
      unawaited(_openEmergencyContactDialer(phone));
    }
  }

  Future<void> _setDrivingMode(bool enabled) async {
    if (!enabled) {
      await _stopDriving();
      return;
    }
    if (_driving) return;

    try {
      final settings = await widget.profile.getSettings();
      if (!mounted) return;
      if (settings.contacts.isEmpty ||
          settings.contacts.first.phone.trim().isEmpty) {
        const message =
            'Add a primary emergency contact in Profile before starting driving mode.';
        setState(() => _drivingError = message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(message)));
        return;
      }
      final contact = settings.contacts.first;

      final access = await widget.locations.requestAccess();
      if (!mounted) return;
      if (access != LocationAccessStatus.granted) {
        final message = switch (access) {
          LocationAccessStatus.denied =>
            'Allow location permission to start driving monitoring.',
          LocationAccessStatus.permanentlyDenied =>
            'Enable location permission in device settings before starting.',
          LocationAccessStatus.servicesDisabled =>
            'Turn on device location services before starting.',
          LocationAccessStatus.granted => '',
        };
        setState(() => _drivingError = message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final stream = await widget.drivingMonitor.start(
        emergencyContactPhone: contact.phone,
      );
      if (!mounted) {
        await widget.drivingMonitor.stop();
        return;
      }
      _drivingSubscription = stream.listen(
        _onMonitorEvent,
        onError: (Object error, StackTrace stackTrace) {
          if (mounted) setState(() => _drivingError = error.toString());
        },
      );
      setState(() {
        _driving = true;
        _drivingError = null;
        _sensorReading = null;
        _lastSensorUiUpdate = null;
        _primaryContactName = contact.name;
      });
      unawaited(_refreshLocation());
    } catch (error) {
      if (mounted) {
        setState(
          () => _drivingError = 'Could not start sensor monitoring: $error',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_drivingError!)));
      }
    }
  }

  Future<void> _stopDriving() async {
    try {
      await _drivingSubscription?.cancel();
      _drivingSubscription = null;
      await widget.drivingMonitor.stop();
      if (mounted) {
        setState(() {
          _driving = false;
          _sensorReading = null;
          _lastSensorUiUpdate = null;
          _drivingError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _drivingError = 'Could not stop monitoring: $error');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_drivingError!)));
      }
    }
  }

  void _onMonitorEvent(DrivingMonitorEvent event) {
    switch (event) {
      case DrivingSensorEvent(:final reading):
        _onSensorReading(reading);
      case AccidentCountdownEvent(:final remainingSeconds):
        if (mounted) {
          setState(() {
            _accidentCountdown = true;
            _countdown = remainingSeconds;
            _emergency = 'detected';
          });
        }
      case AccidentCountdownCancelledEvent():
        if (mounted && _accidentCountdown) {
          setState(() {
            _accidentCountdown = false;
            _emergency = 'idle';
          });
        }
      case AccidentCountdownExpiredEvent(:final contactPhone):
        unawaited(_handleAccidentCountdownExpired(contactPhone));
    }
  }

  void _onSensorReading(DrivingSensorReading reading) {
    if (!mounted) return;
    final previous = _sensorReading;
    final now = DateTime.now();
    final shouldRefresh =
        _lastSensorUiUpdate == null ||
        now.difference(_lastSensorUiUpdate!) >=
            const Duration(milliseconds: 250);
    if (shouldRefresh || previous?.response != reading.response) {
      setState(() {
        _sensorReading = reading;
        _lastSensorUiUpdate = now;
      });
    } else {
      _sensorReading = reading;
    }
  }

  Future<void> _loadIncidents() async {
    try {
      final incidents = await _activityRepository.getIncidents();
      if (mounted) {
        setState(() {
          _incidents = incidents;
          _homeSummary = _homeRepository.getSummary();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _dataError = 'Could not load saved reports: $error');
      }
    }
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    try {
      final location = await widget.locations.getCurrentLocation();
      if (mounted) setState(() => _location = location);
    } catch (error) {
      if (mounted) setState(() => _locationError = error.toString());
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _saveIncident(Incident incident) async {
    await widget.incidents.add(incident);
    if (mounted) {
      setState(() {
        _incidents = [
          incident,
          ..._incidents.where((item) => item.id != incident.id),
        ];
        _dataError = null;
        _homeSummary = _homeRepository.getSummary();
      });
    }
  }

  void _onReportSaved(Incident incident) {
    if (!mounted) return;
    setState(() {
      _incidents = [
        incident,
        ..._incidents.where((item) => item.id != incident.id),
      ];
      _dataError = null;
      _homeSummary = _homeRepository.getSummary();
    });
  }

  Future<void> _handleAccidentCountdownExpired(String phone) async {
    if (!mounted || _handlingAccidentTimeout) return;
    _handlingAccidentTimeout = true;
    try {
      final incident = await RecordSimulatedAlert(
        LocalEmergencyRepository(widget.incidents),
      )(_location);
      if (mounted) {
        setState(() {
          _incidents = [
            incident,
            ..._incidents.where((item) => item.id != incident.id),
          ];
          _lastAlert = incident;
          _homeSummary = _homeRepository.getSummary();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _dataError = 'Could not save the detected incident: $error',
        );
      }
    } finally {
      _handlingAccidentTimeout = false;
    }

    if (!mounted) return;
    if (_appInForeground) {
      unawaited(_openEmergencyContactDialer(phone));
    } else {
      _pendingDialerPhone = phone;
    }
  }

  void _startEmergency() {
    _timer?.cancel();
    _accidentCountdown = false;
    unawaited(_stopDriving());
    setState(() {
      _countdown = 15;
      _emergency = 'detected';
      _emergencyFailureMessage = null;
      _lastAlert = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _emergency != 'detected') {
        timer.cancel();
      } else if (_countdown <= 1) {
        timer.cancel();
        unawaited(_recordAlert());
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _recordAlert() async {
    setState(() {
      _countdown = 0;
      _emergency = 'saving';
    });
    try {
      final incident = await RecordSimulatedAlert(
        LocalEmergencyRepository(widget.incidents),
      )(_location);
      if (!mounted) return;
      setState(() {
        _incidents = [incident, ..._incidents];
        _lastAlert = incident;
        _emergency = 'sent';
        _homeSummary = _homeRepository.getSummary();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _dataError = 'Could not save simulated alert: $error';
          _emergencyFailureMessage =
              'The simulated incident could not be saved.';
          _emergency = 'failed';
        });
      }
    }
  }

  void _cancelAlert() {
    _timer?.cancel();
    setState(() {
      _emergency = 'idle';
    });
    unawaited(_stopDriving());
  }

  void _cancelAccidentCountdown() {
    unawaited(widget.drivingMonitor.cancelAccidentCountdown());
    setState(() {
      _accidentCountdown = false;
      _emergency = 'idle';
    });
  }

  Future<void> _openEmergencyContactDialer(String phone) async {
    if (!mounted) return;
    setState(() {
      _accidentCountdown = false;
      _emergency = 'dialing';
    });

    try {
      final uri = Uri(scheme: 'tel', path: phone);
      final opened =
          await (widget.launchDialer?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (mounted && !opened) {
        setState(() {
          _emergency = 'failed';
          _emergencyFailureMessage =
              'Could not open the phone dialer for ${_primaryContactName ?? 'your emergency contact'}.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _emergency = 'failed';
          _emergencyFailureMessage = 'Could not open the phone dialer: $error';
        });
      }
    }
  }

  void _openIncident(Incident incident) {
    showIncidentDetails(
      context,
      incident,
      photoRepository:
          widget.reportPhotoRepository ?? const LocalReportPhotoRepository(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_emergency == 'detected') {
      return DetectionScreen(
        countdown: _countdown,
        onCancel: _accidentCountdown ? _cancelAccidentCountdown : _cancelAlert,
        sensorTriggered: _accidentCountdown,
        contactName: _primaryContactName,
      );
    }
    if (_emergency == 'dialing') {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.phone_in_talk,
                  size: 48,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 12),
                Text(
                  'Opening ${_primaryContactName ?? 'emergency contact'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Confirm the call in your phone app. ResQRoad does not place calls automatically.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _emergency = 'idle'),
                  child: const Text('Return to ResQRoad'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_emergency == 'saving') {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_emergency == 'failed') {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The emergency action could not be completed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _emergencyFailureMessage ??
                      _dataError ??
                      'Unknown emergency action error',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() {
                    _emergency = 'idle';
                    _emergencyFailureMessage = null;
                  }),
                  child: const Text('Return to ResQRoad'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_emergency == 'sent' && _lastAlert != null) {
      return SentScreen(
        incident: _lastAlert!,
        location: _location,
        onDetails: _addEmergencyDetails,
        onHome: () => setState(() {
          _emergency = 'idle';
          _driving = false;
          _tab = 0;
        }),
      );
    }

    final pages = <Widget>[
      HomeScreen(
        incidents: _incidents,
        summary: _homeSummary,
        location: _location,
        locationError: _locationError,
        locationLoading: _locationLoading,
        driving: _driving,
        sensorReading: _sensorReading,
        drivingError: _drivingError,
        onDrivingChanged: (value) => unawaited(_setDrivingMode(value)),
        onRefreshLocation: () => unawaited(_refreshLocation()),
        onReport: () => setState(() => _tab = 1),
        onSos: _startEmergency,
        onIncident: _openIncident,
        onViewActivity: () => setState(() => _tab = 2),
      ),
      ReportScreen(
        location: _location,
        onLocate: () => unawaited(_refreshLocation()),
        photoRepository:
            widget.reportPhotoRepository ?? const LocalReportPhotoRepository(),
        pickImage: widget.pickReportImage,
        onReportSaved: _onReportSaved,
        submitReport: SubmitReport(
          LocalReportSubmissionRepository(widget.incidents),
        ),
      ),
      ActivityScreen(
        incidents: _incidents,
        photoRepository:
            widget.reportPhotoRepository ?? const LocalReportPhotoRepository(),
      ),
      ProfileScreen(
        repository: widget.profile,
        locations: widget.locations,
        onLocationAccessChanged: () => unawaited(_refreshLocation()),
        accountName: widget.account?.displayName,
        accountEmail: widget.account?.email,
        onSignOut: widget.onSignOut == null
            ? null
            : () async {
                await _stopDriving();
                await widget.onSignOut!();
              },
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(index: _tab, children: pages),
            ),
            if (_dataError != null)
              Positioned(
                left: 12,
                right: 12,
                top: 4,
                child: Material(
                  color: AppColors.redSoft,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      _dataError!,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> _addEmergencyDetails() async {
    final details = await showEmergencyDetailsDialog(context);
    if (details == null || _lastAlert == null) return;
    final old = _lastAlert!;
    final updated = Incident(
      id: old.id,
      type: old.type,
      date: old.date,
      location: old.location,
      method: old.method,
      status: old.status,
      color: old.color,
      latitude: old.latitude,
      longitude: old.longitude,
      description: details,
      vehicles: old.vehicles,
      photoPath: old.photoPath,
    );
    try {
      await _saveIncident(updated);
      if (mounted) setState(() => _lastAlert = updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save incident details: $error')),
        );
      }
    }
  }
}
