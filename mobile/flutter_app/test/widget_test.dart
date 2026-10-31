import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:aman/features/authentication/domain/entities/authenticated_user.dart';
import 'package:aman/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:aman/features/authentication/data/services/local_data_migrator.dart';
import 'package:aman/features/incidents/domain/entities/incident.dart';
import 'package:aman/features/incidents/domain/repositories/incident_repository.dart';
import 'package:aman/features/driving/domain/entities/driving_sensor_reading.dart';
import 'package:aman/features/driving/domain/entities/driving_monitor_event.dart';
import 'package:aman/features/driving/domain/repositories/driving_monitor_repository.dart';
import 'package:aman/features/location/domain/entities/current_location.dart';
import 'package:aman/features/location/domain/repositories/location_repository.dart';
import 'package:aman/features/profile/domain/entities/profile_settings.dart';
import 'package:aman/features/profile/domain/entities/emergency_contact.dart';
import 'package:aman/features/profile/domain/repositories/profile_repository.dart';
import 'package:aman/features/reporting/domain/repositories/report_photo_repository.dart';
import 'package:aman/resq_road_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryIncidentRepository implements IncidentRepository {
  final List<Incident> incidents = [];

  @override
  Future<void> add(Incident incident) async {
    incidents.insert(0, incident);
  }

  @override
  Future<List<Incident>> getAll() async => List.unmodifiable(incidents);
}

class _FakeLocationRepository implements LocationRepository {
  @override
  Future<CurrentLocation> getCurrentLocation() async => CurrentLocation(
    latitude: 33.5899,
    longitude: -7.6039,
    accuracyMeters: 8,
    capturedAt: DateTime(2026, 10, 30),
    address: 'Casablanca',
  );

  @override
  Future<LocationAccessStatus> getAccessStatus() async =>
      LocationAccessStatus.granted;

  @override
  Future<LocationAccessStatus> requestAccess() async =>
      LocationAccessStatus.granted;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _FakeProfileRepository implements ProfileRepository {
  ProfileSettings settings = ProfileSettings(
    contacts: const [
      EmergencyContact(
        name: 'Emergency contact',
        relationship: 'Family',
        phone: '+12125550123',
      ),
    ],
    accidentDetection: true,
    notifications: true,
    impactSound: false,
  );
  bool settingsSaved = false;

  @override
  Future<ProfileSettings> getSettings() async => settings;

  @override
  Future<bool> hasSavedSettings() async => settingsSaved;

  @override
  Future<void> saveSettings(ProfileSettings value) async {
    settings = value;
    settingsSaved = true;
  }
}

class _FakeDrivingMonitorRepository implements DrivingMonitorRepository {
  final controller = StreamController<DrivingMonitorEvent>.broadcast();
  bool active = false;
  int stopCalls = 0;
  bool countdownCancelled = false;
  String? emergencyContactPhone;

  @override
  Future<Stream<DrivingMonitorEvent>> start({
    required String emergencyContactPhone,
  }) async {
    active = true;
    this.emergencyContactPhone = emergencyContactPhone;
    return controller.stream;
  }

  @override
  Future<void> cancelAccidentCountdown() async {
    countdownCancelled = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    active = false;
  }
}

class _FakeReportPhotoRepository implements ReportPhotoRepository {
  int saveCalls = 0;

  @override
  Future<String> savePhoto({
    required String incidentId,
    required List<int> bytes,
    required String fileName,
  }) async {
    saveCalls++;
    return '/temporary/$fileName';
  }

  @override
  Future<Uint8List> loadPhoto(String photoPath) async =>
      Uint8List.fromList([1, 2, 3]);
}

class _FakeAuthenticationRepository implements AuthenticationRepository {
  final _controller = StreamController<AuthenticatedUser?>.broadcast();
  AuthenticatedUser? _currentUser;
  String? registeredEmail;
  String? registeredName;
  String? signedInEmail;
  String? resetEmail;

  @override
  Stream<AuthenticatedUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    registeredName = displayName;
    registeredEmail = email;
    _publishUser(displayName, email);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signedInEmail = email;
    _publishUser('Signed-in Driver', email);
  }

  @override
  Future<void> signInWithGoogle() async =>
      _publishUser('Google Driver', 'google@example.com');

  @override
  Future<void> sendPasswordReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  void _publishUser(String name, String email) {
    _currentUser = AuthenticatedUser(
      uid: 'test-user',
      email: email,
      displayName: name,
    );
    _controller.add(_currentUser);
  }
}

