const jwt = require('jsonwebtoken');
const config = require('./config');

function issueAdminToken(claims) {
  return jwt.sign(
    { sub: claims.adminId, email: claims.email, role: claims.role },
    config.jwtSecret,
    { expiresIn: '24h' },
  );
}

function verifyAdminToken(token) {
  const payload = jwt.verify(token, config.jwtSecret);
  return {
    adminId: payload.sub,
    email: payload.email,
    role: payload.role,
  };
}

module.exports = { issueAdminToken, verifyAdminToken };
