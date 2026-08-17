const express = require('express');
const { sendPushToTopic, fcmReady } = require('../services/fcm');

/**
 * Partner bridge: Supasoka SupaAdmin mirrors *broadcast* pushes here so
 * JamboPlus devices receive the same announcements on JamboPlus-only topics.
 *
 * User-scoped / expired-payment reminders are never mirrored.
 *
 * Auth: header X-Partner-Secret must match SUPA_JAMBOPLUS_BRIDGE_SECRET
 * (or JAMBOPLUS_BRIDGE_SECRET).
 */

const EXPIRED_REMINDER_MARKERS = [
  'kifurushi chako kimeisha',
  'kifurushi chako kimeisha muda wake',
  'mpendwa mteja, kifurushi chako kimeisha',
];

function isExpiredPaymentReminder(title, message) {
  const haystack = `${title} ${message}`.toLowerCase();
  return EXPIRED_REMINDER_MARKERS.some((m) => haystack.includes(m));
}

function createPartnerRoutes() {
  const router = express.Router();

  function verifyPartnerSecret(req, res, next) {
    const secret = String(
      process.env.SUPA_JAMBOPLUS_BRIDGE_SECRET ||
        process.env.JAMBOPLUS_BRIDGE_SECRET ||
        '',
    ).trim();
    if (!secret) {
      return res.status(503).json({ ok: false, error: 'Partner bridge not configured' });
    }
    const header = String(req.get('X-Partner-Secret') || '').trim();
    if (!header || header !== secret) {
      return res.status(401).json({ ok: false, error: 'Unauthorized' });
    }
    return next();
  }

  router.get('/supa-push/health', verifyPartnerSecret, (_req, res) => {
    res.json({
      ok: true,
      fcm: fcmReady(),
      service: 'jamboplus-partner',
      accepts: ['broadcast'],
      topics: ['jamboplus_all_users', 'jamboplus_premium_users', 'jamboplus_free_users'],
    });
  });

  router.post('/supa-push', verifyPartnerSecret, async (req, res) => {
    try {
      const title = String(req.body?.title || '').trim();
      const message = String(req.body?.message || req.body?.body || '').trim();
      const scope = String(req.body?.scope || 'broadcast').trim().toLowerCase();
      const target = String(req.body?.target || 'all').trim() || 'all';
      const kind = String(req.body?.kind || req.body?.type || '').trim().toLowerCase();

      if (!title || !message) {
        return res.status(400).json({ ok: false, error: 'title and message required' });
      }

      if (scope !== 'broadcast') {
        return res.json({
          ok: true,
          skipped: true,
          delivered: false,
          scope,
          reason: 'user_scope_not_mirrored',
        });
      }
      if (kind === 'reminder' || kind === 'payment_reminder' || kind === 'expired_reminder') {
        return res.json({
          ok: true,
          skipped: true,
          delivered: false,
          scope,
          kind,
          reason: 'reminder_not_mirrored',
        });
      }
      if (isExpiredPaymentReminder(title, message)) {
        return res.json({
          ok: true,
          skipped: true,
          delivered: false,
          scope,
          reason: 'expired_reminder_not_mirrored',
        });
      }

      if (!fcmReady()) {
        return res.status(503).json({
          ok: false,
          error: 'Firebase not initialized. Set FCM_SERVICE_ACCOUNT_JSON on Railway.',
        });
      }

      const out = await sendPushToTopic({
        title,
        body: message,
        target,
        kind: kind || 'broadcast',
      });

      return res.json({
        ok: true,
        scope: 'broadcast',
        target,
        topic: out.topic,
        messageId: out.messageId,
        delivered: true,
      });
    } catch (e) {
      console.error('[partner/supa-push]', e);
      return res.status(500).json({
        ok: false,
        error: e instanceof Error ? e.message : String(e),
      });
    }
  });

  return router;
}

module.exports = { createPartnerRoutes };
