import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  void startAccelerometer(void Function(AccelerometerEvent event) onEvent) {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream().listen(onEvent);
  }

  Future<void> stopAccelerometer() async {
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }
}
