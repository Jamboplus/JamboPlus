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

function normalizePhoneDigits(raw) {
  return String(raw || '').replace(/\D/g, '');
}

/** Match DB phones stored as 07…, 255…, or 7… */
function phoneLookupVariants(raw) {
  const digits = normalizePhoneDigits(raw);
  if (!digits) return [];
  const variants = new Set([digits]);
  if (digits.startsWith('255') && digits.length === 12) {
    variants.add(`0${digits.slice(3)}`);
    variants.add(digits.slice(3));
  } else if (digits.startsWith('0') && digits.length === 10) {
    variants.add(`255${digits.slice(1)}`);
    variants.add(digits.slice(1));
  } else if (digits.length === 9 && /^[67]/.test(digits)) {
    variants.add(`0${digits}`);
    variants.add(`255${digits}`);
  }
  return [...variants].filter((v) => v.length >= 9);
}

function findUserByPhoneVariants(db, raw) {
  for (const phone of phoneLookupVariants(raw)) {
    const row = db.prepare('SELECT * FROM users WHERE phone = ?').get(phone);
    if (row) return row;
  }
  return null;
}

function addPremiumDuration(fromDate, amount, unit) {
  const d = new Date(fromDate.getTime());
  const n = Math.max(1, Number(amount) || 1);
  switch (String(unit || 'days')) {
    case 'minutes':
      d.setUTCMinutes(d.getUTCMinutes() + n);
      break;
    case 'hours':
      d.setUTCHours(d.getUTCHours() + n);
      break;
    case 'weeks':
      d.setUTCDate(d.getUTCDate() + n * 7);
      break;
    default:
      d.setUTCDate(d.getUTCDate() + n);
      break;
  }
  return d.toISOString();
}

function looksLikePhone(raw) {
  const trimmed = String(raw || '').trim();
  if (!trimmed) return false;
  const digits = normalizePhoneDigits(trimmed);
  if (digits.length < 9 || digits.length > 12) return false;
  // Reject values that still contain letters (fingerprint IDs).
  if (/[a-z]/i.test(trimmed)) return false;
  if (/^0\d{9}$/.test(digits) || (digits.startsWith('0') && digits.length === 10)) return true;
  if (digits.startsWith('255') && digits.length === 12) return true;
  if (digits.length === 9 && /^[67]/.test(digits)) return true;
  return false;
}

function looksLikeUuid(raw) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    String(raw || '').trim(),
  );
}

