import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'essivi_offline.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE deliveries ADD COLUMN photo_url TEXT;");
          await db.execute("ALTER TABLE deliveries ADD COLUMN signature_url TEXT;");
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE deliveries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER,
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
    Database db = await database;
    return await db.insert('deliveries', row);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedDeliveries() async {
    Database db = await database;
    return await db.query('deliveries', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<int> markAsSynced(int id) async {
    Database db = await database;
    return await db.update(
      'deliveries',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSyncedDeliveries() async {
    Database db = await database;
    await db.delete('deliveries', where: 'is_synced = ?', whereArgs: [1]);
  }
}
