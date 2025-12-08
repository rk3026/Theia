import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Service for playing beeping sounds to help users locate their phone
class PhoneLocatorService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _beepTimer;
  bool _isBeeping = false;

  // Beep interval in seconds
  static const int _beepInterval = 3;

  /// Start playing beeping sound at regular intervals
  Future<void> startBeeping() async {
    if (_isBeeping) return;

    _isBeeping = true;

    // Play first beep immediately
    await _playBeep();

    // Set up timer for repeated beeps
    _beepTimer = Timer.periodic(
      Duration(seconds: _beepInterval),
      (timer) async {
        if (_isBeeping) {
          await _playBeep();
        }
      },
    );
  }

  /// Stop beeping
  Future<void> stopBeeping() async {
    _isBeeping = false;
    _beepTimer?.cancel();
    _beepTimer = null;
    await _audioPlayer.stop();
  }

  /// Play a single beep sound
  Future<void> _playBeep() async {
    try {
      // Stop any currently playing sound first
      await _audioPlayer.stop();
      
      // Set audio player properties for maximum volume
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      // Use a publicly accessible beep sound
      // This is a short notification beep that works reliably
      const String beepUrl = 'https://actions.google.com/sounds/v1/alarms/beep_short.ogg';
      
      // Play the beep sound
      await _audioPlayer.play(UrlSource(beepUrl), volume: 1.0);

      debugPrint('Phone locator beep played');
    } catch (e, stackTrace) {
      debugPrint('Error playing beep: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Check if beeping is currently active
  bool isBeeping() => _isBeeping;

  /// Dispose of resources
  Future<void> dispose() async {
    await stopBeeping();
    await _audioPlayer.dispose();
  }
}
