import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/destination.dart';
import '../services/fall_detection_coordinator.dart';
import '../services/preferences_service.dart';
import '../services/voice_service.dart';
import '../state/map_state.dart';
import '../widgets/multi_finger_gesture_detector.dart';
import 'emergency_screen.dart';
import 'settings_screen.dart';

enum SelectionMode { start, destination }

class SelectionHeaderAction {
  const SelectionHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

class SelectionScreen extends StatefulWidget {
  const SelectionScreen({
    super.key,
    required this.mode,
    required this.onConfirm,
    this.leadingAction,
  });

  final SelectionMode mode;
  final Future<void> Function(Destination destination, VoiceService voiceService) onConfirm;
  final SelectionHeaderAction? leadingAction;

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  final PageController _pageController = PageController();
  final VoiceService _voiceService = VoiceService();

  StreamSubscription<String>? _partialSubscription;
  StreamSubscription<String>? _resultSubscription;

  bool _voiceReady = false;
  bool _isListening = false;
  bool _readyToListen = false;
  String? _voiceError;
  String? _partialResult;
  int _currentIndex = 0;
  int? _pendingIndex;
  String? _pendingCommand;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MapState>().initialize();
      _announceScreenPurpose();
    });
    _initializeVoiceService();
  }

  Future<void> _announceScreenPurpose() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || !_voiceReady) {
      return;
    }
    final message = widget.mode == SelectionMode.start
        ? 'Select your current location.'
        : 'Select destination.';
    await _voiceService.speak(message);
  }

  @override
  void dispose() {
    _partialSubscription?.cancel();
    _resultSubscription?.cancel();
    _voiceService.dispose();
    _pageController.dispose();
    super.dispose();
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
            _voiceError = null;
          });
          unawaited(_handleRecognizedText(partial, isFinal: false));
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

  @override
  Widget build(BuildContext context) {
    final mapState = context.watch<MapState>();
    final building = mapState.currentBuilding;
    final start = mapState.currentStart;

    final destinations = _destinationsForMode(mapState, start);
    final modeLabel = widget.mode == SelectionMode.start ? 'starting location' : 'destination';
    final accent = Colors.blue;

    Widget body;
    if (mapState.isLoading && destinations.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (mapState.error != null && destinations.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                mapState.error!,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (building == null) {
      body = _buildMissingState(
        icon: Icons.apartment,
        message: 'Select a building to continue.',
      );
    } else if (widget.mode == SelectionMode.destination && start == null) {
      body = _buildMissingState(
        icon: Icons.flag,
        message: 'Select a starting location first.',
      );
    } else if (destinations.isEmpty) {
      body = _buildMissingState(
        icon: Icons.location_disabled,
        message: 'No destinations available.',
      );
    } else {
      body = _buildMainContent(destinations, modeLabel, accent, start);
    }

    final voiceStatusCard = _buildVoiceStatusCard(accent);

    return Scaffold(
      backgroundColor: accent.shade50,
      body: SafeArea(
        child: Stack(
          children: [
            MultiFingerGestureDetector(
              onThreeFingerTripleTap: () {
                unawaited(_openEmergency());
              },
              child: body,
            ),
            Positioned(
              top: 10,
              left: 10,
              child: widget.leadingAction == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: Icon(widget.leadingAction!.icon, color: accent.shade900, size: 32),
                      tooltip: widget.leadingAction!.tooltip,
                      onPressed: () {
                        _stopListening();
                        widget.leadingAction!.onPressed();
                      },
                    ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.settings, color: accent.shade900, size: 30),
                    tooltip: 'Open settings',
                    onPressed: _openSettings,
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: Icon(Icons.emergency, color: Colors.red.shade700, size: 32),
                    tooltip: 'Open emergency screen',
                    onPressed: () {
                      unawaited(_openEmergency());
                    },
                  ),
                ],
              ),
            ),
            if (voiceStatusCard != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: voiceStatusCard,
              ),
          ],
        ),
      ),
    );
  }

  List<Destination> _destinationsForMode(MapState mapState, Destination? start) {
    final destinations = List<Destination>.from(mapState.destinationsForCurrentBuilding);
    if (widget.mode == SelectionMode.destination && start != null) {
      destinations.removeWhere((destination) => destination.id == start.id);
    }
    return destinations;
  }

  Widget _buildMissingState({required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.blue.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
    List<Destination> destinations,
    String modeLabel,
    MaterialColor accent,
    Destination? start,
  ) {
    final selectedDestination = destinations.isEmpty ? null : destinations[_currentIndex.clamp(0, destinations.length - 1)];

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              _announceScreen(
                context,
                'Voice command area. Double tap to activate voice search for your $modeLabel.',
                spoken: 'Voice area. Double tap to activate.',
              );
            },
            onDoubleTap: _handleVoiceActivationTap,
            onLongPress: _cancelVoiceInteraction,
            child: Container(
              width: double.infinity,
              color: accent.shade100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, size: 120, color: accent.shade700, semanticLabel: 'Voice command'),
                  const SizedBox(height: 20),
                  Text(
                    'Voice Command',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: accent.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Double tap to activate',
                    style: TextStyle(fontSize: 20, color: accent.shade800),
                  ),
                  if ((_pendingIndex != null && (_pendingCommand?.isNotEmpty ?? false)) ||
                      (_pendingIndex == null && (_partialResult?.isNotEmpty ?? false))) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        _pendingIndex != null
                            ? 'Heard: ${_pendingCommand ?? destinations[_pendingIndex!].name}'
                            : _partialResult!,
                        style: TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: accent.shade900,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (selectedDestination == null) {
                return;
              }
              final floorInfo = 'Floor ${selectedDestination.floor}';
              _announceScreen(
                context,
                '${selectedDestination.name}, $floorInfo. Swipe left or right to change. Double tap to confirm this $modeLabel.',
                spoken: selectedDestination.name,
              );
            },
            onDoubleTap: () {
              _confirmSelection(_currentIndex, destinations);
            },
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) {
                return;
              }
              if (details.primaryVelocity! > 0) {
                _animateToIndex(_currentIndex - 1, destinations.length);
              } else {
                _animateToIndex(_currentIndex + 1, destinations.length);
              }
            },
            child: Container(
              width: double.infinity,
              color: accent.shade300,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    widget.mode == SelectionMode.start ? 'Starting Location' : 'Destination Scroller',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: accent.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Swipe left/right', style: TextStyle(fontSize: 18, color: accent.shade800)),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                        _triggerSelectionHaptic();
                        _announceCurrent(index, destinations);
                      },
                      itemCount: destinations.length,
                      itemBuilder: (context, index) {
                        final destination = destinations[index];
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            elevation: 8,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, size: 50, color: accent.shade700),
                                  const SizedBox(height: 12),
                                  Text(
                                    destination.name,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Floor ${destination.floor}',
                                    style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                                  ),
                                  if (destination.type.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      destination.type,
                                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        destinations.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentIndex == index ? accent.shade900 : accent.shade200,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleVoiceActivationTap() async {
    if (!_voiceReady) {
      _announceScreen(context, 'Voice system is still loading.', spoken: 'Voice system loading.');
      return;
    }

    if (_isListening && _pendingIndex != null) {
      await _executePendingSelection();
      return;
    }

    if (_isListening) {
      await _cancelVoiceInteraction();
      return;
    }

    setState(() {
      _isListening = true;
      _readyToListen = false;
      _partialResult = null;
      _pendingIndex = null;
      _pendingCommand = null;
      _voiceError = null;
    });

    final modeLabelShort = widget.mode == SelectionMode.start ? 'start location' : 'destination';
    await _voiceService.speak('Listening for a $modeLabelShort. Say next or cancel.');
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
        _voiceError = 'Microphone permission is required.';
      });
      _announceScreen(context, 'Microphone permission is required.', spoken: 'Microphone permission needed.');
    }
  }

  Future<void> _cancelVoiceInteraction() async {
    if (_isListening) {
      await _stopListening();
      if (!mounted) {
        return;
      }
      _announceScreen(context, 'Voice command cancelled.');
      return;
    }

    if (_pendingIndex != null) {
      setState(() {
        _pendingIndex = null;
        _pendingCommand = null;
      });
      _announceScreen(context, 'Cancelled the pending request.', spoken: 'Request cancelled.');
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

  Future<void> _handleRecognizedText(String text, {required bool isFinal}) async {
    var trimmed = text.trim();
    if (trimmed.isEmpty) {
      final fallback = _voiceService.consumeResidualTranscript();
      if (fallback == null || fallback.trim().isEmpty) {
        return;
      }
      trimmed = fallback.trim();
    }

    final command = trimmed.toLowerCase();
    final normalizedCommand = _normalizeForMatching(command);

    if (!isFinal) {
      setState(() {
        _partialResult = trimmed;
      });
      return;
    }

    final mapState = context.read<MapState>();
    final destinations = _destinationsForMode(mapState, mapState.currentStart);
    if (destinations.isEmpty) {
      await _stopListening();
      return;
    }

    if (command.contains('cancel') || command.contains('stop')) {
      await _stopListening();
      setState(() {
        _pendingIndex = null;
        _pendingCommand = null;
      });
      await _voiceService.speak('Cancelled.');
      return;
    }

    if (command.contains('next')) {
      await _voiceService.stopListening();
      _animateToIndex((_currentIndex + 1), destinations.length);
      return;
    }

    if (command.contains('previous') || command.contains('back')) {
      await _voiceService.stopListening();
      _animateToIndex((_currentIndex - 1), destinations.length);
      return;
    }

    if (_pendingIndex != null && (command.contains('confirm') || command.contains('yes'))) {
      await _executePendingSelection();
      return;
    }

    for (var index = 0; index < destinations.length; index++) {
      final destination = destinations[index];
      final matchTerms = <String>[destination.name, ...destination.keywords];

      final matchedTerm = matchTerms.firstWhere(
        (term) {
          final normalizedTerm = _normalizeForMatching(term);
          if (normalizedTerm.isEmpty) {
            return false;
          }
          return _matchesNormalized(normalizedCommand, normalizedTerm);
        },
        orElse: () => '',
      );

      if (matchedTerm.isNotEmpty) {
        await _voiceService.stopListening();
        if (!mounted) {
          return;
        }
        _animateToIndex(index, destinations.length);
        setState(() {
          _pendingIndex = index;
          _pendingCommand = trimmed;
        });
        await _voiceService.resetRecognizer();
        await _voiceService.speak('Heard ${destinations[index].name}. Say confirm or cancel.');
        return;
      }
    }

    await _voiceService.stopListening();
    await _voiceService.speak("Didn't catch that. Try again.");
  }

  Future<void> _executePendingSelection() async {
    final index = _pendingIndex;
    if (index == null) {
      return;
    }
    final mapState = context.read<MapState>();
    final destinations = _destinationsForMode(mapState, mapState.currentStart);
    if (index < 0 || index >= destinations.length) {
      return;
    }
    await _stopListening();
    setState(() {
      _pendingIndex = null;
      _pendingCommand = null;
    });
    await _confirmSelection(index, destinations, speakIntro: true);
  }

  void _triggerSelectionHaptic() {
    if (!mounted) {
      return;
    }
    final preferences = context.read<PreferencesService>();
    if (!preferences.hapticsEnabled) {
      return;
    }
    HapticFeedback.mediumImpact();
  }

  void _animateToIndex(int index, int length) {
    if (length == 0) {
      return;
    }
    final previous = _currentIndex;
    final target = index.clamp(0, length - 1);
    setState(() {
      _currentIndex = target;
    });
    if (target != previous) {
      _triggerSelectionHaptic();
    }
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _confirmSelection(int index, List<Destination> destinations, {bool speakIntro = true}) async {
    if (index < 0 || index >= destinations.length) {
      return;
    }
    _triggerSelectionHaptic();
    await _stopListening();
    final selection = destinations[index];
    if (speakIntro) {
      await _voiceService.speak('Selected ${selection.name}.');
    }
    await widget.onConfirm(selection, _voiceService);
  }

  void _announceCurrent(int index, List<Destination> destinations) {
    if (index < 0 || index >= destinations.length) {
      return;
    }
    final destination = destinations[index];
    final floorText = 'Floor ${destination.floor}. Double tap to select.';
    _announceScreen(
      context,
      '${destination.name}, $floorText',
      spoken: destination.name,
    );
  }

  void _announceScreen(BuildContext context, String message, {String? spoken}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 18)),
        duration: const Duration(seconds: 2),
      ),
    );
    if (_voiceReady) {
      _voiceService.speak(spoken ?? message);
    }
  }

  void _openSettings() {
    _stopListening();
    if (!mounted) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    ).then((_) {
      if (!mounted) {
        return;
      }
      _announceScreen(
        context,
        'Returned to ${widget.mode == SelectionMode.start ? 'Start' : 'Destination'} Selection Screen.',
        spoken: 'Back to selection.',
      );
    });
  }

  Future<void> _openEmergency() async {
    _stopListening();
    if (!mounted) {
      return;
    }

    final fallCoordinator = context.read<FallDetectionCoordinator?>();
    if (fallCoordinator != null) {
      await fallCoordinator.pauseForEmergency();
    }

    try {
      if (!mounted) {
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmergencyScreen(
            previousScreen: widget.mode == SelectionMode.start ? 'Start Selection' : 'Destination Selection',
            voiceService: _voiceService,
            onReturn: () {
              _announceScreen(
                context,
                'Returned to ${widget.mode == SelectionMode.start ? 'Start' : 'Destination'} Selection Screen.',
                spoken: 'Back to selection.',
              );
            },
          ),
        ),
      );
    } finally {
      if (fallCoordinator != null) {
        await fallCoordinator.resumeAfterEmergency();
      }
    }
  }

  Widget? _buildVoiceStatusCard(MaterialColor accent) {
    if (_voiceError == null && !_isListening) {
      return null;
    }

    final theme = Theme.of(context);
    final errorStyle = theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700);
    final listeningStyle = theme.textTheme.bodyMedium?.copyWith(color: accent.shade900);

    return Card(
      elevation: 4,
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              _voiceError != null
                  ? Icons.error_outline
                  : (_isListening ? Icons.hearing : Icons.mic),
              color: _voiceError != null ? Colors.red.shade700 : accent.shade700,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _voiceError ?? (_isListening ? 'Listening... say your request.' : ''),
                style: _voiceError != null ? errorStyle : listeningStyle,
              ),
            ),
            if (_isListening)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancelVoiceInteraction,
              ),
          ],
        ),
      ),
    );
  }

  String _normalizeForMatching(String value) {
    final lowered = value.toLowerCase();
    final cleaned = lowered.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _matchesNormalized(String command, String term) {
    if (command.isEmpty || term.isEmpty) {
      return false;
    }
    return command == term || command.contains(term);
  }
}
