import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const TheiaApp());
}

class TheiaApp extends StatelessWidget {
  const TheiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Theia Navigation',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// Custom gesture detector for multi-finger taps
class MultiFingerGestureDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTwoFingerDoubleTap;
  final VoidCallback? onThreeFingerTripleTap;

  const MultiFingerGestureDetector({
    super.key,
    required this.child,
    this.onTwoFingerDoubleTap,
    this.onThreeFingerTripleTap,
  });

  @override
  State<MultiFingerGestureDetector> createState() => _MultiFingerGestureDetectorState();
}

class _MultiFingerGestureDetectorState extends State<MultiFingerGestureDetector> {
  int _tapCount = 0;
  int _fingerCount = 0;
  Timer? _tapTimer;

  void _handlePointerDown(PointerDownEvent event) {
    _fingerCount++;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_fingerCount == 2 || _fingerCount == 3) {
      final targetFingers = _fingerCount;
      _tapCount++;

      _tapTimer?.cancel();
      _tapTimer = Timer(const Duration(milliseconds: 300), () {
        if (targetFingers == 2 && _tapCount == 2 && widget.onTwoFingerDoubleTap != null) {
          widget.onTwoFingerDoubleTap!();
        } else if (targetFingers == 3 && _tapCount == 3 && widget.onThreeFingerTripleTap != null) {
          widget.onThreeFingerTripleTap!();
        }
        _tapCount = 0;
      });
    }

    _fingerCount = 0;
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      child: widget.child,
    );
  }
}

// Home Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentDestination = 0;
  final List<String> _destinations = [
    'Cafeteria',
    'Library',
    'Classroom 101',
    'Restroom',
    'Exit',
  ];

  void _navigateToEmergency() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyScreen(
          previousScreen: 'Home Screen',
          onReturn: () {
            _announceScreen(context, 'Returned to Home Screen');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Stack(
          children: [
            MultiFingerGestureDetector(
              onThreeFingerTripleTap: _navigateToEmergency,
              child: Column(
            children: [
              // Top Half - Voice Command
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _announceScreen(context, 'Voice Command area. Double tap to activate voice command.');
                  },
                  onDoubleTap: () {
                    _announceScreen(context, 'Voice Command activated. Say Navigate to ${_destinations[_currentDestination]}');
                  },
                  child: Container(
                    width: double.infinity,
                    color: Colors.blue.shade100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic,
                          size: 120,
                          color: Colors.blue.shade700,
                          semanticLabel: 'Voice command',
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Voice Command',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                          semanticsLabel: 'Voice Command',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Double tap to activate',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Half - Destination Scroller
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _announceScreen(context, 'Destination: ${_destinations[_currentDestination]}. Swipe left or right to change. Double tap to select.');
                  },
                  onDoubleTap: () {
                    _announceScreen(context, 'Selected ${_destinations[_currentDestination]}. Navigating to route selection.');
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RouteSelectScreen(destination: _destinations[_currentDestination])),
                    );
                  },
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity! > 0) {
                      // Swiped right - go to previous
                      if (_currentDestination > 0) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    } else {
                      // Swiped left - go to next
                      if (_currentDestination < _destinations.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    color: Colors.blue.shade300,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            'Destination Scroller',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Swipe left/right',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentDestination = index;
                              });
                              _announceScreen(context, 'Destination: ${_destinations[index]}');
                            },
                            itemCount: _destinations.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Card(
                                  elevation: 8,
                                  color: Colors.white,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _getDestinationIcon(_destinations[index]),
                                          size: 100,
                                          color: Colors.blue.shade700,
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          _destinations[index],
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                          semanticsLabel: _destinations[index],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Page indicator
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _destinations.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentDestination == index
                                      ? Colors.blue.shade900
                                      : Colors.blue.shade200,
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
            // Debug button (only visible in debug mode)
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.emergency, color: Colors.red.shade700, size: 32),
                onPressed: _navigateToEmergency,
                tooltip: 'Debug: Emergency',
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDestinationIcon(String destination) {
    switch (destination) {
      case 'Cafeteria':
        return Icons.restaurant;
      case 'Library':
        return Icons.local_library;
      case 'Classroom 101':
        return Icons.school;
      case 'Restroom':
        return Icons.wc;
      case 'Exit':
        return Icons.exit_to_app;
      default:
        return Icons.place;
    }
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
    _pageController.dispose();
    super.dispose();
  }
}

// Route Select Screen
class RouteSelectScreen extends StatefulWidget {
  final String destination;

  const RouteSelectScreen({super.key, required this.destination});

  @override
  State<RouteSelectScreen> createState() => _RouteSelectScreenState();
}

class _RouteSelectScreenState extends State<RouteSelectScreen> {
  final PageController _pageController = PageController();
  int _currentRoute = 0;
  final List<Map<String, String>> _routes = [
    {'name': 'Main Hallway', 'time': '5 min', 'description': 'Standard route'},
    {'name': 'Accessible Path', 'time': '7 min', 'description': 'Elevator access'},
    {'name': 'Shortest Path', 'time': '3 min', 'description': 'Stairs required'},
  ];

  void _navigateToEmergency() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyScreen(
          previousScreen: 'Route Select Screen',
          onReturn: () {
            _announceScreen(context, 'Returned to Route Select Screen');
          },
        ),
      ),
    );
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: Stack(
          children: [
            MultiFingerGestureDetector(
              onTwoFingerDoubleTap: _goBack,
              onThreeFingerTripleTap: _navigateToEmergency,
              child: Column(
            children: [
              // Top Half - Voice Command
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _announceScreen(context, 'Voice Command area. Double tap to activate voice command.');
                  },
                  onDoubleTap: () {
                    _announceScreen(context, 'Voice Command activated. Say Confirm route to ${widget.destination}');
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
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Half - Route Scroller
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final route = _routes[_currentRoute];
                    _announceScreen(context, 'Route: ${route['name']}, ${route['time']}, ${route['description']}. Swipe left or right to change. Double tap to select.');
                  },
                  onDoubleTap: () {
                    final route = _routes[_currentRoute];
                    _announceScreen(context, 'Selected ${route['name']}. Starting navigation.');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NavigationScreen(
                          destination: widget.destination,
                          route: _routes[_currentRoute]['name']!,
                        ),
                      ),
                    );
                  },
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity! > 0) {
                      if (_currentRoute > 0) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    } else {
                      if (_currentRoute < _routes.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
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
                              _announceScreen(context, 'Route: ${route['name']}, ${route['time']}');
                            },
                            itemCount: _routes.length,
                            itemBuilder: (context, index) {
                              final route = _routes[index];
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Card(
                                  elevation: 8,
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Page indicator
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
            // Debug buttons
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.emergency, color: Colors.red.shade700, size: 32),
                onPressed: _navigateToEmergency,
                tooltip: 'Debug: Emergency',
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.green.shade900, size: 32),
                onPressed: _goBack,
                tooltip: 'Debug: Go Back',
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
    _pageController.dispose();
    super.dispose();
  }
}

