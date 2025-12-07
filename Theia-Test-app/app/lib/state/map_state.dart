import 'package:flutter/foundation.dart';

import '../models/building.dart';
import '../models/destination.dart';
import '../models/map_data.dart';
import '../models/path_instructions.dart';
import '../services/map_loader_service.dart';
import '../services/storage_service.dart';

class MapState extends ChangeNotifier {
  MapState({required MapLoaderService mapLoader, required StorageService storage})
      : _mapLoader = mapLoader,
        _storage = storage;

  final MapLoaderService _mapLoader;
  final StorageService _storage;

  bool _initialized = false;
  bool _isLoading = false;
  String? _error;

  List<Building> _buildings = const [];
  Building? _currentBuilding;
  Destination? _currentStart;
  Destination? _currentDestination;
  MapData? _currentMap;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Building> get buildings => _buildings;
  Building? get currentBuilding => _currentBuilding;
  Destination? get currentStart => _currentStart;
  Destination? get currentDestination => _currentDestination;
  MapData? get currentMapData => _currentMap;

  List<Destination> get destinationsForCurrentBuilding {
    if (_currentBuilding == null) {
      return const [];
    }
    return _currentBuilding!.destinations;
  }

  Future<void> initialize({bool restoreLastSelections = true}) async {
    if (_initialized) {
      return;
    }
    await _loadBuildings(restoreLastSelections: restoreLastSelections);
    _initialized = true;
  }

  Future<void> _loadBuildings({bool restoreLastSelections = true}) async {
    _setLoading(true);
    try {
      _buildings = await _mapLoader.loadBuildingCatalog();
      if (_buildings.isEmpty) {
        _setLoading(false);
        notifyListeners();
        return;
      }

      if (restoreLastSelections) {
        final lastBuildingId = await _storage.getLastBuildingId();
        if (lastBuildingId != null) {
          if (_buildings.any((building) => building.buildingId == lastBuildingId)) {
            await selectBuilding(lastBuildingId, persist: false, restorePreferences: true);
          }
        }
      }
    } catch (error) {
      _error = error.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectBuilding(
    String buildingId, {
    bool persist = true,
    bool restorePreferences = false,
  }) async {
    final building = _buildings.firstWhere(
      (candidate) => candidate.buildingId == buildingId,
      orElse: () => throw ArgumentError('Unknown building: $buildingId'),
    );

    _setLoading(true);
    try {
      final mapData = await _mapLoader.loadMapData(buildingId);
      _currentBuilding = building;
      _currentMap = mapData;
      _currentStart = null;
      _currentDestination = null;
      _error = null;
      if (persist) {
        await _storage.setLastBuildingId(buildingId);
      }
      if (restorePreferences) {
        final lastStart = await _storage.getLastStartLocation(buildingId);
        if (lastStart != null) {
          await selectStart(lastStart, persist: false);
        }
        final lastDestination = await _storage.getLastDestination(buildingId);
        if (lastDestination != null) {
          await selectDestination(lastDestination, persist: false);
        }
      }
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectStart(String destinationId, {bool persist = true}) async {
    if (_currentBuilding == null) {
      throw StateError('Building must be selected before choosing a start location.');
    }
    final destination = _currentBuilding!.destinations.firstWhere(
      (candidate) => candidate.id == destinationId,
      orElse: () => throw ArgumentError('Unknown destination id: $destinationId'),
    );
    _currentStart = destination;
    _currentDestination = null;
    if (persist) {
      final buildingId = _currentBuilding!.buildingId;
      await _storage.setLastStartLocation(buildingId, destinationId);
    }
    notifyListeners();
  }

  Future<void> selectDestination(String destinationId, {bool persist = true}) async {
    if (_currentBuilding == null) {
      throw StateError('Building must be selected before choosing a destination.');
    }
    final destination = _currentBuilding!.destinations.firstWhere(
      (candidate) => candidate.id == destinationId,
      orElse: () => throw ArgumentError('Unknown destination id: $destinationId'),
    );
    _currentDestination = destination;
    if (persist) {
      final buildingId = _currentBuilding!.buildingId;
      await _storage.setLastDestination(buildingId, destinationId);
    }
    notifyListeners();
  }

  PathInstructions? resolveCurrentPath() {
    if (_currentBuilding == null || _currentStart == null || _currentDestination == null) {
      return null;
    }
    final buildingId = _currentBuilding!.buildingId;
    final fromId = _currentStart!.id;
    final toId = _currentDestination!.id;

    final cached = _currentMap?.paths['$fromId $toId'];
    if (cached != null) {
      return cached;
    }
    return _mapLoader.resolvePath(buildingId, fromId, toId);
  }

  void clearSelections() {
    _currentStart = null;
    _currentDestination = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }
    _isLoading = value;
    notifyListeners();
  }
}
