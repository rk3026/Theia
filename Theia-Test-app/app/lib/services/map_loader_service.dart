import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/building.dart';
import '../models/map_data.dart';
import '../models/path_instructions.dart';

class MapLoaderService {
  MapLoaderService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  static const _buildingCatalogPath = 'assets/maps/Building.json';

  List<Building>? _buildingCache;
  final Map<String, MapData> _mapCache = <String, MapData>{};

  Future<List<Building>> loadBuildingCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh && _buildingCache != null) {
      return _buildingCache!;
    }

    final rawJson = await _bundle.loadString(_buildingCatalogPath);
    final dynamic decoded = jsonDecode(rawJson);
    final buildings = (decoded as List<dynamic>)
        .map(
          (entry) => Building.fromJson(entry as Map<String, dynamic>),
        )
        .toList();

    _buildingCache = buildings;
    return buildings;
  }

  Future<MapData> loadMapData(String buildingId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _mapCache.containsKey(buildingId)) {
      return _mapCache[buildingId]!;
    }

    final assetPath = 'assets/maps/$buildingId.json';
    final rawJson = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final mapData = MapData.fromJson(decoded);
    _mapCache[buildingId] = mapData;
    return mapData;
  }

  PathInstructions? resolvePath(String buildingId, String fromId, String toId) {
    final mapData = _mapCache[buildingId];
    if (mapData == null) {
      return null;
    }
    final key = '$fromId $toId';
    return mapData.paths[key];
  }

  void clearCache() {
    _buildingCache = null;
    _mapCache.clear();
  }
}
