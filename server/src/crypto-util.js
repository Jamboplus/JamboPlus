const crypto = require('crypto');

function hashPassword(password) {
  const saltBytes = crypto.randomBytes(16);
  const salt = saltBytes.toString('base64url');
  const hash = sha256(`${salt}:${password}`);
  return `${salt}:${hash}`;
}

function verifyPassword(password, stored) {
  const sep = stored.indexOf(':');
  if (sep <= 0) return false;
  const salt = stored.slice(0, sep);
  const expected = stored.slice(sep + 1);
  const actual = sha256(`${salt}:${password}`);
  return constantTimeEquals(expected, actual);
}

function sha256(input) {
  return crypto.createHash('sha256').update(input, 'utf8').digest('hex');
}

function hmacSha256Hex(secret, payload) {
  return crypto.createHmac('sha256', secret).update(payload, 'utf8').digest('hex');
}

function constantTimeEquals(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

module.exports = { hashPassword, verifyPassword, hmacSha256Hex, constantTimeEquals };
