import 'package:aman/features/driving/domain/entities/accident_confidence_scorer.dart';
import 'package:aman/features/driving/domain/entities/driving_sensor_reading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'combines impact, rotation, and speed signals with prototype weights',
    () {
      final scorer = AccidentConfidenceScorer();
      final start = DateTime(2026, 10, 30, 12);

      scorer.addPositionSample(
        speedMetersPerSecond: 0,
        latitude: 33.5,
        longitude: -7.6,
        capturedAt: start,
      );
      final eventAt = start.add(const Duration(seconds: 1));
      scorer.addAccelerometerSample(x: 28, y: 0, z: 0, capturedAt: eventAt);
      scorer.addGyroscopeSample(x: 8, y: 0, z: 0, capturedAt: eventAt);
      final reading = scorer.addPositionSample(
        speedMetersPerSecond: 8,
        latitude: 33.5,
        longitude: -7.6,
        capturedAt: eventAt,
      );

      expect(reading.confidence, 90);
      expect(reading.supportingSignal, 0);
      expect(reading.response, AccidentResponse.confirmation);
    },
  );

  test('maps scores to monitoring and suspicious response tiers', () {
    final scorer = AccidentConfidenceScorer();
    final time = DateTime(2026, 10, 30, 12);
    final reading = scorer.addAccelerometerSample(
      x: 15,
      y: 0,
      z: 0,
      capturedAt: time,
    );

    expect(reading.confidence, inInclusiveRange(0, 39));
    expect(reading.response, AccidentResponse.monitoring);

    final suspicious = scorer.addGyroscopeSample(
      x: 7,
      y: 0,
      z: 0,
      capturedAt: time,
    );
    expect(suspicious.confidence, inInclusiveRange(40, 69));
    expect(suspicious.response, AccidentResponse.suspicious);
  });

  test('transient sensor signals expire after the evidence window', () {
    final scorer = AccidentConfidenceScorer();
    final time = DateTime(2026, 10, 30, 12);
    scorer.addAccelerometerSample(x: 28, y: 0, z: 0, capturedAt: time);

    final reading = scorer.addGyroscopeSample(
      x: 0,
      y: 0,
      z: 0,
      capturedAt: time.add(const Duration(seconds: 5)),
    );

    expect(reading.impactSignal, 0);
    expect(reading.confidence, 0);
  });
}
