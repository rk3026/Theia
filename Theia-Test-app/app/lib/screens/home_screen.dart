import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/destination.dart';
import '../models/path_instructions.dart';
import '../services/voice_service.dart';
import '../state/map_state.dart';
import 'route_select_screen.dart';
import 'selection_screen.dart';
import 'start_select_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SelectionScreen(
      mode: SelectionMode.destination,
      leadingAction: SelectionHeaderAction(
        icon: Icons.flag,
        tooltip: 'Change start location',
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const StartSelectScreen()),
          );
        },
      ),
      onConfirm: (Destination destination, VoiceService voiceService) async {
        final mapState = context.read<MapState>();
        final currentStart = mapState.currentStart;
        if (currentStart == null) {
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const StartSelectScreen()),
          );
          return;
        }

        await mapState.selectDestination(destination.id);
        final path = mapState.resolveCurrentPath();
        if (path == null || path.instructions.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No route data available from ${currentStart.name} to ${destination.name}.',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          await voiceService.speak('No route available for that destination.');
          return;
        }

        if (!context.mounted) {
          return;
        }

        final routes = [_toRouteOption(path, currentStart, destination)];

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RouteSelectScreen(
              destination: destination.name,
              routes: routes,
              voiceService: voiceService,
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _toRouteOption(
    PathInstructions path,
    Destination start,
    Destination destination,
  ) {
    final requiresStairs = path.pathType.toLowerCase().contains('stair');
    return <String, dynamic>{
      'name': path.pathType,
      'time': path.estimatedTimeMin > 0 ? '${path.estimatedTimeMin} min' : 'Timing unavailable',
      'description': 'From ${start.name} to ${destination.name}',
      'requiresStairs': requiresStairs,
      'hasTripHazards': false,
      'instructions': path.instructions,
    };
  }
}