function findUserForAccess(db, body = {}) {
  const userId = String(body.userId || body.id || '').trim();
  if (userId && looksLikeUuid(userId)) {
    const byId = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (byId) return byId;
  }

  const phoneRaw = body.phone;
  if (phoneRaw != null && String(phoneRaw).trim() && looksLikePhone(phoneRaw)) {
    const byPhone = findUserByPhoneVariants(db, phoneRaw);
    if (byPhone) return byPhone;
  }

  const deviceId = String(body.deviceId || body.device_id || '').trim();
  if (deviceId.length >= 8 && !looksLikePhone(deviceId) && !looksLikeUuid(deviceId)) {
    const byDevice = db.prepare('SELECT * FROM users WHERE device_id = ?').get(deviceId);
    if (byDevice) return byDevice;
  }

  // Unified identifier: fingerprint / phone / UUID (admin "Kwa ID")
  const identifier = String(body.identifier || body.uniqueId || '').trim();
  const candidates = [...new Set([identifier, userId, deviceId].filter((v) => v.length >= 8))];
  for (const value of candidates) {
    if (looksLikeUuid(value)) {
      const byId = db.prepare('SELECT * FROM users WHERE id = ?').get(value);
      if (byId) return byId;
      continue;
    }
    if (looksLikePhone(value)) {
      const byPhone = findUserByPhoneVariants(db, value);
      if (byPhone) return byPhone;
      continue;
    }
    const byDevice = db.prepare('SELECT * FROM users WHERE device_id = ?').get(value);
    if (byDevice) return byDevice;
  }

  return null;
}

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
    const nowIso = new Date().toISOString();
    const dateKey = nowIso.slice(0, 10);
    const counts = db
      .prepare(
        `SELECT
           (SELECT COUNT(*) FROM users) AS userCount,
           (SELECT COUNT(*) FROM users
             WHERE package_type = 'premium'
               AND (expiry_date IS NULL OR expiry_date >= ?)) AS premiumCount,
           (SELECT COUNT(*) FROM channels) AS channelCount`,
      )
      .get(nowIso);
    const rev = db.prepare('SELECT amount, transaction_count FROM revenue_daily WHERE date = ?').get(dateKey);

    res.json({
      userCount: counts.userCount,
      premiumCount: counts.premiumCount,
      channelCount: counts.channelCount,
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

  /**
   * Grant / revoke premium by userId, phone, OR unique deviceId.
   * POST /v1/admin/users/premium
   * { action?: 'grant'|'revoke', userId?, phone?, deviceId?, amount?, unit? }
   */
  router.post('/users/premium', (req, res) => {
    const action = String(req.body?.action || 'grant').toLowerCase().trim();
    const user = findUserForAccess(db, req.body || {});
    if (!user) {
      return res.status(404).json({
        error: 'Mtumiaji hajapatikana. Tumia kitambulisho cha kifaa, simu, au ID.',
      });
    }

    if (action === 'revoke') {
      db.prepare(
        `UPDATE users SET package_type = 'free', expiry_date = NULL WHERE id = ?`,
      ).run(user.id);
      audit(db, req.admin.adminId, `user.revoke:${user.id}`);
      const row = db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
      return res.json(userToJson(row));
    }

    const amount = Math.max(1, parseIntSafe(req.body?.amount, 1));
    const unit = String(req.body?.unit || 'days').toLowerCase();
    const now = new Date();
    let base = now;
    if (user.package_type === 'premium' && user.expiry_date) {
      const existing = new Date(user.expiry_date);
      if (!Number.isNaN(existing.getTime()) && existing > now) base = existing;
    }
    const expiry = addPremiumDuration(base, amount, unit);
    db.prepare(
      `UPDATE users SET package_type = 'premium', expiry_date = ? WHERE id = ?`,
    ).run(expiry, user.id);
    audit(db, req.admin.adminId, `user.grant:${user.id}:${amount}${unit}`);
    const row = db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
    return res.json(userToJson(row));
  });

  router.post('/users', (req, res) => {
    const name = req.body.name || 'Free User';
    let phone = normalizePhoneDigits(req.body.phone);
    if (phone.startsWith('255') && phone.length === 12) {
      phone = `0${phone.slice(3)}`;
    } else if (phone.length === 9 && /^[67]/.test(phone)) {
      phone = `0${phone}`;
    }
    const deviceId = String(req.body.deviceId || req.body.device_id || '').trim();
    if (phone.length < 9 && deviceId.length < 8) {
      return res.status(400).json({
        error: 'Simu sahihi au kitambulisho cha kifaa (device id) kinahitajika',
      });
    }
    const packageType = req.body.packageType || 'free';
    const expiryDate = req.body.expiryDate ?? null;
    const id = uuidv4();
    const createdAt = new Date().toISOString();

    if (phone.length >= 9) {
      const dup = findUserByPhoneVariants(db, phone);
      if (dup) {
        return res.status(409).json({ error: 'Namba hii tayari ipo' });
      }
    }
    if (deviceId.length >= 8) {
      const dupDevice = db.prepare('SELECT id FROM users WHERE device_id = ?').get(deviceId);
      if (dupDevice) {
        return res.status(409).json({ error: 'Kitambulisho cha kifaa tayari kipo' });
      }
    }

    db.prepare(
      `INSERT INTO users (
        id, name, phone, package_type, expiry_date, created_at, device_id, last_open_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run(
      id,
      name,
      phone.length >= 9 ? phone : '',
      packageType,
      expiryDate,
      createdAt,
      deviceId.length >= 8 ? deviceId : null,
      createdAt,
    );
    audit(db, req.admin.adminId, `user.create:${id}`);

    const row = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
    return res.status(201).json(userToJson(row));
  });

  router.put('/users/:id', (req, res) => {
    const existing = db.prepare('SELECT * FROM users WHERE id = ?').get(req.params.id);
    if (!existing) return res.status(404).json({ error: 'User not found' });

    const { name, packageType } = req.body;
    if (name != null) db.prepare('UPDATE users SET name = ? WHERE id = ?').run(name, req.params.id);

    if (Object.prototype.hasOwnProperty.call(req.body, 'phone')) {
      const phone = normalizePhoneDigits(req.body.phone);
      const deviceIdAfter = Object.prototype.hasOwnProperty.call(req.body, 'deviceId')
        ? String(req.body.deviceId || '').trim()
        : String(existing.device_id || '').trim();
      if (phone.length > 0 && phone.length < 9) {
        return res.status(400).json({ error: 'Simu sahihi inahitajika' });
      }
      if (phone.length === 0 && deviceIdAfter.length < 8) {
        return res.status(400).json({
          error: 'Akaunti inahitaji simu au kitambulisho cha kifaa',
        });
      }
      if (phone.length >= 9) {
        const dup = db
          .prepare('SELECT id FROM users WHERE phone = ? AND id != ?')
          .get(phone, req.params.id);
        if (dup) return res.status(409).json({ error: 'Namba hii tayari ipo' });
      }
      db.prepare('UPDATE users SET phone = ? WHERE id = ?').run(phone, req.params.id);
    }

    if (Object.prototype.hasOwnProperty.call(req.body, 'deviceId') ||
        Object.prototype.hasOwnProperty.call(req.body, 'device_id')) {
      const deviceId = String(req.body.deviceId || req.body.device_id || '').trim();
      if (deviceId.length > 0 && deviceId.length < 8) {
        return res.status(400).json({ error: 'Kitambulisho cha kifaa si sahihi' });
      }
      if (deviceId.length >= 8) {
        const dup = db
          .prepare('SELECT id FROM users WHERE device_id = ? AND id != ?')
          .get(deviceId, req.params.id);
        if (dup) {
          return res.status(409).json({ error: 'Kitambulisho cha kifaa tayari kipo' });
        }
        db.prepare('UPDATE users SET device_id = ? WHERE id = ?').run(deviceId, req.params.id);
      } else {
        const phoneNow = Object.prototype.hasOwnProperty.call(req.body, 'phone')
          ? normalizePhoneDigits(req.body.phone)
          : normalizePhoneDigits(existing.phone);
        if (phoneNow.length < 9) {
          return res.status(400).json({
            error: 'Huwezi kuondoa device id bila simu sahihi',
          });
        }
        db.prepare('UPDATE users SET device_id = NULL WHERE id = ?').run(req.params.id);
      }
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
    const whatsappRaw = req.body.whatsappNumber ?? req.body.whatsapp_number;
    let whatsappNumber = current.whatsapp_number || '255712345678';
    if (whatsappRaw != null) {
      const digits = String(whatsappRaw).replace(/\D/g, '');
      if (digits.length >= 9) {
        // Normalize local 0XXXXXXXXX → 255XXXXXXXXX for wa.me
        whatsappNumber =
          digits.startsWith('0') && digits.length === 10
            ? `255${digits.slice(1)}`
            : digits;
      }
    }
    db.prepare(`
      UPDATE app_config SET
        player_engine = ?, drm_type = ?, stream_origin = ?, stream_referer = ?,
        user_agent = ?, token_refresh_url = ?, stream_user_id = ?,
        app_api_key = ?, app_api_secret = ?, maintenance_mode = ?,
        whatsapp_number = ?, whatsapp_message = ?, support_hours = ?
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
      whatsappNumber,
      req.body.whatsappMessage ?? req.body.whatsapp_message ?? current.whatsapp_message,
      req.body.supportHours ?? req.body.support_hours ?? current.support_hours,
    );
    audit(db, req.admin.adminId, 'app_config.update');
    return res.json(appConfigForAdmin(loadAppConfigRow(db)));
  });

  return router;
}

module.exports = { createAdminRoutes };
