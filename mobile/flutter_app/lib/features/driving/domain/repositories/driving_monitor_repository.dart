import '../entities/driving_monitor_event.dart';

abstract interface class DrivingMonitorRepository {
  Future<Stream<DrivingMonitorEvent>> start({
    required String emergencyContactPhone,
  });

  Future<void> cancelAccidentCountdown();
  Future<void> stop();
}
