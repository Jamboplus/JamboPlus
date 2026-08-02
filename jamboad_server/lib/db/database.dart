import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../config/env.dart';
import 'seed.dart';

const _uuid = Uuid();
bool _sqliteLoaderConfigured = false;

void _ensureSqliteLoader() {
  if (_sqliteLoaderConfigured) return;
  _sqliteLoaderConfigured = true;
  if (!Platform.isLinux) return;

  open.overrideFor(OperatingSystem.linux, () {
    const candidates = [
      'libsqlite3.so',
      'libsqlite3.so.0',
      '/usr/lib/x86_64-linux-gnu/libsqlite3.so',
      '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
    ];
    for (final path in candidates) {
      try {
        return DynamicLibrary.open(path);
      } catch (_) {}
    }
    throw StateError(
      'Could not load SQLite. Install libsqlite3 (e.g. apt install libsqlite3-dev).',
    );
  });
}

class AppDatabase {
  AppDatabase(this._db);

  final Database _db;

  Database get raw => _db;

  static AppDatabase open(Env env) {
    _ensureSqliteLoader();
    final file = File(env.dbPath);
    file.parent.createSync(recursive: true);
    final db = sqlite3.open(env.dbPath);
    final appDb = AppDatabase(db);
    appDb._migrate();
    seedIfEmpty(appDb);
    return appDb;
  }

  void _migrate() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS admins (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        package_type TEXT NOT NULL DEFAULT 'free',
        expiry_date TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS channels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        image TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        is_premium INTEGER NOT NULL DEFAULT 0,
        is_live INTEGER NOT NULL DEFAULT 0,
        stream_url TEXT NOT NULL DEFAULT '',
        player_engine TEXT,
        drm_type TEXT,
        drm_license_url TEXT,
        drm_clear_key TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS carousel (
        id TEXT PRIMARY KEY,
        image TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS pricing (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        duration_days INTEGER NOT NULL,
        price REAL NOT NULL,
        original_price REAL NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS app_config (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        player_engine TEXT NOT NULL DEFAULT 'exoplayer',
        drm_type TEXT NOT NULL DEFAULT 'none',
        stream_origin TEXT NOT NULL DEFAULT '',
        stream_referer TEXT NOT NULL DEFAULT '',
        user_agent TEXT NOT NULL DEFAULT '',
        token_refresh_url TEXT NOT NULL DEFAULT '',
        stream_user_id TEXT NOT NULL DEFAULT '',
        app_api_key TEXT NOT NULL DEFAULT '',
        app_api_secret TEXT NOT NULL DEFAULT '',
        maintenance_mode INTEGER NOT NULL DEFAULT 0
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS revenue_daily (
        date TEXT PRIMARY KEY,
        amount REAL NOT NULL DEFAULT 0,
        transaction_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id TEXT PRIMARY KEY,
        admin_id TEXT NOT NULL,
        action TEXT NOT NULL,
        at TEXT NOT NULL
      )
    ''');
  }

  void close() => _db.dispose();

  void audit(String adminId, String action) {
    _db.execute(
      'INSERT INTO audit_log (id, admin_id, action, at) VALUES (?, ?, ?, ?)',
      [
        _uuid.v4(),
        adminId,
        action,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }
}
