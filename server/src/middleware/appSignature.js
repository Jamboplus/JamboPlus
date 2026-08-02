const { hmacSha256Hex, constantTimeEquals } = require('../crypto-util');
const { loadAppConfigRow } = require('../db');

const MAX_SKEW_SECONDS = 300;

function getAppApiSecret(db) {
  const row = db.prepare('SELECT app_api_secret FROM app_config WHERE id = 1').get();
  return row?.app_api_secret || '';
}

function appSignatureMiddleware(db) {
  return (req, res, next) => {
    const timestamp = req.headers['x-jambo-timestamp'];
    const signature = req.headers['x-jambo-signature'];

    if (!timestamp || !signature) {
      return res.status(401).json({ error: 'Missing X-Jambo-Timestamp or X-Jambo-Signature' });
    }

    const secret = getAppApiSecret(db);
    if (!secret) {
      return res.status(503).json({ error: 'App API not configured' });
    }

    const tsSeconds = Number.parseInt(timestamp, 10);
    if (Number.isNaN(tsSeconds)) {
      return res.status(401).json({ error: 'Invalid timestamp' });
    }

    const now = Math.floor(Date.now() / 1000);
    if (Math.abs(now - tsSeconds) > MAX_SKEW_SECONDS) {
      return res.status(401).json({ error: 'Timestamp expired' });
    }

    const method = req.method.toUpperCase();
    const path = req.originalUrl.split('?')[0];
    const payload = `${timestamp}${method}${path}`;
    const expected = hmacSha256Hex(secret, payload);

    if (!constantTimeEquals(expected.toLowerCase(), signature.toLowerCase())) {
      return res.status(401).json({ error: 'Invalid signature' });
    }

    return next();
  };
}

module.exports = { appSignatureMiddleware };
