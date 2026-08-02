const express = require('express');
const cors = require('cors');
const config = require('./config');
const { openDatabase } = require('./db');
const { createAppRoutes } = require('./routes/app');
const { createAdminRoutes } = require('./routes/admin');
const { createPartnerRoutes } = require('./routes/partner');
const { createPaymentRoutes } = require('./routes/payments');
const { sonicpesaConfigured } = require('./lib/sonicpesa');

const db = openDatabase();
const app = express();

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Authorization',
    'Content-Type',
    'X-Jambo-Timestamp',
    'X-Jambo-Signature',
    'X-Partner-Secret',
    'X-Webhook-Secret',
    'X-Sonicpesa-Secret',
    'X-Sonicpesa-Signature',
    'X-Webhook-Signature',
    'X-Signature',
  ],
}));
app.use(express.json({
  limit: '2mb',
  verify: (req, _res, buf) => {
    if (buf?.length) req.rawBody = buf.toString('utf8');
  },
}));

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: config.serviceName,
    payments: {
      provider: 'sonicpesa',
      configured: sonicpesaConfigured(),
    },
  });
});

app.use('/v1/app', createAppRoutes(db));
app.use('/v1/app', createPaymentRoutes(db));
app.use('/v1/admin', createAdminRoutes(db));
app.use('/api/partner', createPartnerRoutes());

app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(config.port, config.host, () => {
  console.log(`${config.serviceName} listening on http://${config.host}:${config.port}`);
  console.log(`Database: ${config.dbPath}`);
});
