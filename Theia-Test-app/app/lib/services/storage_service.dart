import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/emergency_contact.dart';
import '../models/favorite_destination.dart';
import '../models/preferences.dart';

class StorageService {
  StorageService();

  static const _databaseName = 'theia_audit.db';
  static const _databaseVersion = 4;
  static const _lastBuildingKey = 'storage.lastBuildingId';
  static String _lastStartKey(String buildingId) => 'storage.lastStart.$buildingId';
  static String _lastDestinationKey(String buildingId) => 'storage.lastDestination.$buildingId';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Uuid _uuid = const Uuid();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  Database? _database;

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$_databaseName';

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToVersion2(db);
        }
        if (oldVersion < 3) {
          await _upgradeToVersion3(db);
        }
        if (oldVersion < 4) {
          await _upgradeToVersion4(db);
        }
      },
    );

    await _seedDefaults();
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_events (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        payload TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS emergency_contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phoneNumber TEXT NOT NULL,
        isPrimary INTEGER NOT NULL,
        relationship TEXT NOT NULL,
        email TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS preferences (
        id TEXT PRIMARY KEY,
        ttsVolume REAL NOT NULL,
        hapticsEnabled INTEGER NOT NULL,
        avoidStairs INTEGER NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        building TEXT,
        room TEXT,
        sortIndex INTEGER NOT NULL,
        isActive INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _upgradeToVersion2(Database db) async {
    final existingTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='emergency_contacts'",
    );
    if (existingTables.isEmpty) {
      await db.execute('''
        CREATE TABLE emergency_contacts (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phoneNumber TEXT NOT NULL,
          isPrimary INTEGER NOT NULL,
          relationship TEXT NOT NULL,
          email TEXT,
          notes TEXT
        )
      ''');
    }
  }

  Future<void> _upgradeToVersion3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS preferences (
        id TEXT PRIMARY KEY,
        ttsVolume REAL NOT NULL,
        hapticsEnabled INTEGER NOT NULL,
        avoidStairs INTEGER NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        building TEXT,
        room TEXT,
        sortIndex INTEGER NOT NULL,
        isActive INTEGER NOT NULL
      )
    ''');

    final columns = await db.rawQuery('PRAGMA table_info(emergency_contacts)');
    final hasEmail = columns.any((column) => column['name'] == 'email');
    final hasNotes = columns.any((column) => column['name'] == 'notes');

    if (!hasEmail) {
      await db.execute("ALTER TABLE emergency_contacts ADD COLUMN email TEXT");
    }
    if (!hasNotes) {
      await db.execute("ALTER TABLE emergency_contacts ADD COLUMN notes TEXT");
    }
  }

  Future<void> _upgradeToVersion4(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(preferences)');
    final hasAvoidTrips = columns.any((column) => column['name'] == 'avoidTrips');
    if (!hasAvoidTrips) {
      return;
    }

    await db.execute('''
      CREATE TABLE preferences_tmp (
        id TEXT PRIMARY KEY,
        ttsVolume REAL NOT NULL,
        hapticsEnabled INTEGER NOT NULL,
        avoidStairs INTEGER NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      INSERT INTO preferences_tmp (id, ttsVolume, hapticsEnabled, avoidStairs, updatedAt)
      SELECT id, ttsVolume, hapticsEnabled, avoidStairs, updatedAt FROM preferences
    ''');

    await db.execute('DROP TABLE preferences');
    await db.execute('ALTER TABLE preferences_tmp RENAME TO preferences');
  }

  Future<void> _seedDefaults() async {
    final db = _database;
    if (db == null) {
      return;
    }

    final preferences = await getPreferences();
    if (preferences == null) {
      await savePreferences(Preferences.defaults());
    }

    final favorites = await getFavorites();
    if (favorites.isEmpty) {
      final defaults = [
        FavoriteDestination(
          id: _uuid.v4(),
          name: 'Cafeteria',
          building: 'Student Center',
          room: 'Floor 1',
          sortIndex: 0,
          isActive: true,
        ),
        FavoriteDestination(
          id: _uuid.v4(),
          name: 'Library',
          building: 'Knowledge Hall',
          room: 'Floor 2',
          sortIndex: 1,
          isActive: true,
        ),
        FavoriteDestination(
          id: _uuid.v4(),
          name: 'Classroom 101',
          building: 'Engineering',
          room: 'Room 101',
          sortIndex: 2,
          isActive: true,
        ),
      ];

      final batch = db.batch();
      for (final favorite in defaults) {
        batch.insert('favorites', favorite.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> savePreference({required String key, required String value}) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> readPreference(String key) {
    return _secureStorage.read(key: key);
  }

  Future<void> logAuditEvent({required String type, String? payload}) async {
    final db = _database;
    if (db == null) {
      return;
    }

    await db.insert(
      'audit_events',
      {
        'id': _uuid.v4(),
        'type': type,
        'timestamp': _dateFormat.format(DateTime.now()),
        'payload': payload,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> fetchAuditEvents() async {
    final db = _database;
    if (db == null) {
      return const [];
    }

    return db.query('audit_events', orderBy: 'timestamp DESC');
  }

  Future<void> clearAuditEvents() async {
    final db = _database;
    if (db == null) {
      return;
    }

    await db.delete('audit_events');
  }

  Future<void> setLastBuildingId(String buildingId) {
    return _secureStorage.write(key: _lastBuildingKey, value: buildingId);
  }

  Future<String?> getLastBuildingId() {
    return _secureStorage.read(key: _lastBuildingKey);
  }

  Future<void> setLastStartLocation(String buildingId, String destinationId) {
    return _secureStorage.write(key: _lastStartKey(buildingId), value: destinationId);
  }

  Future<String?> getLastStartLocation(String buildingId) {
    return _secureStorage.read(key: _lastStartKey(buildingId));
  }

  Future<void> setLastDestination(String buildingId, String destinationId) {
    return _secureStorage.write(key: _lastDestinationKey(buildingId), value: destinationId);
  }

  Future<String?> getLastDestination(String buildingId) {
    return _secureStorage.read(key: _lastDestinationKey(buildingId));
  }

  // Emergency Contact Methods

  Future<void> saveEmergencyContact(EmergencyContact contact) async {
    final db = _database;
    if (db == null) {
      throw Exception('Database not initialized');
    }

    if (contact.isPrimary) {
      await db.update(
        'emergency_contacts',
        {'isPrimary': 0},
        where: 'isPrimary = ?',
        whereArgs: [1],
      );
    }

    await db.insert(
      'emergency_contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateEmergencyContact(EmergencyContact contact) async {
    final db = _database;
    if (db == null) {
      throw Exception('Database not initialized');
    }

    if (contact.isPrimary) {
      await db.update(
        'emergency_contacts',
        {'isPrimary': 0},
        where: 'isPrimary = ? AND id != ?',
        whereArgs: [1, contact.id],
      );
    }

    await db.update(
      'emergency_contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<List<EmergencyContact>> getEmergencyContacts() async {
    final db = _database;
    if (db == null) {
      return [];
    }

    final maps = await db.query(
      'emergency_contacts',
      orderBy: 'isPrimary DESC, name COLLATE NOCASE',
    );
    return maps.map((map) => EmergencyContact.fromMap(map)).toList();
  }

  Future<EmergencyContact?> getPrimaryEmergencyContact() async {
    final db = _database;
    if (db == null) {
      return null;
    }

    final maps = await db.query(
      'emergency_contacts',
      where: 'isPrimary = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return EmergencyContact.fromMap(maps.first);
  }

  Future<void> deleteEmergencyContact(String id) async {
    final db = _database;
    if (db == null) {
      return;
    }

    await db.delete(
      'emergency_contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Preferences

  Future<Preferences?> getPreferences() async {
    final db = _database;
    if (db == null) {
      return null;
    }

    final maps = await db.query('preferences', limit: 1);
    if (maps.isEmpty) {
      return null;
    }

    return Preferences.fromMap(maps.first);
  }

  Future<void> savePreferences(Preferences preferences) async {
    final db = _database;
    if (db == null) {
      throw Exception('Database not initialized');
    }

    await db.insert(
      'preferences',
      preferences.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Favorites

  Future<List<FavoriteDestination>> getFavorites({bool onlyActive = false}) async {
    final db = _database;
    if (db == null) {
      return [];
    }

    final maps = await db.query(
      'favorites',
      where: onlyActive ? 'isActive = ?' : null,
      whereArgs: onlyActive ? [1] : null,
      orderBy: 'sortIndex ASC, name COLLATE NOCASE',
    );
    return maps.map((map) => FavoriteDestination.fromMap(map)).toList();
  }

  Future<void> saveFavorite(FavoriteDestination favorite) async {
    final db = _database;
    if (db == null) {
      throw Exception('Database not initialized');
    }

    await db.insert(
      'favorites',
      favorite.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFavorite(String id) async {
    final db = _database;
    if (db == null) {
      return;
    }

    await db.delete(
      'favorites',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> replaceFavorites(List<FavoriteDestination> favorites) async {
    final db = _database;
    if (db == null) {
      throw Exception('Database not initialized');
    }

    final batch = db.batch();
    for (final favorite in favorites) {
      batch.update(
        'favorites',
        favorite.toMap(),
        where: 'id = ?',
        whereArgs: [favorite.id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> dispose() async {
    await _database?.close();
  }
}
