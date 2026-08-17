const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');
const { v4: uuidv4 } = require('uuid');
const config = require('./config');
const { hashPassword } = require('./crypto-util');

function migrate(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS admins (
      id TEXT PRIMARY KEY,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      package_type TEXT NOT NULL DEFAULT 'free',
      expiry_date TEXT,
      created_at TEXT NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS users_phone_unique ON users(phone) WHERE phone != '';
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
    );
    CREATE TABLE IF NOT EXISTS carousel (
      id TEXT PRIMARY KEY,
      image TEXT NOT NULL,
      title TEXT NOT NULL,
      link TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      enabled INTEGER NOT NULL DEFAULT 1
    );
    CREATE TABLE IF NOT EXISTS pricing (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      duration_days INTEGER NOT NULL,
      price REAL NOT NULL,
      original_price REAL NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER NOT NULL DEFAULT 0
    );
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
    );
    CREATE TABLE IF NOT EXISTS revenue_daily (
      date TEXT PRIMARY KEY,
      amount REAL NOT NULL DEFAULT 0,
      transaction_count INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS audit_log (
      id TEXT PRIMARY KEY,
      admin_id TEXT NOT NULL,
      action TEXT NOT NULL,
      at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS payment_transactions (
      id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL UNIQUE,
      user_id TEXT,
      user_name TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL,
      plan_id TEXT NOT NULL,
      plan_name TEXT NOT NULL DEFAULT '',
      amount REAL NOT NULL,
      currency TEXT NOT NULL DEFAULT 'TZS',
      status TEXT NOT NULL DEFAULT 'pending',
      provider TEXT NOT NULL DEFAULT 'sonicpesa',
      created_at TEXT NOT NULL,
      completed_at TEXT,
      activated_at TEXT
    );
    CREATE INDEX IF NOT EXISTS payment_transactions_phone_idx ON payment_transactions(phone);
    CREATE INDEX IF NOT EXISTS payment_transactions_status_idx ON payment_transactions(status);
  `);
  migrateUserDeviceColumns(db);
}

function migrateUserDeviceColumns(db) {
  const cols = db.prepare('PRAGMA table_info(users)').all().map((c) => c.name);
  if (!cols.includes('device_id')) {
    db.exec('ALTER TABLE users ADD COLUMN device_id TEXT');
  }
  if (!cols.includes('last_open_at')) {
    db.exec('ALTER TABLE users ADD COLUMN last_open_at TEXT');
  }
  if (!cols.includes('fcm_token')) {
    db.exec('ALTER TABLE users ADD COLUMN fcm_token TEXT');
  }
  if (!cols.includes('platform')) {
    db.exec("ALTER TABLE users ADD COLUMN platform TEXT NOT NULL DEFAULT ''");
  }
  if (!cols.includes('app_version')) {
    db.exec("ALTER TABLE users ADD COLUMN app_version TEXT NOT NULL DEFAULT ''");
  }
  db.exec('DROP INDEX IF EXISTS users_phone_unique');
  db.exec("CREATE UNIQUE INDEX IF NOT EXISTS users_phone_unique ON users(phone) WHERE phone != ''");
  db.exec(
    "CREATE UNIQUE INDEX IF NOT EXISTS users_device_id_unique ON users(device_id) WHERE device_id IS NOT NULL AND device_id != ''",
  );
}

function seedIfEmpty(db) {
  const count = db.prepare('SELECT COUNT(*) AS c FROM admins').get().c;
  if (count > 0) return;

  const adminEmail = (process.env.ADMIN_EMAIL || 'jamboplus@gmail.com').trim().toLowerCase();
  const adminPassword = process.env.ADMIN_PASSWORD || 'Chundabadi6%';
  const apiKey = process.env.APP_API_KEY || 'jamboplus-dev-key';
  const apiSecret = process.env.APP_API_SECRET || 'jamboplus-dev-secret-change-in-production';

  db.prepare(
    'INSERT INTO admins (id, email, password_hash, role) VALUES (?, ?, ?, ?)',
  ).run(uuidv4(), adminEmail, hashPassword(adminPassword), 'superadmin');

  db.prepare(`
    INSERT INTO app_config (
      id, player_engine, drm_type, stream_origin, stream_referer,
      user_agent, token_refresh_url, stream_user_id,
      app_api_key, app_api_secret, maintenance_mode
    ) VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
  `).run('exoplayer', 'none', '', '', 'JamboPlus/1.0', '', '', apiKey, apiSecret);

  const carouselRows = [
    ['1', 'https://picsum.photos/seed/soka1/800/400', 'Mpira wa Moja kwa Moja', '', 0],
    ['2', 'https://picsum.photos/seed/soka2/800/400', 'Tamthilia Bora Zaidi', '', 1],
    ['3', 'https://picsum.photos/seed/soka3/800/400', 'Habari za Leo', '', 2],
    ['4', 'https://picsum.photos/seed/soka4/800/400', 'Katuni kwa Watoto', '', 3],
  ];
  const insertCarousel = db.prepare(
    'INSERT INTO carousel (id, image, title, link, sort_order, enabled) VALUES (?, ?, ?, ?, ?, 1)',
  );
  for (const row of carouselRows) insertCarousel.run(...row);

  const pricingRows = [
    [uuidv4(), 'Wiki 1', 7, 2000, 5000, 0],
    [uuidv4(), 'Mwezi 1', 30, 5000, 12000, 1],
    [uuidv4(), 'Miezi 3', 90, 12000, 36000, 2],
    [uuidv4(), 'Mwaka 1', 365, 40000, 144000, 3],
  ];
  const insertPricing = db.prepare(
    'INSERT INTO pricing (id, name, duration_days, price, original_price, enabled, sort_order) VALUES (?, ?, ?, ?, ?, 1, ?)',
  );
  for (const row of pricingRows) insertPricing.run(...row);

  const channelRows = [
    ['b1', 'Soka TV Bure', 'https://picsum.photos/seed/bure1/400/300', 'Bure', 'Chaneli ya mpira bure', 0, 1, ''],
    ['b2', 'Tamthilia Bure', 'https://picsum.photos/seed/bure2/400/300', 'Bure', 'Tamthilia bure kila siku', 0, 1, ''],
    ['b3', 'Habari Bure', 'https://picsum.photos/seed/bure3/400/300', 'Bure', 'Habari za Tanzania', 0, 0, ''],
    ['b4', 'Katuni Bure', 'https://picsum.photos/seed/bure4/400/300', 'Bure', 'Katuni kwa watoto', 0, 1, ''],
    ['b5', 'Wanyama Bure', 'https://picsum.photos/seed/bure5/400/300', 'Bure', 'Maisha ya wanyama', 0, 0, ''],
    ['m1', 'Simba SC Live', 'https://picsum.photos/seed/mpira1/500/350', 'Mpira', 'Mechi za Simba moja kwa moja', 1, 1, ''],
    ['m2', 'Yanga Live', 'https://picsum.photos/seed/mpira2/500/350', 'Mpira', 'Mechi za Yanga moja kwa moja', 1, 1, ''],
    ['m3', 'Ligi Kuu TZ', 'https://picsum.photos/seed/mpira3/500/350', 'Mpira', 'Ligi Kuu Tanzania', 1, 1, ''],
    ['m4', 'Premier League', 'https://picsum.photos/seed/mpira4/500/350', 'Mpira', 'Premier League ya Uingereza', 1, 1, ''],
    ['m5', 'Champions League', 'https://picsum.photos/seed/mpira5/500/350', 'Mpira', 'UEFA Champions League', 1, 0, ''],
    ['t1', 'Selina', 'https://picsum.photos/seed/tam1/400/550', 'Tamthilia', 'Tamthilia ya Selina', 1, 1, ''],
    ['t2', 'Siri ya Mtungi', 'https://picsum.photos/seed/tam2/400/550', 'Tamthilia', 'Tamthilia ya Siri ya Mtungi', 1, 0, ''],
    ['t3', "Mama's Daughter", 'https://picsum.photos/seed/tam3/400/550', 'Tamthilia', 'Tamthilia ya kuvutia', 1, 1, ''],
    ['t4', 'Aziza', 'https://picsum.photos/seed/tam4/400/550', 'Tamthilia', 'Tamthilia ya Aziza', 1, 0, ''],
    ['h1', 'TBC Taarifa', 'https://picsum.photos/seed/hab1/200/200', 'Habari', 'Habari za Tanzania na duniani', 0, 1, ''],
    ['h2', 'Clouds Media', 'https://picsum.photos/seed/hab2/200/200', 'Habari', 'Habari, burudani na michezo', 0, 1, ''],
    ['h3', 'Azam TV Habari', 'https://picsum.photos/seed/hab3/200/200', 'Habari', 'Taarifa za kila dakika', 1, 0, ''],
    ['h4', 'ITV Habari', 'https://picsum.photos/seed/hab4/200/200', 'Habari', 'Habari za ndani na nje ya nchi', 0, 0, ''],
    ['k1', 'Cartoon Plus', 'https://picsum.photos/seed/kat1/400/300', 'Katuni', 'Katuni za kufurahisha', 0, 1, ''],
    ['k2', 'Kids Zone', 'https://picsum.photos/seed/kat2/400/300', 'Katuni', 'Burudani kwa watoto', 1, 0, ''],
    ['k3', 'Anime Swahili', 'https://picsum.photos/seed/kat3/400/300', 'Katuni', 'Anime kwa Kiswahili', 1, 1, ''],
    ['k4', 'Funny Toons', 'https://picsum.photos/seed/kat4/400/300', 'Katuni', 'Katuni za kuchekesha', 0, 0, ''],
    ['w1', 'Safari Live', 'https://picsum.photos/seed/wan1/400/300', 'Wanyama', 'Maisha ya wanyama porini', 1, 1, ''],
    ['w2', 'Ocean World', 'https://picsum.photos/seed/wan2/400/300', 'Wanyama', 'Maisha ya baharini', 1, 0, ''],
    ['w3', 'Bird Paradise', 'https://picsum.photos/seed/wan3/400/300', 'Wanyama', 'Ndege wa duniani', 0, 1, ''],
    ['w4', 'Wild Africa', 'https://picsum.photos/seed/wan4/400/300', 'Wanyama', 'Wanyama wa Afrika', 1, 0, ''],
  ];
  const insertChannel = db.prepare(`
    INSERT INTO channels (
      id, name, image, category, description, is_premium, is_live,
      stream_url, player_engine, drm_type, drm_license_url, drm_clear_key,
      sort_order, enabled
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, ?, 1)
  `);
  let order = 0;
  for (const ch of channelRows) {
    insertChannel.run(ch[0], ch[1], ch[2], ch[3], ch[4], ch[5], ch[6], ch[7], order++);
  }

  const today = new Date();
  const dateKey = today.toISOString().slice(0, 10);
  db.prepare(
    'INSERT INTO revenue_daily (date, amount, transaction_count) VALUES (?, 0, 0) ON CONFLICT(date) DO NOTHING',
  ).run(dateKey);
}

function ensureAdminFromEnv(db) {
  const adminEmail = (process.env.ADMIN_EMAIL || 'jamboplus@gmail.com').trim().toLowerCase();
  const adminPassword = process.env.ADMIN_PASSWORD || 'Chundabadi6%';
  const passwordHash = hashPassword(adminPassword);

  const existing = db.prepare('SELECT id, email FROM admins WHERE role = ? ORDER BY rowid LIMIT 1').get('superadmin')
    || db.prepare('SELECT id, email FROM admins ORDER BY rowid LIMIT 1').get();

  if (!existing) {
    db.prepare(
      'INSERT INTO admins (id, email, password_hash, role) VALUES (?, ?, ?, ?)',
    ).run(uuidv4(), adminEmail, passwordHash, 'superadmin');
    console.log(`Admin created: ${adminEmail}`);
    return;
  }

  db.prepare('UPDATE admins SET email = ?, password_hash = ?, role = ? WHERE id = ?').run(
    adminEmail,
    passwordHash,
    'superadmin',
    existing.id,
  );
  console.log(`Admin credentials synced: ${adminEmail}`);
}

function openDatabase() {
  fs.mkdirSync(path.dirname(config.dbPath), { recursive: true });
  const db = new Database(config.dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  migrate(db);
  seedIfEmpty(db);
  ensureAdminFromEnv(db);
  return db;
}

function loadAppConfigRow(db) {
  const row = db.prepare('SELECT * FROM app_config WHERE id = 1').get();
  if (!row) throw new Error('app_config missing');
  return row;
}

function audit(db, adminId, action) {
  db.prepare('INSERT INTO audit_log (id, admin_id, action, at) VALUES (?, ?, ?, ?)').run(
    uuidv4(),
    adminId,
    action,
    new Date().toISOString(),
  );
}

module.exports = { openDatabase, loadAppConfigRow, audit, seedIfEmpty, ensureAdminFromEnv };
