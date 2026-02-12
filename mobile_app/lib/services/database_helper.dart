import 'dart:async';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart'; // Pour kIsWeb
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static bool _isInitialized = false;

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    if (!_isInitialized) {
      try {
        _database = await _initDatabase();
        _isInitialized = true;
      } catch (e) {
        print("❌ Erreur d'initialisation de la base de données: $e");
        // En cas d'erreur, retourner une base de données vide simulée
        _database = await _createMockDatabase();
        _isInitialized = true;
      }
    }
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // SUR LE WEB, PAS DE SQFLITE, ON UTILISE LE MOCK DIRECTEMENT
    if (kIsWeb) {
      print("🌐 Web détecté : Utilisation de MockDatabase (Mémoire)");
      return await _createMockDatabase();
    }

    try {
      String path = join(await getDatabasesPath(), 'essivi_offline.db');
      return await openDatabase(
        path,
        version: 3, // ⚠️ INCRÉMENTÉ POUR FORCER LA MIGRATION
        onCreate: _onCreate,
        onUpgrade: (db, oldVersion, newVersion) async {
          // Migration v1 → v2
          if (oldVersion < 2) {
            await db.execute("ALTER TABLE deliveries ADD COLUMN photo_url TEXT;");
            await db.execute("ALTER TABLE deliveries ADD COLUMN signature_url TEXT;");
          }
          // Migration v2 → v3
          if (oldVersion < 3) {
            await db.execute("ALTER TABLE deliveries ADD COLUMN client_name TEXT;");
            await db.execute("ALTER TABLE deliveries ADD COLUMN items_json TEXT;");
            await db.execute("ALTER TABLE deliveries ADD COLUMN order_id INTEGER;");
          }
        },
      );
    } catch (e) {
      print("❌ Erreur lors de la création de la base de données: $e");
      rethrow;
    }
  }

  Future<Database> _createMockDatabase() async {
    print("🔄 Utilisation d'une base de données simulée (mock)");
    return MockDatabase();
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE deliveries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER,
        client_name TEXT,
        items_json TEXT,
        order_id INTEGER,
        quantity_vitale INTEGER,
        quantity_voltic INTEGER,
        amount REAL,
        gps_lat REAL,
        gps_lng REAL,
        photo_url TEXT,
        signature_url TEXT,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<int> insertDelivery(Map<String, dynamic> row) async {
    try {
      Database db = await database;
      return await db.insert('deliveries', row);
    } catch (e) {
      print("❌ Erreur lors de l'insertion de livraison: $e");
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedDeliveries() async {
    try {
      Database db = await database;
      return await db.query('deliveries', where: 'is_synced = ?', whereArgs: [0]);
    } catch (e) {
      print("❌ Erreur lors de la récupération des livraisons non synchronisées: $e");
      return [];
    }
  }

  Future<int> markAsSynced(int id) async {
    try {
      Database db = await database;
      return await db.update(
        'deliveries',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print("❌ Erreur lors du marquage comme synchronisé: $e");
      return -1;
    }
  }

  Future<void> deleteSyncedDeliveries() async {
    try {
      Database db = await database;
      await db.delete('deliveries', where: 'is_synced = ?', whereArgs: [1]);
    } catch (e) {
      print("❌ Erreur lors de la suppression des livraisons synchronisées: $e");
    }
  }
}

// Classe Mock pour simuler la base de données en cas d'erreur
class MockDatabase implements Database {
  final List<Map<String, dynamic>> _deliveries = [];
  int _nextId = 1;

  @override
  Future<int> insert(String table, Map<String, Object?> values, {ConflictAlgorithm? conflictAlgorithm, String? nullColumnHack}) async {
    final delivery = Map<String, dynamic>.from(values);
    delivery['id'] = _nextId++;
    delivery['is_synced'] = 0;
    _deliveries.add(delivery);
    print("📝 Mock: Insertion de livraison ${delivery['id']}");
    return delivery['id'];
  }

  @override
  Future<List<Map<String, dynamic>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) async {
    if (where == 'is_synced = ?' && whereArgs?[0] == 0) {
      return _deliveries.where((d) => d['is_synced'] == 0).toList();
    }
    return _deliveries;
  }

  @override
  Future<int> update(String table, Map<String, Object?> values, {ConflictAlgorithm? conflictAlgorithm, String? where, List<Object?>? whereArgs}) async {
    if (where == 'id = ?' && whereArgs != null) {
      final id = whereArgs[0];
      final index = _deliveries.indexWhere((d) => d['id'] == id);
      if (index != -1) {
        _deliveries[index].addAll(values);
        print("📝 Mock: Mise à jour de livraison $id");
        return 1;
      }
    }
    return 0;
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    if (where == 'is_synced = ?' && whereArgs?[0] == 1) {
      final initialLength = _deliveries.length;
      _deliveries.removeWhere((d) => d['is_synced'] == 1);
      print("📝 Mock: Suppression de ${initialLength - _deliveries.length} livraisons synchronisées");
      return initialLength - _deliveries.length;
    }
    return 0;
  }

  // Implémentations minimales des autres méthodes requises
  @override
  dynamic noSuchMethod(Invocation invocation) {
    print("📝 Mock: Appel de méthode ${invocation.memberName}");
    return Future.value(null);
  }
}
