const express = require('express');
const { sendPushToTopic, fcmReady } = require('../services/fcm');

/**
 * Partner bridge: Supasoka SupaAdmin mirrors pushes here so JamboPlus
 * devices (Firebase project supasoka-18128) receive the same alerts.
 *
 * Auth: header X-Partner-Secret must match SUPA_JAMBOPLUS_BRIDGE_SECRET
 * (or JAMBOPLUS_BRIDGE_SECRET).
 */
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
    });
  });

  router.post('/supa-push', verifyPartnerSecret, async (req, res) => {
    try {
      const title = String(req.body?.title || '').trim();
      const message = String(req.body?.message || req.body?.body || '').trim();
      const scope = String(req.body?.scope || 'broadcast').trim();
      const target = String(req.body?.target || 'all').trim() || 'all';

      if (!title || !message) {
        return res.status(400).json({ ok: false, error: 'title and message required' });
      }

      if (!fcmReady()) {
        return res.status(503).json({
          ok: false,
          error: 'Firebase not initialized. Set FCM_SERVICE_ACCOUNT_JSON on Railway.',
        });
      }

      // User-scoped mirrors from Supasoka use Supasoka public IDs — broadcast
      // to all_users so JamboPlus still surfaces the alert.
      const effectiveTarget = scope === 'user' ? 'all' : target;
      const out = await sendPushToTopic({
        title,
        body: message,
        target: effectiveTarget,
      });

      return res.json({
        ok: true,
        scope,
        target: effectiveTarget,
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
