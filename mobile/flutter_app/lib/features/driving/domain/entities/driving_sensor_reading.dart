enum AccidentResponse { monitoring, suspicious, confirmation }

class DrivingSensorReading {
  const DrivingSensorReading({
    required this.accelerationMagnitude,
    required this.gyroscopeMagnitude,
    required this.speedMetersPerSecond,
    required this.speedChangeMetersPerSecondSquared,
    required this.latitude,
    required this.longitude,
    required this.impactSignal,
    required this.rotationSignal,
    required this.speedChangeSignal,
    required this.confidence,
    required this.capturedAt,
  });

  final double accelerationMagnitude;
  final double gyroscopeMagnitude;
  final double? speedMetersPerSecond;
  final double? speedChangeMetersPerSecondSquared;
  final double? latitude;
  final double? longitude;
  final double impactSignal;
  final double rotationSignal;
  final double speedChangeSignal;
  final int confidence;
  final DateTime capturedAt;

  double get supportingSignal => 0;

  AccidentResponse get response {
    if (confidence >= 50) return AccidentResponse.confirmation;
    if (confidence >= 40) return AccidentResponse.suspicious;
    return AccidentResponse.monitoring;
  }

  Map<String, Object?> toJson() => {
    'accelerationMagnitude': accelerationMagnitude,
    'gyroscopeMagnitude': gyroscopeMagnitude,
    'speedMetersPerSecond': speedMetersPerSecond,
    'speedChangeMetersPerSecondSquared': speedChangeMetersPerSecondSquared,
    'latitude': latitude,
    'longitude': longitude,
    'impactSignal': impactSignal,
    'rotationSignal': rotationSignal,
    'speedChangeSignal': speedChangeSignal,
    'confidence': confidence,
    'capturedAt': capturedAt.toIso8601String(),
  };

  factory DrivingSensorReading.fromJson(Map<String, Object?> json) {
    return DrivingSensorReading(
      accelerationMagnitude: (json['accelerationMagnitude'] as num).toDouble(),
      gyroscopeMagnitude: (json['gyroscopeMagnitude'] as num).toDouble(),
      speedMetersPerSecond: (json['speedMetersPerSecond'] as num?)?.toDouble(),
      speedChangeMetersPerSecondSquared:
          (json['speedChangeMetersPerSecondSquared'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      impactSignal: (json['impactSignal'] as num).toDouble(),
      rotationSignal: (json['rotationSignal'] as num).toDouble(),
      speedChangeSignal: (json['speedChangeSignal'] as num).toDouble(),
      confidence: (json['confidence'] as num).toInt(),
      capturedAt: DateTime.parse(json['capturedAt'] as String),
    );
  }

  static final initial = DrivingSensorReading(
    accelerationMagnitude: 0,
    gyroscopeMagnitude: 0,
    speedMetersPerSecond: null,
    speedChangeMetersPerSecondSquared: null,
    latitude: null,
    longitude: null,
    impactSignal: 0,
    rotationSignal: 0,
    speedChangeSignal: 0,
    confidence: 0,
    capturedAt: DateTime.now(),
  );
}
