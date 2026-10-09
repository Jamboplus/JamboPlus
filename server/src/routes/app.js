const express = require('express');
const { v4: uuidv4 } = require('uuid');
const {
  channelToAppJson,
  carouselToAppJson,
  pricingToAppJson,
  appConfigForBootstrap,
  userToJson,
} = require('../serializers');
const { loadAppConfigRow } = require('../db');
const { appSignatureMiddleware } = require('../middleware/appSignature');

function normalizePhone(raw) {
  return String(raw || '').replace(/\D/g, '');
}

function phoneLookupVariants(raw) {
  const digits = normalizePhone(raw);
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

function createAppRoutes(db) {
  const router = express.Router();
  const signed = appSignatureMiddleware(db);

  router.get('/bootstrap', signed, (_req, res) => {
    const row = loadAppConfigRow(db);
    res.json({
      config: appConfigForBootstrap(row),
      maintenanceMode: row.maintenance_mode === 1,
    });
  });

  router.get('/channels', signed, (_req, res) => {
    const rows = db
      .prepare('SELECT * FROM channels WHERE enabled = 1 ORDER BY sort_order ASC, name ASC')
      .all();
    res.json(rows.map(channelToAppJson));
  });

  router.post('/channels/:id/watch', signed, (req, res) => {
    const result = db
      .prepare('UPDATE channels SET watch_count = watch_count + 1 WHERE id = ? AND enabled = 1')
      .run(req.params.id);
    if (result.changes === 0) return res.status(404).json({ error: 'Channel not found' });
    res.status(204).end();
  });

  router.get('/carousel', signed, (_req, res) => {
    const rows = db
      .prepare('SELECT * FROM carousel WHERE enabled = 1 ORDER BY sort_order ASC')
      .all();
    res.json(rows.map(carouselToAppJson));
  });

  router.get('/pricing', signed, (_req, res) => {
    const rows = db
      .prepare('SELECT * FROM pricing WHERE enabled = 1 ORDER BY sort_order ASC')
      .all();
    res.json(rows.map(pricingToAppJson));
  });

  /**
   * Record every app open / install so admin lists devices even before signup.
   * POST /v1/app/devices/heartbeat { deviceId, fcmToken?, platform?, appVersion? }
   */
  router.post('/devices/heartbeat', signed, (req, res) => {
    const deviceId = String(req.body?.deviceId || '').trim();
    const fcmToken = String(req.body?.fcmToken || '').trim();
    const platform = String(req.body?.platform || '').trim();
    const appVersion = String(req.body?.appVersion || '').trim();
    if (deviceId.length < 8) {
      return res.status(400).json({ error: 'deviceId required' });
    }

    const now = new Date().toISOString();
    const existing = db.prepare('SELECT * FROM users WHERE device_id = ?').get(deviceId);
    if (existing) {
      db.prepare(
        `UPDATE users SET last_open_at = ?, fcm_token = ?, platform = ?, app_version = ? WHERE id = ?`,
      ).run(
        now,
        fcmToken || existing.fcm_token || null,
        platform || existing.platform || '',
        appVersion || existing.app_version || '',
        existing.id,
      );
      const row = db.prepare('SELECT * FROM users WHERE id = ?').get(existing.id);
      return res.json(userToJson(row));
    }

    const id = uuidv4();
    db.prepare(
      `INSERT INTO users (
        id, name, phone, package_type, expiry_date, created_at,
        device_id, last_open_at, fcm_token, platform, app_version
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run(
      id,
      'Mgeni',
      '',
      'free',
      null,
      now,
      deviceId,
      now,
      fcmToken || null,
      platform,
      appVersion,
    );

    return res.status(201).json(
      userToJson(
        db.prepare('SELECT * FROM users WHERE id = ?').get(id),
      ),
    );
  });

  /**
   * Subscription status for the user app (admin / payment is source of truth).
   * GET /v1/app/users/me?phone=07XXXXXXXX
   * GET /v1/app/users/me?deviceId=...
   */
  router.get('/users/me', signed, (req, res) => {
    const phoneRaw = req.query.phone;
    const deviceId = String(req.query.deviceId || '').trim();

    if (phoneRaw != null && String(phoneRaw).trim()) {
      const row = findUserByPhoneVariants(db, phoneRaw);
      if (!row) return res.status(404).json({ error: 'User not found' });
      return res.json(userToJson(row));
    }

    if (deviceId.length >= 8) {
      const row = db.prepare('SELECT * FROM users WHERE device_id = ?').get(deviceId);
      if (!row) return res.status(404).json({ error: 'User not found' });
      return res.json(userToJson(row));
    }

    return res.status(400).json({ error: 'phone or deviceId required' });
  });

  /**
   * Register / update profile from the user app.
   * Never grants premium — only admin or SonicPesa payment webhook/status can.
   * POST /v1/app/users/register { name, phone, deviceId? }
   */
  router.post('/users/register', signed, (req, res) => {
    const name = String(req.body.name || '').trim() || 'Free User';
    const phoneDigits = normalizePhone(req.body.phone);
    // Prefer national 07… storage so admin/search/grant match payments.
    let phone = phoneDigits;
    if (phone.startsWith('255') && phone.length === 12) {
      phone = `0${phone.slice(3)}`;
    } else if (phone.length === 9 && /^[67]/.test(phone)) {
      phone = `0${phone}`;
    }
    const deviceId = String(req.body.deviceId || '').trim();
    if (phone.length < 9) {
      return res.status(400).json({ error: 'Simu sahihi inahitajika' });
    }

    const byPhone = findUserByPhoneVariants(db, phone) || findUserByPhoneVariants(db, phoneDigits);
    const byDevice = deviceId
      ? db.prepare('SELECT * FROM users WHERE device_id = ?').get(deviceId)
      : null;

    if (byPhone && byDevice && byPhone.id !== byDevice.id) {
      db.prepare('DELETE FROM users WHERE id = ?').run(byDevice.id);
      db.prepare('UPDATE users SET name = ?, device_id = ? WHERE id = ?').run(
        name,
        deviceId,
        byPhone.id,
      );
      const row = db.prepare('SELECT * FROM users WHERE id = ?').get(byPhone.id);
      return res.json(userToJson(row));
    }

    if (byDevice) {
      db.prepare('UPDATE users SET name = ?, phone = ? WHERE id = ?').run(
        name,
        phone,
        byDevice.id,
      );
      const row = db.prepare('SELECT * FROM users WHERE id = ?').get(byDevice.id);
      return res.json(userToJson(row));
    }

    if (byPhone) {
      if (deviceId.length >= 8) {
        db.prepare('UPDATE users SET name = ?, device_id = ? WHERE id = ?').run(
          name,
          deviceId,
          byPhone.id,
        );
      } else {
        db.prepare('UPDATE users SET name = ? WHERE id = ?').run(name, byPhone.id);
      }
      const row = db.prepare('SELECT * FROM users WHERE id = ?').get(byPhone.id);
      return res.json(userToJson(row));
    }

    const id = uuidv4();
    const createdAt = new Date().toISOString();
    db.prepare(
      `INSERT INTO users (
        id, name, phone, package_type, expiry_date, created_at,
        device_id, last_open_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run(id, name, phone, 'free', null, createdAt, deviceId || null, createdAt);

    return res.status(201).json(
      userToJson(
        db.prepare('SELECT * FROM users WHERE id = ?').get(id),
      ),
    );
  });

  return router;
}

module.exports = { createAppRoutes };
