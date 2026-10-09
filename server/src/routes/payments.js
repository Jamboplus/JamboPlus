const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { userToJson } = require('../serializers');
const { appSignatureMiddleware } = require('../middleware/appSignature');
const { hmacSha256Hex, constantTimeEquals } = require('../crypto-util');
const {
  sonicpesaConfigured,
  normalizeTzPhone,
  toLocalTzPhone,
  normalizePaymentStatus,
  isSonicpesaSuccess,
  isSonicpesaFailure,
  sonicpesaCreateOrder,
  sonicpesaOrderStatus,
} = require('../lib/sonicpesa');

function addDaysIso(fromDate, days) {
  const d = new Date(fromDate.getTime());
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString();
}

function ensureUser(db, { name, phone, deviceId }) {
  const device = String(deviceId || '').trim();
  const byPhone = db.prepare('SELECT * FROM users WHERE phone = ?').get(phone);
  const byDevice = device.length >= 8
    ? db.prepare('SELECT * FROM users WHERE device_id = ?').get(device)
    : null;

  // Merge guest device row into the phone account (same as /users/register).
  if (byPhone && byDevice && byPhone.id !== byDevice.id) {
    db.prepare('DELETE FROM users WHERE id = ?').run(byDevice.id);
    db.prepare(
      'UPDATE users SET name = COALESCE(?, name), device_id = ? WHERE id = ?',
    ).run(name || null, device, byPhone.id);
    return db.prepare('SELECT * FROM users WHERE id = ?').get(byPhone.id);
  }

  if (byDevice && !byPhone) {
    db.prepare(
      'UPDATE users SET name = COALESCE(?, name), phone = ? WHERE id = ?',
    ).run(name || null, phone, byDevice.id);
    return db.prepare('SELECT * FROM users WHERE id = ?').get(byDevice.id);
  }

  if (byPhone) {
    if (name && name !== byPhone.name) {
      db.prepare('UPDATE users SET name = ? WHERE id = ?').run(name, byPhone.id);
    }
    if (device.length >= 8 && !byPhone.device_id) {
      db.prepare('UPDATE users SET device_id = ? WHERE id = ?').run(device, byPhone.id);
    }
    return db.prepare('SELECT * FROM users WHERE id = ?').get(byPhone.id);
  }

  const id = uuidv4();
  const createdAt = new Date().toISOString();
  db.prepare(
    `INSERT INTO users (
      id, name, phone, package_type, expiry_date, created_at, device_id, last_open_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    id,
    name || 'Mtumiaji',
    phone,
    'free',
    null,
    createdAt,
    device.length >= 8 ? device : null,
    createdAt,
  );
  return db.prepare('SELECT * FROM users WHERE id = ?').get(id);
}

function grantPremiumFromPayment(db, tx) {
  const plan = db.prepare('SELECT * FROM pricing WHERE id = ?').get(tx.plan_id);
  if (!plan) {
    const err = new Error('plan not found');
    err.status = 404;
    throw err;
  }

  let deviceId = null;
  if (tx.user_id) {
    const linked = db.prepare('SELECT * FROM users WHERE id = ?').get(tx.user_id);
    if (linked && linked.device_id) deviceId = linked.device_id;
  }

  const user = ensureUser(db, {
    name: tx.user_name,
    phone: tx.phone,
    deviceId,
  });
  const now = new Date();
  let base = now;
  if (user.package_type === 'premium' && user.expiry_date) {
    const existing = new Date(user.expiry_date);
    if (!Number.isNaN(existing.getTime()) && existing > now) {
      base = existing;
    }
  }
  const expiry = addDaysIso(base, Number(plan.duration_days) || 0);

  const updated = db.prepare(
    `UPDATE payment_transactions
        SET status = 'completed', completed_at = ?, activated_at = ?, user_id = ?
      WHERE id = ? AND status != 'completed'`,
  ).run(now.toISOString(), now.toISOString(), user.id, tx.id);

  if (updated.changes === 0) {
    return db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
  }

  db.prepare(
    `UPDATE users SET package_type = 'premium', expiry_date = ?, name = COALESCE(?, name) WHERE id = ?`,
  ).run(expiry, tx.user_name || null, user.id);

  const dateKey = now.toISOString().slice(0, 10);
  db.prepare(
    `INSERT INTO revenue_daily (date, amount, transaction_count) VALUES (?, ?, 1)
     ON CONFLICT(date) DO UPDATE SET
       amount = amount + excluded.amount,
       transaction_count = transaction_count + 1`,
  ).run(dateKey, Number(tx.amount) || 0);

  return db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
}

function markPaymentFailed(db, orderId) {
  db.prepare(
    `UPDATE payment_transactions SET status = 'failed', completed_at = ?
      WHERE order_id = ? AND status = 'pending'`,
  ).run(new Date().toISOString(), orderId);
}

function verifyWebhookAuth(req) {
  const webhookSecret = (process.env.SONICPESA_WEBHOOK_SECRET || '').trim();
  if (!webhookSecret) {
    // Require a secret in production-like deploys so unsigned callers cannot grant premium.
    return { ok: false, reason: 'webhook_secret_missing' };
  }

  const headerSecret = String(
    req.headers['x-webhook-secret'] ?? req.headers['x-sonicpesa-secret'] ?? '',
  ).trim();
  if (headerSecret && constantTimeEquals(headerSecret, webhookSecret)) {
    return { ok: true };
  }

  const sigHeader = String(
    req.headers['x-sonicpesa-signature'] ||
      req.headers['x-webhook-signature'] ||
      req.headers['x-signature'] ||
      '',
  ).trim();
  if (!sigHeader) return { ok: false, reason: 'missing_signature' };

  const rawBody =
    typeof req.rawBody === 'string' && req.rawBody.length > 0
      ? req.rawBody
      : JSON.stringify(req.body || {});
  const expected = hmacSha256Hex(webhookSecret, rawBody);
  const valid =
    constantTimeEquals(sigHeader.toLowerCase(), expected.toLowerCase()) ||
    constantTimeEquals(sigHeader.toLowerCase(), `sha256=${expected}`.toLowerCase());
  return valid ? { ok: true } : { ok: false, reason: 'invalid_signature' };
}

function extractWebhookPaid(payload) {
  const nest =
    payload.data && typeof payload.data === 'object' && !Array.isArray(payload.data)
      ? payload.data
      : null;
  const orderId = String(
    payload.order_id ??
      payload.orderId ??
      nest?.order_id ??
      nest?.orderId ??
      payload.reference ??
      payload.transid ??
      '',
  ).trim();

  const rawStatus = normalizePaymentStatus(
    payload.payment_status ?? payload.status ?? nest?.payment_status ?? nest?.status ?? '',
  );
  const ev = String(payload.event || payload.type || '').toLowerCase().trim();
  let paid = isSonicpesaSuccess(rawStatus);
  if (!paid && ev) {
    paid =
      ev === 'payment.success' ||
      ev === 'payment.completed' ||
      ev === 'payment_completed' ||
      ev === 'invoice.paid' ||
      ev === 'charge.succeeded' ||
      ev === 'transaction.completed';
  }
  return { orderId, paid, rawStatus, event: ev };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function createPaymentRoutes(db) {
  const router = express.Router();
  const signed = appSignatureMiddleware(db);
  /** One background checker per order so the app poll never waits on SonicPesa. */
  const watchers = new Map();

  function watchPayment(orderId) {
    if (!orderId || watchers.has(orderId)) return;
    watchers.set(orderId, true);

    const run = (async () => {
      const deadline = Date.now() + 95_000;
      while (Date.now() < deadline) {
        try {
          const tx = db
            .prepare('SELECT * FROM payment_transactions WHERE order_id = ?')
            .get(orderId);
          if (!tx || tx.status !== 'pending') return;
          if (!sonicpesaConfigured()) return;

          const remote = await sonicpesaOrderStatus(orderId);
          if (!remote.ok) {
            await sleep(1200);
            continue;
          }

          const paymentStatus = normalizePaymentStatus(
            remote.payment_status || remote.status,
          );
          const current = db
            .prepare('SELECT * FROM payment_transactions WHERE order_id = ?')
            .get(orderId);
          if (!current || current.status !== 'pending') return;

          if (isSonicpesaSuccess(paymentStatus)) {
            grantPremiumFromPayment(db, current);
            return;
          }
          if (isSonicpesaFailure(paymentStatus)) {
            markPaymentFailed(db, orderId);
            return;
          }
        } catch (err) {
          console.error('[payments/watch]', orderId, err);
        }
        await sleep(1200);
      }
    })().finally(() => {
      if (watchers.get(orderId) === run) watchers.delete(orderId);
    });

    watchers.set(orderId, run);
  }

  router.get('/payments/health', signed, (_req, res) => {
    res.json({
      ok: true,
      provider: 'sonicpesa',
      configured: sonicpesaConfigured(),
      webhookSecretConfigured: Boolean((process.env.SONICPESA_WEBHOOK_SECRET || '').trim()),
    });
  });

  /**
   * Start SonicPesa Push USSD.
   * POST /v1/app/payments/start
   * { name, phone, planId, amount? }
   */
  router.post('/payments/start', signed, async (req, res) => {
    try {
      if (!sonicpesaConfigured()) {
        return res.status(503).json({
          error: 'Malipo hayajasanidi kwenye seva. Wasiliana na msaada.',
          configured: false,
        });
      }

      const name = String(req.body.name || '').trim() || 'Mtumiaji';
      const planId = String(req.body.planId || req.body.plan_id || '').trim();
      const phoneRaw = String(req.body.phone || '').trim();
      const deviceId = String(req.body.deviceId || req.body.device_id || '').trim();
      const localPhone = toLocalTzPhone(phoneRaw);
      const buyerPhone = normalizeTzPhone(phoneRaw);

      if (!planId) return res.status(400).json({ error: 'planId required' });
      if (!localPhone || !buyerPhone) {
        return res.status(400).json({
          error:
            'Namba ya simu si sahihi. Tumia 07… au 06… (mfano 0712345678).',
        });
      }

      const plan = db
        .prepare('SELECT * FROM pricing WHERE id = ? AND enabled = 1')
        .get(planId);
      if (!plan) return res.status(404).json({ error: 'Kifurushi hakipatikani' });

      const amount = Math.round(Number(plan.price));
      if (!Number.isFinite(amount) || amount < 1) {
        return res.status(400).json({ error: 'Bei ya kifurushi si sahihi' });
      }
      if (req.body.amount != null && Math.round(Number(req.body.amount)) !== amount) {
        return res.status(400).json({
          error: `Kiasi cha malipo ni TSh ${amount}.`,
        });
      }

      // Store local 0… form (same as Flutter register /users/me) and bind device.
      const phoneDigits = localPhone;
      const user = ensureUser(db, { name, phone: phoneDigits, deviceId });

      const emailBase = phoneDigits.replace(/\D/g, '').slice(-9) || 'user';
      const startedAt = Date.now();
      const order = await sonicpesaCreateOrder({
        buyer_email: `${emailBase}@jamboplus.app`,
        buyer_name: name,
        buyer_phone: buyerPhone,
        amount,
        currency: 'TZS',
      });
      console.log(
        '[SonicPesa] create_order',
        order.ok ? 'ok' : 'fail',
        `${Date.now() - startedAt}ms`,
      );

      if (!order.ok || !order.order_id) {
        console.warn('[SonicPesa] create_order failed:', order.error);
        return res.status(502).json({
          error:
            order.error && /unreachable|timed out/i.test(String(order.error))
              ? 'Seva ya malipo haipatikani kwa sasa. Jaribu tena baada ya dakika moja.'
              : 'Imeshindikana kutuma ombi la malipo kwenye simu. Hakikisha namba ni sahihi kisha ujaribu tena.',
        });
      }

      const id = uuidv4();
      const now = new Date().toISOString();
      db.prepare(`
        INSERT INTO payment_transactions (
          id, order_id, user_id, user_name, phone, plan_id, plan_name,
          amount, currency, status, provider, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'TZS', 'pending', 'sonicpesa', ?)
      `).run(
        id,
        order.order_id,
        user.id,
        name,
        phoneDigits,
        plan.id,
        plan.name,
        amount,
        now,
      );

      if (isSonicpesaSuccess(order.payment_status)) {
        const paidTx = db
          .prepare('SELECT * FROM payment_transactions WHERE order_id = ?')
          .get(order.order_id);
        const paidUser = grantPremiumFromPayment(db, paidTx);
        return res.status(201).json({
          ok: true,
          status: 'completed',
          orderId: order.order_id,
          order_id: order.order_id,
          amount,
          currency: 'TZS',
          planId: plan.id,
          provider: 'sonicpesa',
          message: 'Malipo yamekamilika. Premium imewashwa.',
          paymentStatus: 'SUCCESS',
          completed: true,
          failed: false,
          pending: false,
          activated: true,
          user: userToJson(paidUser),
        });
      }

      // Confirm success/failure off the request path so the phone prompt is not delayed.
      watchPayment(order.order_id);

      return res.status(201).json({
        ok: true,
        status: 'pending',
        orderId: order.order_id,
        order_id: order.order_id,
        amount,
        currency: 'TZS',
        planId: plan.id,
        provider: 'sonicpesa',
        message:
          'Angalia simu yako — weka PIN ya M-Pesa / Tigo / Airtel / HaloPesa kukamilisha malipo.',
        paymentStatus: order.payment_status || 'PENDING',
        completed: false,
        failed: false,
        pending: true,
        activated: false,
      });
    } catch (err) {
      console.error('[payments/start]', err);
      return res.status(500).json({ error: 'Internal server error' });
    }
  });

  /**
   * Poll payment status; activates premium when Sonic reports paid.
   * GET /v1/app/payments/status?orderId=
   */
  router.get('/payments/status', signed, async (req, res) => {
    try {
      const orderId = String(req.query.orderId || req.query.order_id || '').trim();
      if (!orderId) return res.status(400).json({ error: 'orderId required' });

      const tx = db.prepare('SELECT * FROM payment_transactions WHERE order_id = ?').get(orderId);
      if (!tx) return res.status(404).json({ error: 'Malipo hayajapatikana' });

      if (tx.status === 'completed') {
        const user = db.prepare('SELECT * FROM users WHERE id = ?').get(tx.user_id);
        return res.json({
          ok: true,
          paymentStatus: 'SUCCESS',
          completed: true,
          failed: false,
          pending: false,
          activated: true,
          user: user ? userToJson(user) : null,
        });
      }

      if (tx.status === 'failed') {
        return res.json({
          ok: true,
          paymentStatus: 'FAILED',
          completed: false,
          failed: true,
          pending: false,
          activated: false,
          message: 'Malipo hayajakamilika. Jaribu tena.',
        });
      }

      // Local read only. The watcher (or webhook) flips the row when Sonic reports.
      watchPayment(orderId);
      return res.json({
        ok: true,
        paymentStatus: 'PENDING',
        completed: false,
        failed: false,
        pending: true,
        activated: false,
      });
    } catch (err) {
      console.error('[payments/status]', err);
      return res.status(500).json({ error: 'Internal server error' });
    }
  });

  /**
   * SonicPesa webhook (configure in dashboard):
   * POST https://<host>/v1/app/payments/sonicpesa/webhook
   * Auth: SONICPESA_WEBHOOK_SECRET via HMAC header or x-webhook-secret.
   */
  router.post('/payments/sonicpesa/webhook', (req, res) => {
    try {
      if (!sonicpesaConfigured()) {
        return res.status(503).json({ error: 'SonicPesa not configured' });
      }

      const auth = verifyWebhookAuth(req);
      if (!auth.ok) {
        if (auth.reason === 'webhook_secret_missing') {
          return res.status(503).json({ error: 'Webhook verification is not configured' });
        }
        return res.status(401).json({ error: 'Invalid webhook signature' });
      }

      const { orderId, paid, rawStatus } = extractWebhookPaid(req.body || {});
      if (!orderId) return res.status(400).json({ error: 'Missing order reference' });

      const tx = db.prepare('SELECT * FROM payment_transactions WHERE order_id = ?').get(orderId);
      if (!tx) {
        return res.status(200).json({ received: true, processed: false, reason: 'unknown_order' });
      }

      if (tx.status === 'completed') {
        return res.status(200).json({ received: true, processed: false, reason: 'already_completed' });
      }

      if (!paid) {
        if (isSonicpesaFailure(rawStatus)) markPaymentFailed(db, orderId);
        return res.status(200).json({ received: true, processed: false });
      }

      const user = grantPremiumFromPayment(db, tx);
      console.log('[SonicPesa] webhook activated premium for', user.phone, 'order', orderId);
      return res.status(200).json({
        received: true,
        processed: true,
        userId: user.id,
      });
    } catch (err) {
      console.error('[SonicPesa] webhook error', err);
      return res.status(500).json({ error: 'Processing failed' });
    }
  });

  return router;
}

module.exports = { createPaymentRoutes };
