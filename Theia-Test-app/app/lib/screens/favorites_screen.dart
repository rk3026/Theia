import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/favorite_destination.dart';
import '../services/favorites_service.dart';
import '../services/validation_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final FavoritesService _favoritesService;

  @override
  void initState() {
    super.initState();
    _favoritesService = context.read<FavoritesService>();
  }

  Future<void> _showFavoriteDialog({FavoriteDestination? existing}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final buildingController = TextEditingController(text: existing?.building ?? '');
    final roomController = TextEditingController(text: existing?.room ?? '');
    final isActiveNotifier = ValueNotifier<bool>(existing?.isActive ?? true);

    final result = await showDialog<FavoriteDestination>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Favorite Destination' : 'Edit Favorite Destination'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Destination Name'),
                    validator: (value) => ValidationService.validateRequired(value, fieldName: 'Name'),
                  ),
                  TextFormField(
                    controller: buildingController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Building'),
                  ),
                  TextFormField(
                    controller: roomController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Room / Detail'),
                    validator: ValidationService.validateRoom,
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: isActiveNotifier,
                    builder: (context, isActive, _) {
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        subtitle: const Text('Show in the home carousel'),
                        value: isActive,
                        onChanged: (value) {
                          isActiveNotifier.value = value;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final favorite = (existing ?? const FavoriteDestination(
                    id: '',
                    name: '',
                    building: '',
                    room: '',
                    sortIndex: 0,
                    isActive: true,
                  ))
                      .copyWith(
                    name: nameController.text.trim(),
                    building: buildingController.text.trim(),
                    room: roomController.text.trim(),
                    isActive: isActiveNotifier.value,
                  );
                  Navigator.pop(context, favorite);
                }
              },
              child: Text(existing == null ? 'Add Favorite' : 'Save Changes'),
            ),
          ],
        );
      },
    );

    final isActive = isActiveNotifier.value;

    if (result != null) {
      if (existing == null) {
        await _favoritesService.addFavorite(
          name: result.name,
          building: result.building,
          room: result.room,
          isActive: isActive,
        );
      } else {
        await _favoritesService.updateFavorite(
          existing.copyWith(
            name: result.name,
            building: result.building,
            room: result.room,
            isActive: isActive,
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null
                ? 'Added ${result.name} to favorites.'
                : 'Updated ${result.name}.'),
          ),
        );
      }
    }

    nameController.dispose();
    buildingController.dispose();
    roomController.dispose();
    isActiveNotifier.dispose();
  }

  Future<void> _deleteFavorite(FavoriteDestination favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Favorite'),
          content: Text('Remove ${favorite.name} from favorites?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _favoritesService.deleteFavorite(favorite.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${favorite.name}.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesService>().favorites;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Destinations'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFavoriteDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Favorite'),
      ),
      body: favorites.isEmpty
          ? _buildEmptyState()
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: favorites.length,
              onReorder: (oldIndex, newIndex) => _favoritesService.reorder(oldIndex, newIndex),
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                return Card(
                  key: ValueKey(favorite.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      favorite.isActive ? Icons.star : Icons.star_border,
                      color: favorite.isActive ? Colors.amber : Colors.blueGrey,
                    ),
                    title: Text(favorite.name),
                    subtitle: _buildFavoriteSubtitle(favorite),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        Switch(
                          value: favorite.isActive,
                          onChanged: (value) {
                            _favoritesService.toggleFavorite(favorite.id, value);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit',
                          onPressed: () => _showFavoriteDialog(existing: favorite),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                          onPressed: () => _deleteFavorite(favorite),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFavoriteSubtitle(FavoriteDestination favorite) {
    final details = <String>[];
    if (favorite.building.isNotEmpty) {
      details.add(favorite.building);
    }
    if (favorite.room.isNotEmpty) {
      details.add(favorite.room);
    }
    return Text(
      details.isEmpty ? 'Active in carousel' : details.join(' • '),
      style: TextStyle(color: Colors.blueGrey.shade700),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border, size: 96, color: Colors.blueGrey.shade400),
            const SizedBox(height: 24),
            const Text(
              'No favorite destinations yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add frequent destinations so they appear on the home screen carousel.',
              style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showFavoriteDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Favorite'),
            ),
          ],
        ),
      ),
    );
  }
}
