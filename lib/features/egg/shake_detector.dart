import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// One detected shake of the device.
class Shake {
  const Shake({required this.strength, required this.direction});

  /// 1.0 at the detection threshold, growing with a harder shake.
  final double strength;

  /// -1 when the device moved left, 1 when it moved right.
  final double direction;
}

/// Turns raw accelerometer samples into discrete shake events.
///
/// Samples are gravity-free, so a device at rest reads near zero however it is
/// being held.
class ShakeDetector {
  ShakeDetector({Stream<UserAccelerometerEvent>? samples})
    : _samples =
          samples ??
          userAccelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval,
          );

  /// Acceleration, in m/s^2, that counts as a shake rather than handling.
  static const _threshold = 12.0;

  /// Acceleration beyond which a harder shake no longer reads as harder.
  static const _saturation = 30.0;

  /// One physical shake spans several samples; report only the first.
  static const _cooldown = Duration(milliseconds: 260);

  final Stream<UserAccelerometerEvent> _samples;
  final StreamController<Shake> _shakes = StreamController<Shake>.broadcast();

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  DateTime? _lastShakeAt;

  Stream<Shake> get shakes => _shakes.stream;

  void start() {
    _subscription ??= _samples.listen(
      _onSample,
      // Sensor failures are the platform's to report, not ours to swallow.
      onError: _shakes.addError,
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _shakes.close();
  }

  void _onSample(UserAccelerometerEvent sample) {
    final magnitude = math.sqrt(
      sample.x * sample.x + sample.y * sample.y + sample.z * sample.z,
    );
    if (magnitude < _threshold) {
      return;
    }

    final lastShakeAt = _lastShakeAt;
    if (lastShakeAt != null &&
        sample.timestamp.difference(lastShakeAt) < _cooldown) {
      return;
    }
    _lastShakeAt = sample.timestamp;

    _shakes.add(
      Shake(
        strength: (magnitude / _threshold).clamp(1.0, _saturation / _threshold),
        direction: sample.x.isNegative ? -1.0 : 1.0,
      ),
    );
  }
}
