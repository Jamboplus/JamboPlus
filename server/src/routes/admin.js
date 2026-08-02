const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { verifyPassword } = require('../crypto-util');
const { issueAdminToken } = require('../jwt');
const { audit, loadAppConfigRow } = require('../db');
const { adminAuthMiddleware } = require('../middleware/adminAuth');
const {
  parseBool,
  parseInt: parseIntSafe,
  parseDouble,
  channelToJson,
  carouselToJson,
  pricingToJson,
  userToJson,
  appConfigForAdmin,
} = require('../serializers');

function createAdminRoutes(db) {
  const router = express.Router();

  router.post('/login', (req, res) => {
    const email = (req.body.email || '').trim().toLowerCase();
    const password = req.body.password || '';
    if (!email || !password) {
      return res.status(400).json({ error: 'email and password required' });
    }

    const row = db.prepare('SELECT id, email, password_hash, role FROM admins WHERE email = ?').get(email);
    if (!row || !verifyPassword(password, row.password_hash)) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = issueAdminToken({ adminId: row.id, email: row.email, role: row.role });
    return res.json({
      token,
      expiresInHours: 24,
      admin: { id: row.id, email: row.email, role: row.role },
    });
  });

  router.use(adminAuthMiddleware);

  router.get('/dashboard', (req, res) => {
    const userCount = db.prepare('SELECT COUNT(*) AS c FROM users').get().c;
    const premiumCount = db
      .prepare(
        `SELECT COUNT(*) AS c FROM users
         WHERE package_type = 'premium'
           AND (expiry_date IS NULL OR expiry_date >= ?)`,
      )
      .get(new Date().toISOString()).c;
    const channelCount = db.prepare('SELECT COUNT(*) AS c FROM channels').get().c;
    const dateKey = new Date().toISOString().slice(0, 10);
    const rev = db.prepare('SELECT amount, transaction_count FROM revenue_daily WHERE date = ?').get(dateKey);

    res.json({
      userCount,
      premiumCount,
      channelCount,
      todayRevenue: rev ? rev.amount : 0,
      todayTransactionCount: rev ? rev.transaction_count : 0,
    });
  });

  // Users
  router.get('/users', (_req, res) => {
    const rows = db.prepare('SELECT * FROM users ORDER BY created_at DESC').all();
    res.json(rows.map(userToJson));
  });

  router.get('/users/:id', (req, res) => {
    const row = db.prepare('SELECT * FROM users WHERE id = ?').get(req.params.id);
    if (!row) return res.status(404).json({ error: 'User not found' });
    return res.json(userToJson(row));
  });

  router.post('/users', (req, res) => {
    const name = req.body.name || 'Free User';
    const phone = String(req.body.phone || '').replace(/\D/g, '');
    if (phone.length < 9) {
      return res.status(400).json({ error: 'Simu sahihi inahitajika' });
    }
    const packageType = req.body.packageType || 'free';
    const expiryDate = req.body.expiryDate ?? null;
    const id = uuidv4();
    const createdAt = new Date().toISOString();

    const dup = db.prepare('SELECT id FROM users WHERE phone = ?').get(phone);
    if (dup) {
      return res.status(409).json({ error: 'Namba hii tayari ipo' });
    }

    db.prepare(
      'INSERT INTO users (id, name, phone, package_type, expiry_date, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    ).run(id, name, phone, packageType, expiryDate, createdAt);
    audit(db, req.admin.adminId, `user.create:${id}`);

    return res.status(201).json(userToJson({ id, name, phone, package_type: packageType, expiry_date: expiryDate, created_at: createdAt }));
  });

  router.put('/users/:id', (req, res) => {
    const existing = db.prepare('SELECT id FROM users WHERE id = ?').get(req.params.id);
    if (!existing) return res.status(404).json({ error: 'User not found' });

    const { name, packageType } = req.body;
    if (name != null) db.prepare('UPDATE users SET name = ? WHERE id = ?').run(name, req.params.id);
    if (Object.prototype.hasOwnProperty.call(req.body, 'phone')) {
      const phone = String(req.body.phone || '').replace(/\D/g, '');
      if (phone.length < 9) {
        return res.status(400).json({ error: 'Simu sahihi inahitajika' });
      }
      const dup = db.prepare('SELECT id FROM users WHERE phone = ? AND id != ?').get(phone, req.params.id);
      if (dup) return res.status(409).json({ error: 'Namba hii tayari ipo' });
      db.prepare('UPDATE users SET phone = ? WHERE id = ?').run(phone, req.params.id);
    }
    if (packageType != null) {
      db.prepare('UPDATE users SET package_type = ? WHERE id = ?').run(packageType, req.params.id);
    }
    if (Object.prototype.hasOwnProperty.call(req.body, 'expiryDate')) {
      db.prepare('UPDATE users SET expiry_date = ? WHERE id = ?').run(req.body.expiryDate, req.params.id);
    }

    audit(db, req.admin.adminId, `user.update:${req.params.id}`);
    const row = db.prepare('SELECT * FROM users WHERE id = ?').get(req.params.id);
    return res.json(userToJson(row));
  });

  router.delete('/users/:id', (req, res) => {
    const existing = db.prepare('SELECT id FROM users WHERE id = ?').get(req.params.id);
    if (!existing) return res.status(404).json({ error: 'User not found' });
    db.prepare('DELETE FROM users WHERE id = ?').run(req.params.id);
    audit(db, req.admin.adminId, `user.delete:${req.params.id}`);
    return res.json({ deleted: true });
  });

  /** Wipe every end-user account (does not touch admins). */
  router.delete('/users', (req, res) => {
    const info = db.prepare('DELETE FROM users').run();
    audit(db, req.admin.adminId, `user.delete_all:${info.changes}`);
    return res.json({ deleted: info.changes });
  });

  // Channels
  router.get('/channels', (_req, res) => {
    const rows = db.prepare('SELECT * FROM channels ORDER BY sort_order ASC, name ASC').all();
    res.json(rows.map(channelToJson));
  });

  router.get('/channels/:id', (req, res) => {
    const row = db.prepare('SELECT * FROM channels WHERE id = ?').get(req.params.id);
    if (!row) return res.status(404).json({ error: 'Channel not found' });
    return res.json(channelToJson(row));
  });

  router.post('/channels', (req, res) => {
    const id = (req.body.id || '').trim() || uuidv4();
    const name = req.body.name;
    if (!name) return res.status(400).json({ error: 'name required' });

    db.prepare(`
      INSERT INTO channels (
        id, name, image, category, description, is_premium, is_live,
        stream_url, player_engine, drm_type, drm_license_url, drm_clear_key,
        sort_order, enabled
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      id,
      name,
      req.body.image || '',
      req.body.category || 'Bure',
      req.body.description || '',
      parseBool(req.body.isPremium) ? 1 : 0,
      parseBool(req.body.isLive) ? 1 : 0,
      req.body.streamUrl || '',
      req.body.playerEngine ?? null,
      req.body.drmType ?? null,
      req.body.drmLicenseUrl ?? null,
      req.body.drmClearKey ?? null,
      parseIntSafe(req.body.sortOrder),
      parseBool(req.body.enabled, true) ? 1 : 0,
    );
    audit(db, req.admin.adminId, `channel.create:${id}`);
    const row = db.prepare('SELECT * FROM channels WHERE id = ?').get(id);
    return res.status(201).json(channelToJson(row));
  });

  router.put('/channels/:id', (req, res) => {
    const current = db.prepare('SELECT * FROM channels WHERE id = ?').get(req.params.id);
    if (!current) return res.status(404).json({ error: 'Channel not found' });

    db.prepare(`
      UPDATE channels SET
        name = ?, image = ?, category = ?, description = ?,
        is_premium = ?, is_live = ?, stream_url = ?,
        player_engine = ?, drm_type = ?, drm_license_url = ?, drm_clear_key = ?,
        sort_order = ?, enabled = ?
      WHERE id = ?
    `).run(
      req.body.name ?? current.name,
      req.body.image ?? current.image,
      req.body.category ?? current.category,
      req.body.description ?? current.description,
      parseBool(req.body.isPremium, current.is_premium === 1) ? 1 : 0,
      parseBool(req.body.isLive, current.is_live === 1) ? 1 : 0,
      req.body.streamUrl ?? current.stream_url,
      Object.prototype.hasOwnProperty.call(req.body, 'playerEngine') ? req.body.playerEngine : current.player_engine,
      Object.prototype.hasOwnProperty.call(req.body, 'drmType') ? req.body.drmType : current.drm_type,
      Object.prototype.hasOwnProperty.call(req.body, 'drmLicenseUrl') ? req.body.drmLicenseUrl : current.drm_license_url,
      Object.prototype.hasOwnProperty.call(req.body, 'drmClearKey') ? req.body.drmClearKey : current.drm_clear_key,
      Object.prototype.hasOwnProperty.call(req.body, 'sortOrder') ? parseIntSafe(req.body.sortOrder) : current.sort_order,
      parseBool(req.body.enabled, current.enabled === 1) ? 1 : 0,
      req.params.id,
    );
    audit(db, req.admin.adminId, `channel.update:${req.params.id}`);
    const row = db.prepare('SELECT * FROM channels WHERE id = ?').get(req.params.id);
    return res.json(channelToJson(row));
  });

  router.delete('/channels/:id', (req, res) => {
    const existing = db.prepare('SELECT id FROM channels WHERE id = ?').get(req.params.id);
    if (!existing) return res.status(404).json({ error: 'Channel not found' });
    db.prepare('DELETE FROM channels WHERE id = ?').run(req.params.id);
    audit(db, req.admin.adminId, `channel.delete:${req.params.id}`);
    return res.json({ deleted: true });
  });

  // Carousel
  router.get('/carousel', (_req, res) => {
    const rows = db.prepare('SELECT * FROM carousel ORDER BY sort_order ASC').all();
    res.json(rows.map(carouselToJson));
  });

  router.get('/carousel/:id', (req, res) => {
    const row = db.prepare('SELECT * FROM carousel WHERE id = ?').get(req.params.id);
    if (!row) return res.status(404).json({ error: 'Carousel item not found' });
    return res.json(carouselToJson(row));
  });

  router.post('/carousel', (req, res) => {
    const id = (req.body.id || '').trim() || uuidv4();
    const { image, title } = req.body;
    if (!image || !title) return res.status(400).json({ error: 'image and title required' });

    db.prepare(
      'INSERT INTO carousel (id, image, title, link, sort_order, enabled) VALUES (?, ?, ?, ?, ?, ?)',
    ).run(id, image, title, req.body.link || '', parseIntSafe(req.body.sortOrder), parseBool(req.body.enabled, true) ? 1 : 0);
    audit(db, req.admin.adminId, `carousel.create:${id}`);
    const row = db.prepare('SELECT * FROM carousel WHERE id = ?').get(id);
    return res.status(201).json(carouselToJson(row));
  });

  router.put('/carousel/:id', (req, res) => {
    const current = db.prepare('SELECT * FROM carousel WHERE id = ?').get(req.params.id);
    if (!current) return res.status(404).json({ error: 'Carousel item not found' });

    db.prepare(
      'UPDATE carousel SET image = ?, title = ?, link = ?, sort_order = ?, enabled = ? WHERE id = ?',
    ).run(
      req.body.image ?? current.image,
      req.body.title ?? current.title,
      req.body.link ?? current.link,
      Object.prototype.hasOwnProperty.call(req.body, 'sortOrder') ? parseIntSafe(req.body.sortOrder) : current.sort_order,
      parseBool(req.body.enabled, current.enabled === 1) ? 1 : 0,
      req.params.id,
    );
    audit(db, req.admin.adminId, `carousel.update:${req.params.id}`);
    const row = db.prepare('SELECT * FROM carousel WHERE id = ?').get(req.params.id);
    return res.json(carouselToJson(row));
  });

  router.delete('/carousel/:id', (req, res) => {
    const existing = db.prepare('SELECT id FROM carousel WHERE id = ?').get(req.params.id);
    if (!existing) return res.status(404).json({ error: 'Carousel item not found' });
    db.prepare('DELETE FROM carousel WHERE id = ?').run(req.params.id);
    audit(db, req.admin.adminId, `carousel.delete:${req.params.id}`);
    return res.json({ deleted: true });
  });

  // Pricing
  router.get('/pricing', (_req, res) => {
    const rows = db.prepare('SELECT * FROM pricing ORDER BY sort_order ASC').all();
    res.json(rows.map(pricingToJson));
  });

  router.get('/pricing/:id', (req, res) => {
    const row = db.prepare('SELECT * FROM pricing WHERE id = ?').get(req.params.id);
    if (!row) return res.status(404).json({ error: 'Pricing plan not found' });
    return res.json(pricingToJson(row));
  });

  router.post('/pricing', (req, res) => {
    const id = uuidv4();
    const name = req.body.name;
    if (!name) return res.status(400).json({ error: 'name required' });

    db.prepare(
      'INSERT INTO pricing (id, name, duration_days, price, original_price, enabled, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)',
    ).run(
      id,
      name,
      parseIntSafe(req.body.durationDays, 30),
      parseDouble(req.body.price),
      parseDouble(req.body.originalPrice),
      parseBool(req.body.enabled, true) ? 1 : 0,
      parseIntSafe(req.body.sortOrder),
    );
    audit(db, req.admin.adminId, `pricing.create:${id}`);
    const row = db.prepare('SELECT * FROM pricing WHERE id = ?').get(id);
    return res.status(201).json(pricingToJson(row));
  });

  router.put('/pricing/:id', (req, res) => {
    const current = db.prepare('SELECT * FROM pricing WHERE id = ?').get(req.params.id);
    if (!current) return res.status(404).json({ error: 'Pricing plan not found' });

    db.prepare(`
      UPDATE pricing SET
        name = ?, duration_days = ?, price = ?, original_price = ?,
        enabled = ?, sort_order = ?
      WHERE id = ?
    `).run(
      req.body.name ?? current.name,
      Object.prototype.hasOwnProperty.call(req.body, 'durationDays') ? parseIntSafe(req.body.durationDays) : current.duration_days,
      Object.prototype.hasOwnProperty.call(req.body, 'price') ? parseDouble(req.body.price) : current.price,
      Object.prototype.hasOwnProperty.call(req.body, 'originalPrice') ? parseDouble(req.body.originalPrice) : current.original_price,
      parseBool(req.body.enabled, current.enabled === 1) ? 1 : 0,
      Object.prototype.hasOwnProperty.call(req.body, 'sortOrder') ? parseIntSafe(req.body.sortOrder) : current.sort_order,
      req.params.id,
    );
    audit(db, req.admin.adminId, `pricing.update:${req.params.id}`);
    const row = db.prepare('SELECT * FROM pricing WHERE id = ?').get(req.params.id);
    return res.json(pricingToJson(row));
  });

  router.delete('/pricing/:id', (req, res) => {
    const existing = db.prepare('SELECT id FROM pricing WHERE id = ?').get(req.params.id);
    if (!existing) return res.status(404).json({ error: 'Pricing plan not found' });
    db.prepare('DELETE FROM pricing WHERE id = ?').run(req.params.id);
    audit(db, req.admin.adminId, `pricing.delete:${req.params.id}`);
    return res.json({ deleted: true });
  });

  // App config
  router.get('/app-config', (_req, res) => {
    res.json(appConfigForAdmin(loadAppConfigRow(db)));
  });

  router.put('/app-config', (req, res) => {
    const current = loadAppConfigRow(db);
    db.prepare(`
      UPDATE app_config SET
        player_engine = ?, drm_type = ?, stream_origin = ?, stream_referer = ?,
        user_agent = ?, token_refresh_url = ?, stream_user_id = ?,
        app_api_key = ?, app_api_secret = ?, maintenance_mode = ?
      WHERE id = 1
    `).run(
      req.body.playerEngine ?? current.player_engine,
      req.body.drmType ?? current.drm_type,
      req.body.streamOrigin ?? current.stream_origin,
      req.body.streamReferer ?? current.stream_referer,
      req.body.userAgent ?? current.user_agent,
      req.body.tokenRefreshUrl ?? current.token_refresh_url,
      req.body.streamUserId ?? current.stream_user_id,
      req.body.appApiKey ?? current.app_api_key,
      req.body.appApiSecret ?? current.app_api_secret,
      parseBool(req.body.maintenanceMode, current.maintenance_mode === 1) ? 1 : 0,
    );
    audit(db, req.admin.adminId, 'app_config.update');
    return res.json(appConfigForAdmin(loadAppConfigRow(db)));
  });

  return router;
}

module.exports = { createAdminRoutes };
