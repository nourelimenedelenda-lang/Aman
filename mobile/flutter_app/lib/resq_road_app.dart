import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'core/theme/app_theme.dart';
import 'features/authentication/domain/entities/authenticated_user.dart';
import 'features/authentication/domain/repositories/authentication_repository.dart';
import 'features/authentication/presentation/authentication_screen.dart';
import 'features/incidents/domain/repositories/incident_repository.dart';
import 'features/driving/domain/repositories/driving_monitor_repository.dart';
import 'features/location/domain/repositories/location_repository.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/reporting/domain/repositories/report_photo_repository.dart';
import 'features/shell/presentation/app_shell.dart';

class ResQRoadApp extends StatelessWidget {
  const ResQRoadApp({
    super.key,
    required this.incidents,
    required this.locations,
    required this.profile,
    required this.drivingMonitor,
    this.authentication,
    this.onAuthenticated,
    this.launchDialer,
    this.reportPhotoRepository,
    this.pickReportImage,
  });

  final IncidentRepository incidents;
  final LocationRepository locations;
  final ProfileRepository profile;
  final DrivingMonitorRepository drivingMonitor;
  final AuthenticationRepository? authentication;
  final Future<void> Function(String uid)? onAuthenticated;
  final Future<bool> Function(Uri uri)? launchDialer;
  final ReportPhotoRepository? reportPhotoRepository;
  final Future<XFile?> Function(ImageSource source)? pickReportImage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQRoad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: authentication == null
          ? _appShell()
          : _AuthenticationGate(
              authentication: authentication!,
              onAuthenticated: onAuthenticated,
              appShellBuilder: (user) => AppShell(
                incidents: incidents,
                locations: locations,
                profile: profile,
                drivingMonitor: drivingMonitor,
                account: user,
                onSignOut: authentication!.signOut,
                launchDialer: launchDialer,
                reportPhotoRepository: reportPhotoRepository,
                pickReportImage: pickReportImage,
              ),
            ),
    );
  }

  Widget _appShell() => AppShell(
    incidents: incidents,
    locations: locations,
    profile: profile,
    drivingMonitor: drivingMonitor,
    launchDialer: launchDialer,
    reportPhotoRepository: reportPhotoRepository,
    pickReportImage: pickReportImage,
  );
}

class _AuthenticationGate extends StatefulWidget {
  const _AuthenticationGate({
    required this.authentication,
    required this.appShellBuilder,
    this.onAuthenticated,
  });

  final AuthenticationRepository authentication;
  final Future<void> Function(String uid)? onAuthenticated;
  final Widget Function(AuthenticatedUser user) appShellBuilder;

  @override
  State<_AuthenticationGate> createState() => _AuthenticationGateState();
}

class _AuthenticationGateState extends State<_AuthenticationGate> {
  late Stream<AuthenticatedUser?> _authChanges;
  String? _syncingUid;
  Future<void>? _sync;

  @override
  void initState() {
    super.initState();
    _authChanges = widget.authentication.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthenticatedUser?>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _GateMessage(
            message: 'Could not check your sign-in status: ${snapshot.error}',
            onRetry: () => setState(
              () => _authChanges = widget.authentication.authStateChanges(),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _GateLoading();
        }
        final user = snapshot.data;
        if (user == null) {
          _syncingUid = null;
          _sync = null;
          return AuthenticationScreen(repository: widget.authentication);
        }
        if (_syncingUid != user.uid) {
          _syncingUid = user.uid;
          _sync = widget.onAuthenticated?.call(user.uid) ?? Future.value();
        }
        return FutureBuilder<void>(
          future: _sync,
          builder: (context, syncSnapshot) {
            if (syncSnapshot.hasError) {
              return _GateMessage(
                message:
                    'Could not sync this device’s existing data: ${syncSnapshot.error}',
                onRetry: () => setState(() {
                  _syncingUid = null;
                  _sync = null;
                }),
              );
            }
            if (syncSnapshot.connectionState != ConnectionState.done) {
              return const _GateLoading(message: 'Syncing your existing data…');
            }
            return widget.appShellBuilder(user);
          },
        );
      },
    );
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading({this.message = 'Loading ResQRoad…'});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(message),
        ],
      ),
    ),
  );
}

class _GateMessage extends StatelessWidget {
  const _GateMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}
