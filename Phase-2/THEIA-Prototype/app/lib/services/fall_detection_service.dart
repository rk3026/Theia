import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';

/// Service for detecting potential falls using accelerometer data
/// Currently a stub implementation - will be enhanced with actual fall detection logic
class FallDetectionService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Function()? _onFallDetected;
  
  bool _isMonitoring = false;
  
  // Fall detection threshold in m/s² (25.0 m/s² ≈ 2.5g)
  static const double _fallThreshold = 25.0;

  /// Start monitoring accelerometer for fall patterns
  Future<void> startMonitoring({required Function() onFallDetected}) async {
    if (_isMonitoring) return;
    
    _onFallDetected = onFallDetected;
    _isMonitoring = true;
    
    // Subscribe to accelerometer events
    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        if (detectFall(event)) {
          triggerEmergency();
        }
      },
      onError: (error, stackTrace) {
        debugPrint('Accelerometer error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  /// Stop monitoring accelerometer
  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _onFallDetected = null;
  }

  /// Detect fall based on accelerometer event
  /// Returns true if acceleration exceeds threshold
  bool detectFall(AccelerometerEvent event) {
    // Calculate total acceleration magnitude using correct physics formula
    // magnitude = sqrt(x² + y² + z²)
    final double totalAcceleration = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );
    
    // Detect sudden spike in acceleration (simplified fall detection)
    return totalAcceleration > _fallThreshold;
  }

  /// Trigger emergency callback
  void triggerEmergency() {
    if (_onFallDetected != null) {
      _onFallDetected!();
    }
  }

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Dispose of resources
  void dispose() {
    stopMonitoring();
  }
}
