import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/map_state.dart';
import 'start_select_screen.dart';

class BuildingSelectScreen extends StatefulWidget {
  const BuildingSelectScreen({super.key});

  @override
  State<BuildingSelectScreen> createState() => _BuildingSelectScreenState();
}

class _BuildingSelectScreenState extends State<BuildingSelectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MapState>().initialize();
    });
  }

  Future<void> _handleSelection(MapState mapState, String buildingId) async {
    await mapState.selectBuilding(buildingId);

    if (!mounted) {
      return;
    }

    final selected = mapState.currentBuilding;
    if (selected != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected ${selected.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const StartSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = context.watch<MapState>();
    final buildings = mapState.buildings;

    Widget body;
    if (mapState.isLoading && buildings.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (mapState.error != null && buildings.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Could not load buildings.\n${mapState.error}',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (buildings.isEmpty) {
      body = const Center(
        child: Text('No buildings configured yet.'),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: buildings.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final building = buildings[index];
          final floors = building.floors.isEmpty
              ? 'Floors: N/A'
              : 'Floors: ${building.floors.join(', ')}';

          return Card(
            elevation: 2,
            child: ListTile(
              onTap: () => _handleSelection(mapState, building.buildingId),
              title: Text(building.name),
              subtitle: Text(floors),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Building'),
      ),
      body: body,
    );
  }
}
