import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/preferences.dart';
import '../services/fall_detection_coordinator.dart';
import '../services/preferences_service.dart';
import '../services/voice_service.dart';
import '../widgets/multi_finger_gesture_detector.dart';
import 'emergency_screen.dart';
import 'navigation_screen.dart';

class RouteSelectScreen extends StatefulWidget {
  final String destination;
  final List<Map<String, dynamic>>? routes;
  final VoiceService? voiceService;

  const RouteSelectScreen({
    super.key,
    required this.destination,
    this.routes,
    this.voiceService,
  });

  @override
  State<RouteSelectScreen> createState() => _RouteSelectScreenState();
}

class _RouteSelectScreenState extends State<RouteSelectScreen> {
  final PageController _pageController = PageController();
  late final VoiceService _voiceService;
  late final bool _ownsVoiceService;
  late final PreferencesService _preferencesService;
  StreamSubscription<String>? _partialSubscription;
  StreamSubscription<String>? _resultSubscription;
  int _currentRoute = 0;
  bool _voiceReady = false;
  bool _isListening = false;
  bool _readyToListen = false;
  String? _partialResult;
  String? _lastCommand;
  String? _voiceError;
  bool _isEmergencyActive = false;
  int? _pendingRouteIndex;
  String? _pendingCommandText;
  late final List<Map<String, dynamic>> _routes;