void main() {
  late _MemoryIncidentRepository incidents;
  late _FakeDrivingMonitorRepository drivingMonitor;
  late _FakeReportPhotoRepository reportPhotos;
  Uri? dialerUri;

  Future<void> pumpApp(WidgetTester tester) async {
    incidents = _MemoryIncidentRepository();
    drivingMonitor = _FakeDrivingMonitorRepository();
    reportPhotos = _FakeReportPhotoRepository();
    dialerUri = null;
    await tester.pumpWidget(
      ResQRoadApp(
        incidents: incidents,
        locations: _FakeLocationRepository(),
        profile: _FakeProfileRepository(),
        drivingMonitor: drivingMonitor,
        launchDialer: (uri) async {
          dialerUri = uri;
          return true;
        },
        reportPhotoRepository: reportPhotos,
        pickReportImage: (source) async =>
            XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'accident.jpg'),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the road safety home screen', (tester) async {
    await pumpApp(tester);

    expect(find.text('Hello, Abdelmoumane'), findsOneWidget);
    expect(find.text('Start driving mode'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
  });

  testWidgets('registers, gates the app, and signs out', (tester) async {
    incidents = _MemoryIncidentRepository();
    drivingMonitor = _FakeDrivingMonitorRepository();
    reportPhotos = _FakeReportPhotoRepository();
    final authentication = _FakeAuthenticationRepository();
    await tester.pumpWidget(
      ResQRoadApp(
        incidents: incidents,
        locations: _FakeLocationRepository(),
        profile: _FakeProfileRepository(),
        drivingMonitor: drivingMonitor,
        authentication: authentication,
        reportPhotoRepository: reportPhotos,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.text('New to ResQRoad? Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Driver');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'driver@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'secure123');
    await tester.enterText(find.byType(TextFormField).at(3), 'secure123');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(authentication.registeredName, 'Test Driver');
    expect(authentication.registeredEmail, 'driver@example.com');
    expect(find.text('Start driving mode'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'driver@example.com',
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(authentication.resetEmail, 'driver@example.com');

    await tester.enterText(find.byType(TextFormField).at(1), 'secure123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(authentication.signedInEmail, 'driver@example.com');
    expect(find.text('Start driving mode'), findsOneWidget);
  });

  test('syncs existing local incidents and profile settings once', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final localIncidents = _MemoryIncidentRepository()
      ..incidents.add(
        Incident(
          id: 'RQR-12345',
          type: 'Minor accident',
          date: DateTime(2026, 10, 30),
          location: 'Casablanca',
          method: 'Manual',
          status: 'Awaiting Review',
          color: 'orange',
          photoPath: '/device/photos/accident.jpg',
        ),
      );
    final localProfile = _FakeProfileRepository()..settingsSaved = true;
    final cloudIncidents = _MemoryIncidentRepository();
    final cloudProfile = _FakeProfileRepository();
    final migrator = LocalDataMigrator(
      preferences: preferences,
      localIncidents: localIncidents,
      cloudIncidents: cloudIncidents,
      localProfile: localProfile,
      cloudProfile: cloudProfile,
    );

    await migrator.migrate('first-user');
    await migrator.migrate('first-user');

    expect(cloudIncidents.incidents, hasLength(1));
    expect(cloudProfile.settings.contacts, localProfile.settings.contacts);
    expect(
      preferences.getString('resqroad.firebaseMigration.v1.ownerUid'),
      'first-user',
    );
    expect(
      preferences.getBool('resqroad.firestoreMigration.v2.completed'),
      isTrue,
    );
  });

  testWidgets('driving mode starts live sensor monitoring', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Start driving mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(drivingMonitor.active, isTrue);
    expect(find.text('Live sensor readings'), findsOneWidget);
    expect(find.text('Accelerometer · impact'), findsOneWidget);
    expect(find.text('Gyroscope · rotation'), findsOneWidget);
    expect(find.text('GPS · vehicle speed'), findsOneWidget);
    expect(find.text('Impact sound · supporting signal'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(drivingMonitor.active, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  testWidgets('high confidence starts a countdown that the driver can cancel', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Start driving mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    drivingMonitor.controller.add(
      DrivingSensorEvent(
        DrivingSensorReading(
          accelerationMagnitude: 28,
          gyroscopeMagnitude: 8,
          speedMetersPerSecond: 8,
          speedChangeMetersPerSecondSquared: 8,
          latitude: 33.5,
          longitude: -7.6,
          impactSignal: 1,
          rotationSignal: 1,
          speedChangeSignal: 1,
          confidence: 90,
          capturedAt: DateTime(2026, 10, 30, 12),
        ),
      ),
    );
    await tester.pump();

    drivingMonitor.controller.add(
      const AccidentCountdownEvent(
        remainingSeconds: 15,
        contactPhone: '+12125550123',
      ),
    );
    await tester.pump();

    expect(find.text('15'), findsOneWidget);
    expect(find.textContaining('Are you safe?'), findsNothing);
    expect(
      find.textContaining('Opening Emergency contact dialer in 15 seconds'),
      findsOneWidget,
    );
    expect(drivingMonitor.emergencyContactPhone, '+12125550123');

    await tester.tap(find.text('I’m safe — cancel alert'));
    await tester.pump();
    expect(find.text('15'), findsNothing);
    expect(drivingMonitor.countdownCancelled, isTrue);
    expect(drivingMonitor.active, isTrue);
    expect(drivingMonitor.stopCalls, 0);
    expect(find.text('MONITORING ACTIVE'), findsOneWidget);
  });

  testWidgets('expired countdown opens the primary contact dialer', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Start driving mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    drivingMonitor.controller.add(
      const AccidentCountdownEvent(
        remainingSeconds: 1,
        contactPhone: '+12125550123',
      ),
    );
    await tester.pump();
    drivingMonitor.controller.add(
      const AccidentCountdownExpiredEvent('+12125550123'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.textContaining('Opening Emergency contact'), findsOneWidget);
    expect(dialerUri, Uri(scheme: 'tel', path: '+12125550123'));
    expect(
      find.textContaining('does not place calls automatically'),
      findsOneWidget,
    );
    expect(incidents.incidents, hasLength(1));
    expect(incidents.incidents.single.method, 'Automatic');
    expect(drivingMonitor.active, isTrue);
    expect(drivingMonitor.stopCalls, 0);
  });

  testWidgets('expired countdown waits for app resume before opening dialer', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Start driving mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    drivingMonitor.controller.add(
      const AccidentCountdownExpiredEvent('+12125550123'),
    );
    await tester.pump();

    expect(dialerUri, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(dialerUri, Uri(scheme: 'tel', path: '+12125550123'));
  });

  testWidgets('opens the manual incident report flow', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Report').last);
    await tester.pumpAndSettle();
    expect(find.text('What are you reporting?'), findsOneWidget);

    await tester.tap(find.text('Minor accident'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us what happened'), findsOneWidget);
  });

  testWidgets('submitted report with photo appears in activity', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Report').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minor accident'));
    await tester.pump();

    for (var step = 0; step < 3; step++) {
      await tester.dragFrom(const Offset(400, 450), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Add a photo of the incident'), findsOneWidget);
    await tester.dragFrom(const Offset(400, 450), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(reportPhotos.saveCalls, 0);
    expect(find.byKey(const ValueKey('report-photo-preview')), findsOneWidget);

    await tester.dragFrom(const Offset(400, 450), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 450), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(find.text('What are you reporting?'), findsOneWidget);
    expect(
      find.text('Report saved and added to your activity.'),
      findsOneWidget,
    );
    expect(incidents.incidents, hasLength(1));
    expect(reportPhotos.saveCalls, 1);
    expect(incidents.incidents.single.photoPath, '/temporary/report-photo.jpg');

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(find.text('Your activity'), findsOneWidget);
    expect(find.text('Minor accident'), findsOneWidget);

    await tester.tap(find.text('Minor accident'));
    await tester.pumpAndSettle();
    expect(find.text('Attached photo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity-incident-photo')),
      findsOneWidget,
    );

    Navigator.of(tester.element(find.text('Attached photo'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Recent activity'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minor accident').last);
    await tester.pumpAndSettle();
    expect(find.text('Attached photo'), findsOneWidget);
    expect(find.text('Vehicles involved'), findsOneWidget);
    expect(find.text('Minor accident'), findsNWidgets(2));
  });

  testWidgets('profile restores app settings and location access controls', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('App settings'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Location permissions'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Privacy & data'), findsOneWidget);

    await tester.tap(find.text('Location permissions'));
    await tester.pumpAndSettle();
    expect(find.text('Allowed while using the app'), findsOneWidget);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(
      find.text('ResQRoad is currently available in English.'),
      findsOneWidget,
    );
  });

  testWidgets('adds and saves an emergency contact from the profile', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add emergency contact'), findsOneWidget);
    final inputs = find.byType(TextFormField);
    expect(inputs, findsNWidgets(3));
    await tester.enterText(inputs.at(0), 'Alex Driver');
    await tester.enterText(inputs.at(1), 'Family');
    await tester.enterText(inputs.at(2), '+14155550123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Alex Driver'), findsOneWidget);
    expect(find.text('Family · +14155550123'), findsOneWidget);
  });
}
