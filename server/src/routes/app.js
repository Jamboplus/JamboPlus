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
   * Subscription status for the user app (admin is source of truth for premium).
   * GET /v1/app/users/me?phone=07XXXXXXXX
   */
  router.get('/users/me', signed, (req, res) => {
    const phone = normalizePhone(req.query.phone);
    if (phone.length < 9) {
      return res.status(400).json({ error: 'phone required' });
    }
    const row = db.prepare('SELECT * FROM users WHERE phone = ?').get(phone);
    if (!row) return res.status(404).json({ error: 'User not found' });
    return res.json(userToJson(row));
  });

  /**
   * Register / update profile from the user app.
   * Never grants premium — only admin or SonicPesa payment webhook/status can.
   * POST /v1/app/users/register { name, phone }
   */
  router.post('/users/register', signed, (req, res) => {
    const name = String(req.body.name || '').trim() || 'Free User';
    const phone = normalizePhone(req.body.phone);
    if (phone.length < 9) {
      return res.status(400).json({ error: 'Simu sahihi inahitajika' });
    }

    const existing = db.prepare('SELECT * FROM users WHERE phone = ?').get(phone);
    if (existing) {
      db.prepare('UPDATE users SET name = ? WHERE id = ?').run(name, existing.id);
      const row = db.prepare('SELECT * FROM users WHERE id = ?').get(existing.id);
      return res.json(userToJson(row));
    }

    const id = uuidv4();
    const createdAt = new Date().toISOString();
    db.prepare(
      'INSERT INTO users (id, name, phone, package_type, expiry_date, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    ).run(id, name, phone, 'free', null, createdAt);

    return res.status(201).json(
      userToJson({
        id,
        name,
        phone,
        package_type: 'free',
        expiry_date: null,
        created_at: createdAt,
      }),
    );
  });

  return router;
}

module.exports = { createAppRoutes };