  static const List<Map<String, dynamic>> _defaultRoutes = [
    {
      'name': 'Main Hallway',
      'time': '5 min',
      'description': 'Direct route with moderate traffic',
      'requiresStairs': false,
      'hasTripHazards': false,
      'instructions': [
        'Walk straight ahead',
        'Turn left at the fountain',
        'Continue forward to your destination',
      ],
    },
    {
      'name': 'Accessible Path',
      'time': '7 min',
      'description': 'Elevator access and wide corridors',
      'requiresStairs': false,
      'hasTripHazards': false,
      'instructions': [
        'Walk to the elevator',
        'Take elevator up one floor',
        'Exit and continue forward to your destination',
      ],
    },
    {
      'name': 'Shortest Path',
      'time': '3 min',
      'description': 'Includes stairs and uneven threshold',
      'requiresStairs': true,
      'hasTripHazards': true,
      'instructions': [
        'Turn right toward the stairs',
        'Take the stairs up one floor',
        'Continue straight to your destination',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _voiceService = widget.voiceService ?? VoiceService();
    _ownsVoiceService = widget.voiceService == null;
    final providedRoutes = widget.routes;
    if (providedRoutes == null || providedRoutes.isEmpty) {
      _routes = List<Map<String, dynamic>>.from(_defaultRoutes);
    } else {
      _routes = providedRoutes
          .map((route) => <String, dynamic>{
                'name': route['name'] ?? 'Route',
                'time': route['time'] ?? '',
                'description': route['description'] ?? '',
                'requiresStairs': route['requiresStairs'] ?? false,
                'hasTripHazards': route['hasTripHazards'] ?? false,
                'instructions': (route['instructions'] as List<dynamic>? ?? const [])
                    .map((entry) => entry.toString())
                    .toList(),
              })
          .toList();
    }
    _preferencesService = context.read<PreferencesService>();
    _readyToListen = false;
    _initializeVoiceService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      _partialResult = null;
      _lastCommand = null;
      _voiceError = null;
      _pendingRouteIndex = null;
      _pendingCommandText = null;
      _isListening = false;
    });
    
    // Announce available routes when screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasAnnouncedRoutes) {
        _hasAnnouncedRoutes = true;
        _announceAvailableRoutes();
      }
    });
  }
  
  bool _hasAnnouncedRoutes = false;
  
  Future<void> _announceAvailableRoutes() async {
    final routeNames = _routes.map((r) => r['name']).join(', ');
    await _voiceService.speak('Routes for ${widget.destination}: $routeNames.');
  }

  Future<void> _initializeVoiceService() async {
    try {
      await _voiceService.init();
      await _voiceService.setVolume(_preferencesService.ttsVolume);
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
            previousScreen: 'Route Select Screen',
            voiceService: _voiceService,
            onReturn: () {
              _announceScreen(
                context,
                'Returned to Route Select Screen',
                spoken: 'Back to route selection.',
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
      'Returned to Route Select Screen.',
      spoken: 'Back to route selection.',
    );
  }

  Future<void> _goBack() async {
    await _stopListening();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceStatusCard = _buildVoiceStatusCard();
    final preferences = context.watch<PreferencesService>().current;
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: Stack(
          children: [
            MultiFingerGestureDetector(
              onTwoFingerDoubleTap: () {
                unawaited(_goBack());
              },
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
                          spoken: 'Voice area. Double tap to activate.',
                        );
                      },
                      onDoubleTap: () {
                        _handleVoiceActivationTap();
                      },
                      onLongPress: () {
                        unawaited(_cancelVoiceInteraction());
                      },
                      child: Container(
                        width: double.infinity,
                        color: Colors.green.shade100,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mic,
                              size: 120,
                              color: Colors.green.shade700,
                              semanticLabel: 'Voice command',
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Voice Command',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Double tap to activate',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.green.shade800,
                              ),
                            ),
                            if ((_pendingRouteIndex != null &&
                                    (_pendingCommandText?.isNotEmpty ?? false)) ||
                                (_pendingRouteIndex == null &&
                                    (_partialResult?.isNotEmpty ?? false))) ...[
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Text(
                                  _pendingRouteIndex != null
                                      ? 'Heard: ${_pendingCommandText ?? _routes[_pendingRouteIndex!]['name']}'
                                      : _partialResult!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.green.shade900,
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
                        final route = _routes[_currentRoute];
                        final summary = _buildRouteSummary(route, preferences);
                        _announceScreen(
                          context,
                          '$summary Swipe left or right to change. Double tap to select.',
                          spoken: '${route['name']}, ${route['time']}',
                        );
                      },
                      onDoubleTap: () {
                        unawaited(_startNavigationForRoute(_currentRoute));
                      },
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity! > 0) {
                          _animateToRoute(_currentRoute - 1);
                        } else {
                          _animateToRoute(_currentRoute + 1);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        color: Colors.green.shade300,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Route Scroller',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Swipe left/right',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.green.shade800,
                              ),
                            ),
                            Expanded(
                              child: PageView.builder(
                                controller: _pageController,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentRoute = index;
                                  });
                                  final route = _routes[index];
                                  final summary = _buildRouteSummary(route, preferences);
                                  _announceScreen(
                                    context,
                                    summary,
                                    spoken: '${route['name']}, ${route['time']}',
                                  );
                                },
                                itemCount: _routes.length,
                                itemBuilder: (context, index) {
                                  final route = _routes[index];
                                  final warnings = _preferenceWarningsForRoute(route, preferences);
                                  final preferenceNotice = _buildPreferenceNotice(warnings);
                                  final badges = _buildRouteBadges(route, preferences);
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Card(
                                      elevation: 8,
                                      color: Colors.white,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: 8.0,
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.route,
                                              size: 50,
                                              color: Colors.green.shade700,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              route['name']!,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              route['time']!,
                                              style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              route['description']!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              alignment: WrapAlignment.center,
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: badges,
                                            ),
                                            if (preferenceNotice != null) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                preferenceNotice,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.red.shade700,
                                                ),
                                                textAlign: TextAlign.center,
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
                                  _routes.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentRoute == index
                                          ? Colors.green.shade900
                                          : Colors.green.shade200,
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
              ),
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
                icon: Icon(Icons.arrow_back, color: Colors.green.shade900, size: 32),
                onPressed: () {
                  unawaited(_goBack());
                },
                tooltip: 'Debug: Go Back',
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

  void _announceScreen(BuildContext context, String message, {String? spoken, bool speak = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 18)),
        duration: const Duration(seconds: 2),
      ),
    );
    if (speak && _voiceReady) {
      _voiceService.speak(spoken ?? message);
    }
  }

  void _handleVoiceActivationTap() {
    if (!_isListening && _pendingRouteIndex != null) {
      unawaited(_executePendingRoute());
      return;
    }
    unawaited(_startVoiceInteraction());
  }

  Future<void> _startVoiceInteraction() async {
    if (!_voiceReady) {
      _announceScreen(
        context,
        'Voice system is still loading. Please try again.',
        spoken: 'Voice system loading.',
      );
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
      _lastCommand = null;
      _voiceError = null;
      _pendingRouteIndex = null;
      _pendingCommandText = null;
    });

    await _voiceService.resetRecognizer();
    await _voiceService.speak('Listening for a route. Say cancel to stop.');

    // Reset again after TTS to clear any echo before starting to listen
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
      _announceScreen(
        context,
        'Microphone permission is required for voice commands.',
        spoken: 'Microphone permission needed.',
      );
    }
  }

  Future<void> _cancelVoiceInteraction() async {
    if (_isListening) {
      await _stopListening();
      if (mounted) {
        _announceScreen(context, 'Voice command cancelled.', spoken: 'Voice cancelled.');
      }
      return;
    }

    if (_pendingRouteIndex != null) {
      _clearPendingCommand();
      _announceScreen(context, 'Cancelled the pending navigation request.', spoken: 'Request cancelled.');
    }
  }

  void _animateToRoute(int index) {
    if (!mounted) {
      return;
    }
    final maxIndex = _routes.length - 1;
    final clampedIndex = index.clamp(0, maxIndex).toInt();
    if (clampedIndex == _currentRoute) {
      return;
    }
    setState(() {
      _currentRoute = clampedIndex;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        clampedIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _startNavigationForRoute(int index, {bool speakIntro = true}) async {
    await _stopListening();
    if (!mounted) {
      return;
    }

    _clearPendingCommand();
    _animateToRoute(index);
    final route = _routes[index];
    final preferences = _preferencesService.current;
    final warnings = _preferenceWarningsForRoute(route, preferences);
    final warningText = _formatPreferenceWarning(warnings);

    if (speakIntro) {
      final introParts = <String>[];
      final spokenParts = <String>[];
      if (warningText != null) {
        introParts.add(warningText);
        if (warnings.isNotEmpty) {
          spokenParts.add('Caution: ${_joinWithAnd(warnings)}.');
        }
      }
      introParts.add('Selected ${route['name']} for ${widget.destination}.');
      introParts.add('Starting navigation.');
      spokenParts.add('Starting ${route['name']}.');
      _announceScreen(
        context,
        introParts.join(' '),
        spoken: spokenParts.join(' '),
      );
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          destination: widget.destination,
          route: route['name']!,
          instructions: (route['instructions'] as List<dynamic>? ?? const [])
              .map((entry) => entry.toString())
              .toList(),
          voiceService: _voiceService,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _announceScreen(
      context,
      'Returned to Route Select Screen.',
      spoken: 'Back to route selection.',
    );
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

    if (_pendingRouteIndex != null &&
        (command.contains('confirm') || command.contains('yes') || command.contains('start'))) {
      await _stopListening();
      await _executePendingRoute();
      return;
    }

    if (command.contains('cancel') || command.contains('stop listening') || command.contains('dismiss')) {
      await _stopListening();
      if (_pendingRouteIndex != null) {
        _clearPendingCommand();
        await _voiceService.speak('Cancelled. Ready when you are.');
      } else {
        await _voiceService.speak('Voice cancelled.');
      }
      if (mounted) {
        setState(() {
          _lastCommand = trimmed;
        });
      }
      return;
    }

    if (command.contains('go back') || command.contains('back to home')) {
      await _stopListening();
      if (mounted) {
        await _voiceService.speak('Going back.');
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

    if (command.contains('next route') || command.contains('next option')) {
      final nextIndex = (_currentRoute + 1).clamp(0, _routes.length - 1).toInt();
      _animateToRoute(nextIndex);
      return;
    }

    if (command.contains('previous route') || command.contains('previous option')) {
      final previousIndex = (_currentRoute - 1).clamp(0, _routes.length - 1).toInt();
      _animateToRoute(previousIndex);
      return;
    }

    for (var index = 0; index < _routes.length; index++) {
      final route = _routes[index];
      final normalized = route['name']!.toLowerCase();
      if (command.contains(normalized)) {
        await _stopListening();
        if (!mounted) {
          return;
        }
        _animateToRoute(index);
        setState(() {
          _pendingRouteIndex = index;
          _pendingCommandText = trimmed;
          _lastCommand = trimmed;
          _voiceError = null;
        });
        // Ensure buffer is completely clear before TTS
        await _voiceService.resetRecognizer();
        await _voiceService.speak('Heard ${route['name']}. Say confirm or cancel.');
        // Don't auto-resume - wait for explicit confirmation
        return;
      }
    }

    if (isFinal) {
      await _stopListening();
      await _voiceService.speak("Didn't catch that route. Try again.");
      if (!mounted) {
        return;
      }
      setState(() {
        _voiceError = 'Command not recognized';
        _lastCommand = trimmed;
      });
      _announceScreen(
        context,
        "I didn't catch that route. Please try again.",
        speak: false,
      );
      // Don't auto-resume - wait for user to reactivate voice
    } else {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastCommand = trimmed;
      });
    }
  }

  void _clearPendingCommand() {
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingRouteIndex = null;
      _pendingCommandText = null;
    });
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

  Future<void> _executePendingRoute() async {
    final index = _pendingRouteIndex;
    if (index == null) {
      return;
    }

    final route = _routes[index];
    final heardText = _pendingCommandText ?? route['name']!;
    _clearPendingCommand();

    // Ensure listening is fully stopped and buffer is clear before speaking
    await _voiceService.stopListening();
    await _voiceService.resetRecognizer();
    
    await _voiceService.speak('Starting ${route['name']} to ${widget.destination}.');
    if (!mounted) {
      return;
    }

    // Wait a moment for TTS to fully complete before navigating
    await Future.delayed(const Duration(milliseconds: 300));

    await _startNavigationForRoute(index, speakIntro: false);
    if (!mounted) {
      return;
    }

    setState(() {
      _lastCommand = heardText;
    });
  }

  bool _routeRequiresStairs(Map<String, dynamic> route) {
    return route['requiresStairs'] == true;
  }

  bool _routeHasTripHazards(Map<String, dynamic> route) {
    return route['hasTripHazards'] == true;
  }

  List<String> _preferenceWarningsForRoute(
    Map<String, dynamic> route,
    Preferences preferences,
  ) {
    final warnings = <String>[];
    if (preferences.avoidStairs && _routeRequiresStairs(route)) {
      warnings.add('stairs');
    }
    return warnings;
  }

  String _joinWithAnd(List<String> items) {
    if (items.isEmpty) {
      return '';
    }
    if (items.length == 1) {
      return items.first;
    }
    if (items.length == 2) {
      return '${items[0]} and ${items[1]}';
    }
    final leading = items.sublist(0, items.length - 1).join(', ');
    return '$leading, and ${items.last}';
  }

  String? _formatPreferenceWarning(List<String> warnings) {
    if (warnings.isEmpty) {
      return null;
    }
    final description = _joinWithAnd(warnings);
    return 'Warning: This route includes $description, which the caregiver prefers to avoid.';
  }

  String? _buildPreferenceNotice(List<String> warnings) {
    if (warnings.isEmpty) {
      return null;
    }
    final description = _joinWithAnd(warnings);
    return 'Caretaker prefers to avoid $description.';
  }

  String _buildRouteSummary(Map<String, dynamic> route, Preferences preferences) {
    final base =
        'Route: ${route['name']}, ${route['time']}, ${route['description']}';
    final warnings = _preferenceWarningsForRoute(route, preferences);
    final warning = _formatPreferenceWarning(warnings);
    if (warning == null) {
      return base;
    }
    return '$base. $warning';
  }

  List<Widget> _buildRouteBadges(
    Map<String, dynamic> route,
    Preferences preferences,
  ) {
    final badges = <Widget>[];

    final includesStairs = _routeRequiresStairs(route);
    badges.add(
      _buildBadgeChip(
        icon: includesStairs ? Icons.stairs : Icons.accessible,
        label: includesStairs ? 'Includes stairs' : 'No stairs',
        color: includesStairs ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );

    final hasHazards = _routeHasTripHazards(route);
    badges.add(
      _buildBadgeChip(
        icon: hasHazards ? Icons.warning_amber_rounded : Icons.fact_check,
        label: hasHazards ? 'Trip hazards' : 'Clear path',
        color: hasHazards ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );

    if (preferences.avoidStairs) {
      badges.add(
        _buildBadgeChip(
          icon: Icons.admin_panel_settings,
          label: 'Caretaker avoids stairs',
          color: Colors.blueGrey.shade700,
        ),
      );
    }

    return badges;
  }

  Widget _buildBadgeChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    } else if (_pendingRouteIndex != null) {
      final route = _routes[_pendingRouteIndex!];
      final heardText = _pendingCommandText;
      message = heardText != null && heardText.isNotEmpty
          ? 'Heard: $heardText. Double tap or say confirm to start the ${route['name']}.'
          : 'Ready to start the ${route['name']}. Double tap or say confirm to continue.';
      color = Colors.orange.shade800;
      icon = Icons.playlist_add_check_circle_outlined;
    } else if (_lastCommand != null && _lastCommand!.isNotEmpty) {
      message = 'Heard: $_lastCommand';
      color = Colors.green.shade700;
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

  @override
  void dispose() {
    _partialSubscription?.cancel();
    _resultSubscription?.cancel();
    if (_ownsVoiceService) {
      _voiceService.dispose();
    } else {
      unawaited(_voiceService.stopListening());
    }
    _pageController.dispose();
    super.dispose();
  }
}
