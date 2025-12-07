import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/emergency_service.dart';
import '../services/phone_locator_service.dart';
import '../services/storage_service.dart';
import '../services/voice_service.dart';

/// Emergency screen with 4-phase flow
/// Phase 1: "Are you okay?" prompt (10 seconds)
/// Phase 2: Phone locator beeping (optional)
/// Phase 3: Contact emergency contact or fallback emergency number
/// Phase 4: Return to navigation
class EmergencyScreen extends StatefulWidget {
  final String previousScreen;
  final VoidCallback onReturn;
  final VoiceService voiceService;

  const EmergencyScreen({
    super.key,
    required this.previousScreen,
    required this.onReturn,
    required this.voiceService,
  });

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  int _currentPhase = 1;
  int _countdown = 10;
  Timer? _countdownTimer;
  bool _cancelled = false;
  String _statusMessage = '';
  bool _awaitingPhaseResponse = true;
  
  final PhoneLocatorService _phoneLocator = PhoneLocatorService();
  late final EmergencyService _emergencyService;
  
  StreamSubscription<String>? _voiceSubscription;
  StreamSubscription<String>? _partialVoiceSubscription;

  @override
  void initState() {
    super.initState();
    _emergencyService = EmergencyService(storageService: context.read<StorageService>());
    _initVoiceService();
    unawaited(_phase1InitialPrompt());
  }

  void _initVoiceService() {
    _partialVoiceSubscription = widget.voiceService.partialResults.listen((text) {
      if (!_cancelled && mounted) {
        _handleVoiceResponse(text.toLowerCase(), isFinal: false);
      }
    });

    _voiceSubscription = widget.voiceService.finalResults.listen((text) {
      if (!_cancelled && mounted) {
        final payload = text.isEmpty
            ? (widget.voiceService.consumeResidualTranscript() ?? '')
            : text;
        _handleVoiceResponse(payload.toLowerCase(), isFinal: true);
      }
    });
  }

