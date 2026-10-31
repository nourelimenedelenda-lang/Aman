import 'dart:math' as math;

import 'driving_sensor_reading.dart';

class AccidentConfidenceScorer {
  static const _signalLifetime = Duration(seconds: 4);

  double _accelerationMagnitude = 0;
  double _gyroscopeMagnitude = 0;
  double? _speed;
  double? _previousPositionSpeed;
  DateTime? _previousPositionAt;
  double? _speedChange;
  double? _latitude;
  double? _longitude;
  double _impactSignal = 0;
  double _rotationSignal = 0;
  double _speedChangeSignal = 0;
  DateTime? _impactAt;
  DateTime? _rotationAt;
  DateTime? _speedChangeAt;
  DateTime _capturedAt = DateTime.now();

  DrivingSensorReading addAccelerometerSample({
    required double x,
    required double y,
    required double z,
    required DateTime capturedAt,
  }) {
    _capturedAt = capturedAt;
    _accelerationMagnitude = _magnitude(x, y, z);
    final impact = _normalize(_accelerationMagnitude, 3, 25);
    if (impact >= _decayed(_impactSignal, _impactAt)) {
      _impactSignal = impact;
      _impactAt = capturedAt;
    }
    return _reading();
  }

  DrivingSensorReading addGyroscopeSample({
    required double x,
    required double y,
    required double z,
    required DateTime capturedAt,
  }) {
    _capturedAt = capturedAt;
    _gyroscopeMagnitude = _magnitude(x, y, z);
    final rotation = _normalize(_gyroscopeMagnitude, 1, 7);
    if (rotation >= _decayed(_rotationSignal, _rotationAt)) {
      _rotationSignal = rotation;
      _rotationAt = capturedAt;
    }
    return _reading();
  }

  DrivingSensorReading addPositionSample({
    required double speedMetersPerSecond,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
    bool includeSpeedChange = true,
  }) {
    _capturedAt = capturedAt;
    _latitude = latitude;
    _longitude = longitude;

    final previousSpeed = _previousPositionSpeed;
    final previousCapturedAt = _previousPositionAt;
    final elapsedSeconds = previousCapturedAt == null
        ? 0
        : capturedAt.difference(previousCapturedAt).inMicroseconds / 1000000;
    if (includeSpeedChange &&
        previousSpeed != null &&
        elapsedSeconds >= 0.5 &&
        elapsedSeconds <= 10) {
      _speedChange =
          (speedMetersPerSecond - previousSpeed).abs() / elapsedSeconds;
      _speedChangeSignal = _normalize(_speedChange!, 2, 8);
      _speedChangeAt = capturedAt;
    } else {
      _speedChange = null;
    }
    _speed = speedMetersPerSecond;
    _previousPositionSpeed = speedMetersPerSecond;
    _previousPositionAt = capturedAt;
    return _reading();
  }

  DrivingSensorReading _reading() {
    final impact = _decayed(_impactSignal, _impactAt);
    final rotation = _decayed(_rotationSignal, _rotationAt);
    final speedChange = _decayed(_speedChangeSignal, _speedChangeAt);
    final score =
        100 * (0.40 * impact + 0.25 * rotation + 0.25 * speedChange + 0.10 * 0);

    return DrivingSensorReading(
      accelerationMagnitude: _accelerationMagnitude,
      gyroscopeMagnitude: _gyroscopeMagnitude,
      speedMetersPerSecond: _speed,
      speedChangeMetersPerSecondSquared: _speedChange,
      latitude: _latitude,
      longitude: _longitude,
      impactSignal: impact,
      rotationSignal: rotation,
      speedChangeSignal: speedChange,
      confidence: score.round().clamp(0, 100),
      capturedAt: _capturedAt,
    );
  }

  double _decayed(double signal, DateTime? capturedAt) {
    if (capturedAt == null) return 0;
    final age = _capturedAt.difference(capturedAt);
    if (age.isNegative || age >= _signalLifetime) return 0;
    return signal * (1 - age.inMicroseconds / _signalLifetime.inMicroseconds);
  }

  double _normalize(double value, double baseline, double maximum) =>
      ((value - baseline) / (maximum - baseline)).clamp(0, 1);

  double _magnitude(double x, double y, double z) =>
      math.sqrt(x * x + y * y + z * z);
}
