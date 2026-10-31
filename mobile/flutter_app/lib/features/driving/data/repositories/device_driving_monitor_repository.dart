import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../domain/entities/accident_confidence_scorer.dart';
import '../../domain/entities/driving_monitor_event.dart';
import '../../domain/entities/driving_sensor_reading.dart';
import '../../domain/repositories/driving_monitor_repository.dart';

const _safeNotificationButtonId = 'driver_safe';

@pragma('vm:entry-point')
void startDrivingMonitorTask() {
  FlutterForegroundTask.setTaskHandler(DrivingMonitorTaskHandler());
}

class DrivingMonitorTaskHandler extends TaskHandler {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  AccidentConfidenceScorer? _scorer;
  Position? _previousPosition;
  DateTime? _lastSentAt;
  AccidentResponse? _lastResponse;
  Timer? _countdownTimer;
  DateTime? _countdownDeadline;
  String? _emergencyContactPhone;
  bool _pendingCountdownStart = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _scorer = AccidentConfidenceScorer();
    _previousPosition = null;
    _countdownDeadline = null;
    try {
      _subscriptions.add(
        userAccelerometerEventStream().listen(
          (event) => _sendReading(
            _scorer!.addAccelerometerSample(
              x: event.x,
              y: event.y,
              z: event.z,
              capturedAt: DateTime.now(),
            ),
          ),
          onError: (Object error, StackTrace stackTrace) =>
              _sendError('Accelerometer stream failed: $error'),
        ),
      );
      _subscriptions.add(
        gyroscopeEventStream().listen(
          (event) => _sendReading(
            _scorer!.addGyroscopeSample(
              x: event.x,
              y: event.y,
              z: event.z,
              capturedAt: DateTime.now(),
            ),
          ),
          onError: (Object error, StackTrace stackTrace) =>
              _sendError('Gyroscope stream failed: $error'),
        ),
      );
      _subscriptions.add(
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        ).listen(
          _onPosition,
          onError: (Object error, StackTrace stackTrace) =>
              _sendError('GPS stream failed: $error'),
        ),
      );
      FlutterForegroundTask.sendDataToMain({'type': 'started'});
    } catch (error) {
      _sendError('Could not start background sensor monitoring: $error');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    final subscriptions = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    _scorer = null;
    _previousPosition = null;
    _countdownDeadline = null;
    _pendingCountdownStart = false;
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    switch (data['type']) {
      case 'configure_emergency_contact':
        final phone = data['phone'];
        if (phone is String && phone.trim().isNotEmpty) {
          _emergencyContactPhone = phone.trim();
          if (_pendingCountdownStart) {
            _pendingCountdownStart = false;
            _startAccidentCountdown();
          }
        }
      case 'cancel_accident_countdown':
        _cancelAccidentCountdown();
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == _safeNotificationButtonId) _cancelAccidentCountdown();
  }

  @override
  void onNotificationPressed() {
    if (_countdownDeadline != null) FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {}

  void _onPosition(Position position) {
    if (position.accuracy > 50 || position.speed < 0 || _scorer == null) {
      return;
    }

    final previous = _previousPosition;
    _previousPosition = position;
    final capturedAt = DateTime.now();
    if (previous != null) {
      final elapsed =
          position.timestamp.difference(previous.timestamp).inMicroseconds /
          1000000;
      if (elapsed < 0.5 || elapsed > 10) {
        _sendReading(
          _scorer!.addPositionSample(
            speedMetersPerSecond: position.speed,
            latitude: position.latitude,
            longitude: position.longitude,
            capturedAt: capturedAt,
            includeSpeedChange: false,
          ),
        );
        return;
      }
      final impliedSpeed =
          Geolocator.distanceBetween(
            previous.latitude,
            previous.longitude,
            position.latitude,
            position.longitude,
          ) /
          elapsed;
      if (impliedSpeed > 70 ||
          (position.speedAccuracy > 0 && position.speedAccuracy > 10)) {
        return;
      }
    }

    _sendReading(
      _scorer!.addPositionSample(
        speedMetersPerSecond: position.speed,
        latitude: position.latitude,
        longitude: position.longitude,
        capturedAt: capturedAt,
      ),
    );
  }

  void _sendReading(DrivingSensorReading reading) {
    final now = DateTime.now();
    final responseChanged = reading.response != _lastResponse;
    if (!responseChanged &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!) < const Duration(milliseconds: 250)) {
      return;
    }

    _lastSentAt = now;
    _lastResponse = reading.response;
    FlutterForegroundTask.sendDataToMain({
      'type': 'reading',
      'reading': reading.toJson(),
    });

    if (responseChanged) {
      if (_countdownDeadline != null) {
        _updateCountdown();
      } else if (reading.response == AccidentResponse.confirmation) {
        _startAccidentCountdown();
      } else {
        unawaited(
          FlutterForegroundTask.updateService(
            notificationTitle: 'ResQRoad driving monitor is active',
            notificationText:
                'Location and motion sensors are being monitored.',
            notificationButtons: const [
              NotificationButton(
                id: _safeNotificationButtonId,
                text: "I'm safe",
              ),
            ],
          ),
        );
      }
    }
  }

  void _startAccidentCountdown() {
    if (_countdownDeadline != null) return;
    final phone = _emergencyContactPhone;
    if (phone == null) {
      _pendingCountdownStart = true;
      return;
    }

    _countdownDeadline = DateTime.now().add(const Duration(seconds: 15));
    _updateCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  void _updateCountdown() {
    final deadline = _countdownDeadline;
    final phone = _emergencyContactPhone;
    if (deadline == null || phone == null) return;

    final millisecondsRemaining = deadline
        .difference(DateTime.now())
        .inMilliseconds;
    if (millisecondsRemaining <= 0) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      _countdownDeadline = null;
      _pendingCountdownStart = false;
      FlutterForegroundTask.sendDataToMain({
        'type': 'accident_countdown_expired',
        'phone': phone,
      });
      unawaited(
        FlutterForegroundTask.updateService(
          notificationTitle: 'Accident check-in timed out',
          notificationText: 'Opening the emergency contact dialer.',
          notificationButtons: const [],
        ),
      );
      FlutterForegroundTask.launchApp('/');
      return;
    }

    final secondsRemaining = (millisecondsRemaining / 1000).ceil();
    FlutterForegroundTask.sendDataToMain({
      'type': 'accident_countdown',
      'secondsRemaining': secondsRemaining,
      'phone': phone,
    });
    unawaited(
      FlutterForegroundTask.updateService(
        notificationTitle: 'Possible accident · $secondsRemaining seconds',
        notificationText:
            "Tap “I'm safe” to cancel. Otherwise ResQRoad opens the contact dialer.",
        notificationButtons: const [
          NotificationButton(id: _safeNotificationButtonId, text: "I'm safe"),
        ],
      ),
    );
  }

  void _cancelAccidentCountdown() {
    if (_countdownDeadline == null) {
      _pendingCountdownStart = false;
      return;
    }
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownDeadline = null;
    FlutterForegroundTask.sendDataToMain({
      'type': 'accident_countdown_cancelled',
    });
    unawaited(
      FlutterForegroundTask.updateService(
        notificationTitle: 'ResQRoad driving monitor is active',
        notificationText: 'Location and motion sensors are being monitored.',
        notificationButtons: const [
          NotificationButton(id: _safeNotificationButtonId, text: "I'm safe"),
        ],
      ),
    );
  }

  void _sendError(String message) {
    FlutterForegroundTask.sendDataToMain({'type': 'error', 'message': message});
  }
}

