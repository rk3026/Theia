import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/voice_service.dart';
import '../services/fall_detection_coordinator.dart';
import '../widgets/multi_finger_gesture_detector.dart';
import 'emergency_screen.dart';

class NavigationScreen extends StatefulWidget {
  final String destination;
  final String route;
  final List<String> instructions;
  final VoiceService? voiceService;

  const NavigationScreen({
    super.key,
    required this.destination,
    required this.route,
    required this.instructions,
    this.voiceService,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late final VoiceService _voiceService;
  late final bool _ownsVoiceService;
  StreamSubscription<String>? _partialSubscription;
  StreamSubscription<String>? _resultSubscription;
  bool _isEmergencyActive = false;
  
  bool _voiceReady = false;
  bool _isListening = false;
  bool _readyToListen = false;
  String? _partialResult;
  String? _lastCommand;
  String? _voiceError;
  
  int _currentStepIndex = 0;
  bool _hasArrived = false;
  
  final List<Map<String, dynamic>> _navigationSteps = [];

  @override
  void initState() {
    super.initState();
    _voiceService = widget.voiceService ?? VoiceService();
    _ownsVoiceService = widget.voiceService == null;
    _readyToListen = false;
    _generateNavigationSteps();
    _initializeVoiceService();
  }

  bool _hasAnnouncedFirstStep = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Announce first step when screen appears
    if (!_hasAnnouncedFirstStep && _navigationSteps.isNotEmpty) {
      _hasAnnouncedFirstStep = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Wait for voice service to be ready and previous TTS to complete
        int attempts = 0;
        while (!_voiceReady && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
        
        if (mounted && _voiceReady) {
          // Additional delay to ensure previous screen's TTS has completed
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            await _announceCurrentStep();
          }
        }
      });
    }
  }

  void _generateNavigationSteps() {
    if (widget.instructions.isEmpty) {
      _navigationSteps.addAll([
        {
          'instruction': 'Walk straight ahead',
          'distance': '',
          'detail': 'Follow the hallway toward your destination',
        },
        {
          'instruction': 'Arrive at destination',
          'distance': '0',
          'detail': 'You have arrived at ${widget.destination}',
        },
      ]);
      return;
    }

    final lowerDestination = widget.destination.toLowerCase();
    for (final step in widget.instructions) {
      final normalized = step.trim();
      final lower = normalized.toLowerCase();
      final isArrival = lower.contains('arrive') || lower.contains('destination');

      _navigationSteps.add({
        'instruction': normalized,
        'distance': '',
        'detail': isArrival ? 'You have arrived at ${widget.destination}.' : 'Proceed carefully.',
      });
    }

    final last = _navigationSteps.isEmpty ? null : _navigationSteps.last;
    final alreadyArrived = last != null &&
        (last['instruction'] as String).toLowerCase().contains('arrive') &&
        (last['instruction'] as String).toLowerCase().contains(lowerDestination);

    if (!alreadyArrived) {
      _navigationSteps.add({
        'instruction': 'Arrive at ${widget.destination}',
        'distance': '0',
        'detail': 'You have arrived at ${widget.destination}.',
      });
    }
  }

  Future<void> _initializeVoiceService() async {
    try {
      await _voiceService.init();
      await _voiceService.resetRecognizer();
      _partialSubscription = _voiceService.partialResults.listen(
        (partial) {
          if (!mounted || !_readyToListen) {
            return;
          }
          setState(() {
            _partialResult = partial;
            _lastCommand = partial;
            _voiceError = null;
          });
          unawaited(_handleRecognizedText(partial, isFinal: false));
        },
        onError: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _voiceError = error.toString();
            _isListening = false;
          });
        },
      );

      _resultSubscription = _voiceService.finalResults.listen(
        (result) {
          if (!mounted || !_readyToListen) {
            return;
          }
          setState(() {
            _partialResult = null;
            _voiceError = null;
          });
          unawaited(_handleRecognizedText(result, isFinal: true));
        },
        onError: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _voiceError = error.toString();
            _isListening = false;
          });
        },
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _voiceReady = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _voiceError = 'Voice setup failed: $error';
      });
    }
  }

  Future<void> _announceCurrentStep() async {
    if (_currentStepIndex >= _navigationSteps.length) {
      return;
    }
    
    final step = _navigationSteps[_currentStepIndex];
    final instruction = step['instruction'] as String;
    final distance = (step['distance'] as String).trim();
    final detail = step['detail'] as String;
    
    if (_currentStepIndex == _navigationSteps.length - 1) {
      await _voiceService.speak('Arrived at ${widget.destination}.');
      setState(() {
        _hasArrived = true;
      });
    } else {
      final distanceFragment = distance.isEmpty ? '' : ' for $distance';
      final detailFragment = detail.isEmpty ? '' : '. $detail';
      final spoken = 'Step ${_currentStepIndex + 1}: $instruction$distanceFragment${detailFragment.isEmpty ? '' : detailFragment}.';
      await _voiceService.speak(spoken.replaceAll('..', '.'));
    }
  }

  Future<void> _navigateToEmergency() async {
    if (_isEmergencyActive) {
      return;
    }

    _isEmergencyActive = true;
    final fallCoordinator = context.read<FallDetectionCoordinator?>();
    if (fallCoordinator != null) {
      await fallCoordinator.pauseForEmergency();
    }

    await _stopListening();

    if (!mounted) {
      _isEmergencyActive = false;
      if (fallCoordinator != null) {
        await fallCoordinator.resumeAfterEmergency();
      }
      return;
    }

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmergencyScreen(
            previousScreen: 'Navigation Screen',
            voiceService: _voiceService,
            onReturn: () {
              _announceScreen(
                context,
                'Returned to Navigation Screen. Continuing to ${widget.destination}.',
              );
            },
          ),
        ),
      );
    } finally {
      if (fallCoordinator != null) {
        await fallCoordinator.resumeAfterEmergency();
      }
      _isEmergencyActive = false;
    }

    if (!mounted) {
      return;
    }

    _announceScreen(
      context,
      'Returned to Navigation Screen. Continuing to ${widget.destination}.',
    );
  }

  Future<void> _goBack() async {
    await _stopListening();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleRecognizedText(String text, {required bool isFinal}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final command = trimmed.toLowerCase();

    if (!isFinal && mounted) {
      setState(() {
        _partialResult = trimmed;
        _lastCommand = trimmed;
      });
    } else if (isFinal && mounted) {
      setState(() {
        _lastCommand = trimmed;
        if (_partialResult == null || _partialResult!.isEmpty) {
          _partialResult = trimmed;
        }
      });
    }

    if (command.contains('next') || command.contains('continue') || command.contains('proceed')) {
      await _stopListening();
      await _nextStep();
      return;
    }

    if (command.contains('repeat') || command.contains('again') || command.contains('read')) {
      await _stopListening();
      await _announceCurrentStep();
      return;
    }

    if (command.contains('cancel') || command.contains('stop')) {
      await _stopListening();
      await _voiceService.speak('Navigation cancelled.');
      if (mounted) {
        await _goBack();
      }
      return;
    }

    if (command.contains('emergency')) {
      await _stopListening();
      await _voiceService.speak('Opening emergency.');
      if (!mounted) {
        return;
      }
      await _navigateToEmergency();
      return;
    }

    if (isFinal) {
      await _stopListening();
      await _voiceService.speak('Did not understand. Say next or repeat.');
    }
  }

  Future<void> _nextStep() async {
    if (_currentStepIndex >= _navigationSteps.length - 1) {
      await _voiceService.speak('Already at ${widget.destination}.');
      return;
    }

    setState(() {
      _currentStepIndex++;
    });

    await _announceCurrentStep();
  }

  Future<void> _startVoiceInteraction() async {
    if (!_voiceReady) {
      _announceScreen(context, 'Voice system is still loading. Please try again.');
      return;
    }

    if (_isListening) {
      await _stopListening();
      return;
    }

    setState(() {
      _isListening = true;
      _readyToListen = false;
      _partialResult = null;
      _lastCommand = null;
      _voiceError = null;
    });

    await _voiceService.speak('Listening. Say next or repeat.');

    await _voiceService.resetRecognizer();
    
    final started = await _voiceService.startListening();
    if (!mounted) {
      return;
    }
    if (started) {
      setState(() {
        _readyToListen = true;
      });
    } else {
      setState(() {
        _isListening = false;
        _voiceError = 'Microphone permission is required for voice commands.';
      });
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) {
      return;
    }
    await _voiceService.stopListening();
    if (!mounted) {
      return;
    }
    setState(() {
      _isListening = false;
      _readyToListen = false;
      _partialResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _currentStepIndex < _navigationSteps.length
        ? _navigationSteps[_currentStepIndex]
        : _navigationSteps.last;
    final instruction = currentStep['instruction'] as String;
    final distance = currentStep['distance'] as String;
    final voiceStatusCard = _buildVoiceStatusCard();
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      body: SafeArea(
        child: Stack(
          children: [
            MultiFingerGestureDetector(
              onTwoFingerDoubleTap: _goBack,
              onThreeFingerTripleTap: () {
                unawaited(_navigateToEmergency());
              },
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _announceScreen(
                          context,
                          'Voice Command area. Double tap to activate voice command.',
                        );
                      },
                      onDoubleTap: _startVoiceInteraction,
                      child: Container(
                        width: double.infinity,
                        color: Colors.orange.shade100,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mic,
                              size: 120,
                              color: Colors.orange.shade700,
                              semanticLabel: 'Voice command',
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Voice Command',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Say "next" or "repeat"',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _announceScreen(
                          context,
                          'Step ${_currentStepIndex + 1} of ${_navigationSteps.length}. $instruction. Tap to repeat instruction.',
                        );
                      },
                      onDoubleTap: () async {
                        await _announceCurrentStep();
                      },
                      child: Container(
                        width: double.infinity,
                        color: Colors.orange.shade300,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _hasArrived ? Icons.check_circle : Icons.navigation,
                              size: 80,
                              color: _hasArrived ? Colors.green.shade700 : Colors.orange.shade900,
                              semanticLabel: _hasArrived ? 'Arrived' : 'Navigating',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Step ${_currentStepIndex + 1}/${_navigationSteps.length}',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              instruction,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            if (distance.isNotEmpty && distance != '0 feet')
                              Text(
                                distance,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            const SizedBox(height: 12),
                            if (!_hasArrived)
                              ElevatedButton.icon(
                                onPressed: _nextStep,
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Next Step', style: TextStyle(fontSize: 18)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.warning, color: Colors.red.shade700, size: 24),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Three-finger triple tap for Emergency',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (voiceStatusCard != null)
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: voiceStatusCard,
              ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.emergency, color: Colors.red.shade700, size: 32),
                onPressed: () {
                  unawaited(_navigateToEmergency());
                },
                tooltip: 'Debug: Emergency',
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.orange.shade900, size: 32),
                onPressed: _goBack,
                tooltip: 'Debug: Go Back',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildVoiceStatusCard() {
    String? message;
    Color? color;
    IconData? icon;

    if (_voiceError != null && _voiceError!.isNotEmpty) {
      message = _voiceError;
      color = Colors.red.shade700;
      icon = Icons.error_outline;
    } else if (_isListening) {
      message = _partialResult != null && _partialResult!.isNotEmpty
          ? 'Listening: $_partialResult'
          : 'Listening...';
      color = Colors.green.shade800;
      icon = Icons.hearing_rounded;
    } else if (_lastCommand != null && _lastCommand!.isNotEmpty) {
      message = 'Heard: $_lastCommand';
      color = Colors.orange.shade700;
      icon = Icons.record_voice_over_outlined;
    }

    if (message == null || color == null || icon == null) {
      return null;
    }

    return Card(
      color: color.withValues(alpha: 0.9),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _announceScreen(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 18)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _partialSubscription?.cancel();
    _resultSubscription?.cancel();
    if (_ownsVoiceService) {
      _voiceService.dispose();
    } else {
      unawaited(_voiceService.stopListening());
    }
    super.dispose();
  }
}
