import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/emergency_screen.dart';
import 'fall_detection_service.dart';
import 'preferences_service.dart';
import 'voice_service.dart';

class FallDetectionCoordinator {
  FallDetectionCoordinator({
    required this.navigatorKey,
    required PreferencesService preferencesService,
  }) : _preferencesService = preferencesService {
    _preferencesListener = () {
      unawaited(_updateVoiceVolume());
    };
    _preferencesService.addListener(_preferencesListener);
  }

  final GlobalKey<NavigatorState> navigatorKey;
  final PreferencesService _preferencesService;
  final FallDetectionService _fallDetection = FallDetectionService();
  final VoiceService _voiceService = VoiceService();

  late final VoidCallback _preferencesListener;
  bool _voiceReady = false;
  bool _isMonitoring = false;
  bool _handlingEmergency = false;
  int _pauseDepth = 0;

  Future<void> initialize() async {
    if (!_voiceReady) {
      await _voiceService.init();
      await _voiceService.setVolume(_preferencesService.ttsVolume);
      _voiceReady = true;
    }

    if (_pauseDepth == 0 && !_isMonitoring) {
      await _fallDetection.startMonitoring(onFallDetected: _handleFallDetected);
      _isMonitoring = true;
    }
  }

  Future<void> _handleFallDetected() async {
    if (_handlingEmergency) {
      return;
    }

    _handlingEmergency = true;
    await pauseForEmergency();

    try {
      await _voiceService.stopListening();
      await _voiceService.resetRecognizer();

      if (_voiceReady) {
        unawaited(_voiceService.speak('Fall detected. Opening emergency.'));
      }

      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        return;
      }

      await navigator.push(
        MaterialPageRoute(
          builder: (context) => EmergencyScreen(
            previousScreen: 'Automatic Fall Detection',
            voiceService: _voiceService,
            onReturn: () {
              unawaited(_voiceService.resetRecognizer());
              unawaited(_voiceService.speak('Fall response complete. Returning to THEIA.'));
            },
          ),
        ),
      );
    } finally {
      _handlingEmergency = false;
      await resumeAfterEmergency();
    }
  }

  Future<void> pauseForEmergency() async {
    _pauseDepth++;
    if (_isMonitoring) {
      await _fallDetection.stopMonitoring();
      _isMonitoring = false;
    }
  }

  Future<void> resumeAfterEmergency() async {
    if (_pauseDepth > 0) {
      _pauseDepth--;
    }

    if (_pauseDepth == 0 && !_isMonitoring) {
      await _fallDetection.startMonitoring(onFallDetected: _handleFallDetected);
      _isMonitoring = true;
    }
  }

  Future<void> dispose() async {
    _preferencesService.removeListener(_preferencesListener);
    if (_isMonitoring) {
      await _fallDetection.stopMonitoring();
      _isMonitoring = false;
    }
    await _voiceService.dispose();
  }

  Future<void> _updateVoiceVolume() async {
    if (!_voiceReady) {
      return;
    }

    await _voiceService.setVolume(_preferencesService.ttsVolume);
  }
}
