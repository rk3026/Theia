import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/destination.dart';
import '../services/voice_service.dart';
import '../state/map_state.dart';
import 'building_select_screen.dart';
import 'home_screen.dart';
import 'selection_screen.dart';

class StartSelectScreen extends StatelessWidget {
  const StartSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SelectionScreen(
      mode: SelectionMode.start,
      leadingAction: SelectionHeaderAction(
        icon: Icons.apartment,
        tooltip: 'Change building',
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const BuildingSelectScreen()),
          );
        },
      ),
      onConfirm: (Destination destination, VoiceService voiceService) async {
        final mapState = context.read<MapState>();
        await mapState.selectStart(destination.id);
        if (!context.mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      },
    );
  }
}
