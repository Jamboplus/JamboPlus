const path = require('path');

// Load local .env when present (Railway injects vars directly)
require('dotenv').config();

const config = {
  port: parseInt(process.env.PORT || '8080', 10),
  host: process.env.HOST || '0.0.0.0',
  jwtSecret: process.env.JWT_SECRET || 'dev-jwt-secret-change-in-production',
  dbPath: process.env.DB_PATH || path.join(process.cwd(), 'data', 'jamboad.db'),
  serviceName: 'jamboplus-api',
  sonicpesaConfigured: Boolean((process.env.SONICPESA_API_KEY || '').trim()),
};

module.exports = config;
