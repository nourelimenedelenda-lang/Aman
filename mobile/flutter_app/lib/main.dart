import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/authentication/data/repositories/firebase_authentication_repository.dart';
import 'features/authentication/data/services/local_data_migrator.dart';
import 'features/incidents/data/repositories/firestore_incident_repository.dart';
import 'features/incidents/data/repositories/shared_preferences_incident_repository.dart';
import 'features/driving/data/repositories/device_driving_monitor_repository.dart';
import 'features/location/data/repositories/device_location_repository.dart';
import 'features/profile/data/repositories/firestore_profile_repository.dart';
import 'features/profile/data/repositories/shared_preferences_profile_repository.dart';
import 'features/reporting/data/repositories/local_report_photo_repository.dart';
import 'resq_road_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'resqroad_driving_monitor',
      channelName: 'Driving monitor',
      channelDescription:
          'Visible notification while ResQRoad monitors a driving session.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(60000),
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );
  final preferences = await SharedPreferences.getInstance();
  final locations = DeviceLocationRepository();
  final firebaseAuth = FirebaseAuth.instance;
  final localIncidents = SharedPreferencesIncidentRepository(preferences);
  final localProfile = SharedPreferencesProfileRepository(preferences);
  final firestore = FirebaseFirestore.instance;
  final cloudIncidents = FirestoreIncidentRepository(
    authentication: firebaseAuth,
    firestore: firestore,
    localIncidents: localIncidents,
  );
  final cloudProfile = FirestoreProfileRepository(
    authentication: firebaseAuth,
    firestore: firestore,
  );
  final migrator = LocalDataMigrator(
    preferences: preferences,
    localIncidents: localIncidents,
    cloudIncidents: cloudIncidents,
    localProfile: localProfile,
    cloudProfile: cloudProfile,
  );
  runApp(
    ResQRoadApp(
      incidents: cloudIncidents,
      locations: locations,
      profile: cloudProfile,
      drivingMonitor: DeviceDrivingMonitorRepository(),
      authentication: FirebaseAuthenticationRepository(
        authentication: firebaseAuth,
      ),
      onAuthenticated: migrator.migrate,
      reportPhotoRepository: const LocalReportPhotoRepository(),
    ),
  );
}