class DeviceDrivingMonitorRepository implements DrivingMonitorRepository {
  DeviceDrivingMonitorRepository();

  final _controller = StreamController<DrivingMonitorEvent>.broadcast();
  bool _isRunning = false;
  String? _emergencyContactPhone;

  @override
  Future<Stream<DrivingMonitorEvent>> start({
    required String emergencyContactPhone,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Persistent driving monitoring is currently supported on Android only.',
      );
    }
    if (_isRunning) {
      throw StateError('Driving sensor monitoring is already active.');
    }

    var notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      notificationPermission =
          await FlutterForegroundTask.requestNotificationPermission();
    }
    if (notificationPermission != NotificationPermission.granted) {
      throw StateError(
        'Notification permission is required to show the active driving monitor.',
      );
    }

    _emergencyContactPhone = emergencyContactPhone;
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    final result = await FlutterForegroundTask.startService(
      serviceId: 2841,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'ResQRoad driving monitor is active',
      notificationText: 'Location and motion sensors are being monitored.',
      notificationButtons: const [
        NotificationButton(id: _safeNotificationButtonId, text: "I'm safe"),
      ],
      notificationInitialRoute: '/',
      callback: startDrivingMonitorTask,
    );
    if (result case ServiceRequestFailure(:final error)) {
      FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
      _emergencyContactPhone = null;
      throw StateError(
        'Could not start the Android foreground service: $error',
      );
    }

    _isRunning = true;
    return _controller.stream;
  }

  void _onTaskData(Object data) {
    if (data is! Map) {
      _controller.addError(
        const FormatException('Received invalid data from driving service.'),
      );
      return;
    }

    switch (data['type']) {
      case 'reading':
        try {
          final json = Map<String, Object?>.from(data['reading'] as Map);
          _controller.add(
            DrivingSensorEvent(DrivingSensorReading.fromJson(json)),
          );
        } catch (error, stackTrace) {
          _controller.addError(
            FormatException('Could not read driving sensor data: $error'),
            stackTrace,
          );
        }
      case 'error':
        _controller.addError(
          StateError(data['message']?.toString() ?? 'Driving service failed.'),
        );
      case 'started':
        final phone = _emergencyContactPhone;
        if (phone != null) {
          FlutterForegroundTask.sendDataToTask({
            'type': 'configure_emergency_contact',
            'phone': phone,
          });
        }
        break;
      case 'accident_countdown':
        _controller.add(
          AccidentCountdownEvent(
            remainingSeconds: (data['secondsRemaining'] as num).toInt(),
            contactPhone: data['phone'] as String,
          ),
        );
      case 'accident_countdown_cancelled':
        _controller.add(const AccidentCountdownCancelledEvent());
      case 'accident_countdown_expired':
        _controller.add(AccidentCountdownExpiredEvent(data['phone'] as String));
      default:
        _controller.addError(
          FormatException('Unknown driving service message: ${data['type']}'),
        );
    }
  }

  @override
  Future<void> cancelAccidentCountdown() async {
    if (_isRunning) {
      FlutterForegroundTask.sendDataToTask({
        'type': 'cancel_accident_countdown',
      });
    }
  }

  @override
  Future<void> stop() async {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    if (await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.stopService();
      if (result case ServiceRequestFailure(:final error)) {
        throw StateError(
          'Could not stop the Android foreground service: $error',
        );
      }
    }
    _isRunning = false;
    _emergencyContactPhone = null;
  }
}
