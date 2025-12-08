import 'package:flutter/foundation.dart';

import '../models/preferences.dart';
import 'storage_service.dart';

class PreferencesService extends ChangeNotifier {
  PreferencesService(this._storageService);

  final StorageService _storageService;
  Preferences? _cache;
  bool _isLoading = false;

  Preferences get current => _cache ?? Preferences.defaults();

  double get ttsVolume => current.ttsVolume;
  bool get hapticsEnabled => current.hapticsEnabled;
  bool get avoidStairs => current.avoidStairs;
  DateTime get updatedAt => current.updatedAt;

  bool get isLoaded => _cache != null;
  bool get isLoading => _isLoading;

  Future<Preferences> loadPreferences() async {
    if (_cache != null) {
      return _cache!;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await _storageService.getPreferences();
      _cache = prefs ?? Preferences.defaults();
      if (prefs == null) {
        await _storageService.savePreferences(_cache!);
      }
      return _cache!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setTtsVolume(double value) async {
    value = value.clamp(0.0, 1.0);
    await _persist(current.copyWith(ttsVolume: value, updatedAt: DateTime.now()));
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    await _persist(current.copyWith(hapticsEnabled: enabled, updatedAt: DateTime.now()));
  }

  Future<void> setAvoidStairs(bool enabled) async {
    await _persist(current.copyWith(avoidStairs: enabled, updatedAt: DateTime.now()));
  }

  Future<void> refresh() async {
    _cache = null;
    await loadPreferences();
  }

  Future<void> _persist(Preferences preferences) async {
    _cache = preferences;
    await _storageService.savePreferences(preferences);
    notifyListeners();
  }
}