// Navigation Screen
class NavigationScreen extends StatefulWidget {
  final String destination;
  final String route;

  const NavigationScreen({
    super.key,
    required this.destination,
    required this.route,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  void _navigateToEmergency() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyScreen(
          previousScreen: 'Navigation Screen',
          onReturn: () {
            _announceScreen(context, 'Returned to Navigation Screen. Continuing to ${widget.destination}.');
          },
        ),
      ),
    );
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      body: SafeArea(
        child: Stack(
          children: [
            MultiFingerGestureDetector(
              onTwoFingerDoubleTap: _goBack,
              onThreeFingerTripleTap: _navigateToEmergency,
              child: Column(
                children: [
              // Top Half - Voice Command
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _announceScreen(context, 'Voice Command area. Double tap to activate voice command.');
                  },
                  onDoubleTap: () {
                    _announceScreen(context, 'Voice Command activated. Say Read Location or Stop Navigation');
                  },
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
                          'Double tap to activate',
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

              // Bottom Half - Navigation Instructions
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _announceScreen(context, 'Navigation instructions. Navigating to ${widget.destination} via ${widget.route}. Continue straight for 50 feet. Double tap to read current location.');
                  },
                  onDoubleTap: () {
                    _announceScreen(context, 'Current location: Main hallway, 50 feet to destination.');
                  },
                  child: Container(
                    width: double.infinity,
                    color: Colors.orange.shade300,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.navigation,
                          size: 120,
                          color: Colors.orange.shade900,
                          semanticLabel: 'Navigating',
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Continue straight',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '50 feet',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning, color: Colors.red.shade700, size: 28),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Three-finger triple tap for Emergency',
                                  style: TextStyle(
                                    fontSize: 16,
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
            // Debug buttons
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.emergency, color: Colors.red.shade700, size: 32),
                onPressed: _navigateToEmergency,
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

  void _announceScreen(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 18)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Emergency Screen with countdown
class EmergencyScreen extends StatefulWidget {
  final String previousScreen;
  final VoidCallback onReturn;

  const EmergencyScreen({
    super.key,
    required this.previousScreen,
    required this.onReturn,
  });

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  int _countdown = 3;
  Timer? _countdownTimer;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Announce on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceScreen(context, 'Emergency Mode activated. 3 seconds to cancel. Double tap anywhere to cancel and return to ${widget.previousScreen}.');
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
        if (_countdown > 0) {
          _announceScreen(context, '$_countdown seconds remaining. Double tap to cancel.');
        }
      } else {
        timer.cancel();
        // Emergency confirmed after 3 seconds
        if (!_cancelled && mounted) {
          _announceScreen(context, 'Emergency confirmed. Help has been notified.');
        }
      }
    });
  }

  void _cancelEmergency() {
    if (!_cancelled) {
      setState(() {
        _cancelled = true;
      });
      _countdownTimer?.cancel();
      Navigator.pop(context);
      // Call the onReturn callback to announce the return
      Future.delayed(const Duration(milliseconds: 100), () {
        widget.onReturn();
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade700,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            if (_countdown > 0) {
              _announceScreen(context, 'Emergency Mode. $_countdown seconds to cancel. Double tap anywhere to cancel.');
            } else {
              _announceScreen(context, 'Emergency confirmed. Help has been notified. Double tap to return to ${widget.previousScreen}.');
            }
          },
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
                  semanticsLabel: 'Emergency Mode Activated',
                ),
                const SizedBox(height: 40),
                if (_countdown > 0) ...[
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    semanticsLabel: '$_countdown seconds remaining',
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Double tap anywhere\nto cancel',
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const SizedBox(height: 40),
                  const Text(
                    'Help has been notified',
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
              ],
            ),
          ),
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
}