  /// Phase 1: Initial prompt "Are you okay?"
  Future<void> _phase1InitialPrompt() async {
    setState(() {
      _currentPhase = 1;
      _countdown = 10;
      _statusMessage = 'Are you okay?';
      _awaitingPhaseResponse = true;
    });

    await widget.voiceService.stopListening();
    await widget.voiceService.resetRecognizer();
    await widget.voiceService.speak('Emergency mode. Say yes for help, no to cancel.');

    if (mounted && !_cancelled) {
      final started = await widget.voiceService.startListening();
      if (!started) {
        setState(() {
          _statusMessage = 'Microphone unavailable. Tap cancel if you are okay.';
        });
      }
    }

    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        if (!_cancelled && mounted) {
          if (_currentPhase == 1) {
            // No response in phase 1, proceed to phase 2
            unawaited(_phase2PhoneLocator());
          } else if (_currentPhase == 2) {
            // No response in phase 2, proceed to phase 3
            _phase3ContactEmergency();
          }
        }
      }
    });
  }

  /// Phase 2: Phone locator beeping
  Future<void> _phase2PhoneLocator() async {
    await widget.voiceService.stopListening();

    setState(() {
      _currentPhase = 2;
      _countdown = 30;
      _statusMessage = 'Phone locator active';
      _awaitingPhaseResponse = true;
    });

    await widget.voiceService.resetRecognizer();
    await widget.voiceService.speak('Phone locator on. Say found when you have your phone.');

    if (mounted && !_cancelled) {
      await _phoneLocator.startBeeping();
      final started = await widget.voiceService.startListening();
      if (!started) {
        setState(() {
          _statusMessage = 'Microphone unavailable. Tap cancel after finding your phone.';
        });
      }
      _startCountdownTimer();
    }
  }

  /// Phase 3: Contact emergency contact or fallback emergency number
  void _phase3ContactEmergency() async {
    await widget.voiceService.stopListening();
    await widget.voiceService.resetRecognizer();
    await _phoneLocator.stopBeeping();
    _countdownTimer?.cancel();

    setState(() {
      _currentPhase = 3;
      _statusMessage = 'Contacting emergency contact...';
      _awaitingPhaseResponse = false;
    });

    try {
      final contact = await _emergencyService.getPrimaryContact();
      
      if (contact != null) {
        widget.voiceService.speak('Calling ${contact.name}.');
        
        setState(() {
          _statusMessage = 'Calling ${contact.name}';
        });

        // Wait for TTS to complete
        await Future.delayed(const Duration(milliseconds: 2000));
        
        if (mounted && !_cancelled) {
          // Call emergency contact
          await _emergencyService.callEmergencyContact(contact.phoneNumber);
          
          // Send SMS
          await _emergencyService.sendEmergencySMS(
            contact.phoneNumber,
            'Emergency alert from THEIA app. ${contact.name} may need assistance. Please check on them immediately.',
          );
        }
      } else {
        // No emergency contact configured, fall back to emergency services number
        widget.voiceService.speak('No emergency contact saved. Calling emergency services.');
        
        setState(() {
          _statusMessage = 'Calling 555-555-5555';
        });

        await Future.delayed(const Duration(milliseconds: 2000));
        
        if (mounted && !_cancelled) {
          await _emergencyService.call911();
        }
      }

      // Phase 4: Complete - allow user to return
      if (mounted && !_cancelled) {
        setState(() {
          _currentPhase = 4;
          _statusMessage = 'Emergency contact notified';
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error in phase 3: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  void _handleVoiceResponse(String text, {required bool isFinal}) {
    if (_cancelled || !_awaitingPhaseResponse) {
      return;
    }

    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }

    debugPrint('Voice response in phase $_currentPhase: $normalized (final: $isFinal)');

    final lower = normalized.toLowerCase();

    if (_currentPhase == 1) {
      // Phase 1: Are you okay?
      final needsHelp = lower.contains('yes') || lower.contains('help') || lower.contains('assist');
      final cancelEmergency = lower.contains('no') || lower.contains('cancel') || lower.contains('fine') || lower.contains("i'm ok") || lower.contains('i am ok');

      if (needsHelp) {
        _awaitingPhaseResponse = false;
        // User needs help, skip to phase 3
        widget.voiceService.stopListening();
        widget.voiceService.speak('Understood. Contacting emergency services.');
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && !_cancelled) {
            _phase3ContactEmergency();
          }
        });
      } else if (cancelEmergency) {
        _awaitingPhaseResponse = false;
        // User is okay, cancel emergency
        widget.voiceService.speak('Understood. Canceling emergency.');
        _cancelEmergency();
      } else if (isFinal && !_awaitingPhaseResponse) {
        // already handled
      } else if (isFinal) {
        // Provide quick clarification prompt
        widget.voiceService.speak('Please say yes for help or no to cancel.');
      }
    } else if (_currentPhase == 2) {
      // Phase 2: Phone locator
      final foundPhone = lower.contains('found') || lower.contains('stop') || lower.contains('got it');
      if (foundPhone) {
        _awaitingPhaseResponse = false;
        // User found phone, cancel emergency
        widget.voiceService.speak('Understood. Canceling emergency.');
        _cancelEmergency();
      } else if (isFinal) {
        widget.voiceService.speak('Say found when you have your phone.');
      }
    }
  }

  void _cancelEmergency() async {
    if (!_cancelled) {
      setState(() {
        _cancelled = true;
      });
      
      _countdownTimer?.cancel();
      await widget.voiceService.stopListening();
      await widget.voiceService.resetRecognizer();
      await _phoneLocator.stopBeeping();
      _awaitingPhaseResponse = false;
      
      if (mounted) {
        Navigator.pop(context);
        Future.delayed(const Duration(milliseconds: 100), () {
          widget.onReturn();
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _voiceSubscription?.cancel();
    _partialVoiceSubscription?.cancel();
    _phoneLocator.dispose();
    widget.voiceService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade700,
      body: SafeArea(
        child: GestureDetector(
          onDoubleTap: _cancelEmergency,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.emergency,
                  size: 180,
                  color: Colors.white,
                  semanticLabel: 'Emergency activated',
                ),
                const SizedBox(height: 48),
                const Text(
                  'EMERGENCY',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (_currentPhase <= 2 && _countdown > 0) ...[
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _getPhaseInstructions(),
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_currentPhase >= 3) ...[
                  const SizedBox(height: 40),
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 6,
                  ),
                ],
                const SizedBox(height: 60),
                SizedBox(
                  width: double.infinity,
                  height: 100,
                  child: ElevatedButton(
                    onPressed: _cancelEmergency,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade700,
                      textStyle: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Cancel Emergency'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPhaseInstructions() {
    switch (_currentPhase) {
      case 1:
        return 'Say "yes" if you need help\nSay "no" to cancel\nDouble tap to cancel';
      case 2:
        return 'Phone locator beeping\nSay "found" when located\nDouble tap to cancel';
      default:
        return 'Double tap to cancel';
    }
  }
}
