import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/favorite_destination.dart';
import 'storage_service.dart';

class FavoritesService extends ChangeNotifier {
  FavoritesService(this._storageService);

  final StorageService _storageService;
  final Uuid _uuid = const Uuid();
  final List<FavoriteDestination> _favorites = [];

  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<FavoriteDestination> get favorites {
    final copy = [..._favorites];
    copy.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return List.unmodifiable(copy);
  }

  List<FavoriteDestination> get activeFavorites {
    return favorites.where((f) => f.isActive).toList(growable: false);
  }

  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();
    try {
      final stored = await _storageService.getFavorites();
      _favorites
        ..clear()
        ..addAll(stored);
      _favorites.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<FavoriteDestination> addFavorite({
    required String name,
    String building = '',
    String room = '',
    bool isActive = true,
  }) async {
    final favorite = FavoriteDestination(
      id: _uuid.v4(),
      name: name,
      building: building,
      room: room,
      sortIndex: _favorites.isEmpty ? 0 : _favorites.map((f) => f.sortIndex).reduce((a, b) => a > b ? a : b) + 1,
      isActive: isActive,
    );
    _favorites.add(favorite);
    await _storageService.saveFavorite(favorite);
    _notifySorted();
    return favorite;
  }

  Future<void> updateFavorite(FavoriteDestination favorite) async {
    final index = _favorites.indexWhere((f) => f.id == favorite.id);
    if (index == -1) {
      return;
    }
    _favorites[index] = favorite;
    await _storageService.saveFavorite(favorite);
    _notifySorted();
  }

  Future<void> toggleFavorite(String id, bool isActive) async {
    final index = _favorites.indexWhere((f) => f.id == id);
    if (index == -1) {
      return;
    }
    final updated = _favorites[index].copyWith(isActive: isActive);
    _favorites[index] = updated;
    await _storageService.saveFavorite(updated);
    _notifySorted();
  }

  Future<void> deleteFavorite(String id) async {
    _favorites.removeWhere((f) => f.id == id);
    await _storageService.deleteFavorite(id);
    await _normalizeSortIndices();
    _notifySorted();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final favorite = _favorites.removeAt(oldIndex);
    _favorites.insert(newIndex, favorite);
    await _normalizeSortIndices();
    _notifySorted();
  }

  Future<void> _normalizeSortIndices() async {
    for (var i = 0; i < _favorites.length; i++) {
      final favorite = _favorites[i];
      _favorites[i] = favorite.copyWith(sortIndex: i);
    }
    await _storageService.replaceFavorites(_favorites);
  }

  void _notifySorted() {
    _favorites.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    notifyListeners();
  }
}
