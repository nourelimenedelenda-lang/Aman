import 'driving_sensor_reading.dart';

sealed class DrivingMonitorEvent {
  const DrivingMonitorEvent();
}

class DrivingSensorEvent extends DrivingMonitorEvent {
  const DrivingSensorEvent(this.reading);

  final DrivingSensorReading reading;
}

class AccidentCountdownEvent extends DrivingMonitorEvent {
  const AccidentCountdownEvent({
    required this.remainingSeconds,
    required this.contactPhone,
  });

  final int remainingSeconds;
  final String contactPhone;
}

class AccidentCountdownCancelledEvent extends DrivingMonitorEvent {
  const AccidentCountdownCancelledEvent();
}

class AccidentCountdownExpiredEvent extends DrivingMonitorEvent {
  const AccidentCountdownExpiredEvent(this.contactPhone);

  final String contactPhone;
}
