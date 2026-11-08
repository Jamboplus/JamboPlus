const path = require('path');
const express = require('express');
const { APPS, findApp } = require('./catalog');
const { renderHome, renderApp, renderGo, playUrlFor, pickLang } = require('./pages');

function baseUrlFor(req) {
  const configured = (process.env.PUBLIC_BASE_URL || '').trim().replace(/\/+$/, '');
  if (configured) return configured;
  const proto = (req.get('x-forwarded-proto') || req.protocol || 'https').split(',')[0].trim();
  const host = (req.get('x-forwarded-host') || req.get('host') || '').split(',')[0].trim();
  return `${proto}://${host}`;
}

function sendHtml(res, html, { cache = 'public, max-age=300' } = {}) {
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.set('Cache-Control', cache);
  res.send(html);
}

function logClick(kind, app, req) {
  const q = req.query || {};
  console.log(
    `[store] ${kind} app=${app.slug} utm_source=${q.utm_source || '-'} utm_campaign=${q.utm_campaign || '-'} ua="${(req.get('user-agent') || '').slice(0, 80)}"`,
  );
}

/**
 * Public AppStore website (mobile-first), served from the JamboPlus API server.
 *
 *   /                 store home (all apps)
 *   /app/:slug        app detail page
 *   /go/:slug         promo/ad link: shows app, then auto-redirects to Google Play
 *   /install/:slug    instant 302 to Google Play
 */
function createStoreRoutes() {
  const router = express.Router();

  router.use(
    '/store-assets',
    express.static(path.join(__dirname, 'public'), { maxAge: '7d', immutable: true }),
  );

  router.get('/', (req, res) => {
    sendHtml(res, renderHome({ lang: pickLang(req.query), baseUrl: baseUrlFor(req), query: req.query }));
  });

  router.get('/app/:slug', (req, res) => {
    const app = findApp(req.params.slug);
    if (!app) return res.redirect(302, '/');
    sendHtml(res, renderApp({ app, lang: pickLang(req.query), baseUrl: baseUrlFor(req), query: req.query }));
  });

  router.get('/go/:slug', (req, res) => {
    const app = findApp(req.params.slug);
    // Unknown slug: never guess an app — show the store instead.
    if (!app) return res.redirect(302, '/');
    logClick('go', app, req);
    sendHtml(res, renderGo({ app, lang: pickLang(req.query), baseUrl: baseUrlFor(req), query: req.query }), {
      cache: 'no-store',
    });
  });

  router.get('/install/:slug', (req, res) => {
    const app = findApp(req.params.slug);
    if (!app) return res.redirect(302, '/');
    logClick('install', app, req);
    res.set('Cache-Control', 'no-store');
    res.redirect(302, playUrlFor(app, req.query));
  });

  router.get('/robots.txt', (req, res) => {
    res.type('text/plain').send(`User-agent: *\nAllow: /\nDisallow: /go/\nDisallow: /install/\nDisallow: /v1/\n\nSitemap: ${baseUrlFor(req)}/sitemap.xml\n`);
  });

  router.get('/sitemap.xml', (req, res) => {
    const base = baseUrlFor(req);
    const urls = ['/', ...APPS.map((a) => `/app/${a.slug}`)];
    res
      .type('application/xml')
      .send(
        `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls
          .map((u) => `  <url><loc>${base}${u}</loc></url>`)
          .join('\n')}\n</urlset>\n`,
      );
  });

  router.get('/favicon.ico', (_req, res) => res.redirect(302, '/store-assets/icons/jamboplus-192.png'));

  return router;
}

module.exports = { createStoreRoutes };
