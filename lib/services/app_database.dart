import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_init.dart';

class AppDatabase {
  static Database? _database;
  static bool _factoryReady = false;

  static Future<Database> open() async {
    final existing = _database;
    if (existing != null) return existing;

    if (!_factoryReady) {
      await initDatabaseFactory();
      _factoryReady = true;
    }

    final String path;
    if (kIsWeb) {
      path = 'travel_equality.db';
    } else {
      path = join(await getDatabasesPath(), 'travel_equality.db');
    }

    final database = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            photo TEXT,
            phone TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE users ADD COLUMN photo TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE users ADD COLUMN phone TEXT');
        }
      },
    );
    _database = database;
    return database;
  }
}
