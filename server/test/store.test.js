const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const { createStoreRoutes } = require('../src/store/routes');

// Exact Play Store URLs — hard-coded on purpose, independent of catalog.js.
const EXPECTED = {
  jamboplus: 'https://play.google.com/store/apps/details?id=com.jamboplus&pcampaignid=web_share',
  leotena: 'https://play.google.com/store/apps/details?id=com.ghettodevelopers.leotena&pcampaignid=web_share',
  washatv: 'https://play.google.com/store/apps/details?id=com.washatv&pcampaignid=web_share',
  dawaasili: 'https://play.google.com/store/apps/details?id=com.asilia&pcampaignid=web_share',
};
const ALIASES = {
  'jambo-plus': 'jamboplus',
  'leotena-tv': 'leotena',
  'leo-tena': 'leotena',
  'washa-tv': 'washatv',
  washa: 'washatv',
  'dawa-asili': 'dawaasili',
  asilia: 'dawaasili',
  LEOTENA: 'leotena',
};

let server;
let base;

test.before(async () => {
  const app = express();
  app.use(createStoreRoutes());
  server = http.createServer(app);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
test.after(() => server.close());

const get = (p) => fetch(base + p, { redirect: 'manual' });

test('/install/:slug 302s to the exact Play URL', async () => {
  for (const [slug, url] of Object.entries(EXPECTED)) {
    const res = await get(`/install/${slug}`);
    assert.equal(res.status, 302);
    assert.equal(res.headers.get('location'), url);
  }
});

test('aliases resolve to the right app', async () => {
  for (const [alias, slug] of Object.entries(ALIASES)) {
    const res = await get(`/install/${alias}`);
    assert.equal(res.headers.get('location'), EXPECTED[slug], alias);
  }
});

test('/go/:slug page targets only its own Play URL (meta refresh, button, JS)', async () => {
  for (const [slug, url] of Object.entries(EXPECTED)) {
    const res = await get(`/go/${slug}`);
    assert.equal(res.status, 200);
    const html = await res.text();
    const escaped = url.replace(/&/g, '&amp;');
    assert.ok(html.includes(`content="5;url=${escaped}"`), `${slug} meta refresh`);
    assert.ok(html.includes(`href="${escaped}"`), `${slug} button`);
    assert.ok(html.includes(`var u=${JSON.stringify(url)}`), `${slug} js redirect`);
    // must not mention the other apps' Play URLs
    for (const [other, otherUrl] of Object.entries(EXPECTED)) {
      if (other !== slug) assert.ok(!html.includes(otherUrl.replace(/&/g, '&amp;')), `${slug} leaks ${other}`);
    }
  }
});

const NAMES = { jamboplus: 'JamboPlus', washatv: 'Washa TV', leotena: 'LeoTena TV', dawaasili: 'Dawa Asili' };

test('/go page shows ONLY the targeted app (no other app, icon or store link)', async () => {
  for (const slug of Object.keys(EXPECTED)) {
    const html = await (await get(`/go/${slug}`)).text();
    assert.ok(html.includes(NAMES[slug]), `go/${slug} shows its app`);
    assert.ok(!html.includes('href="/"') && !html.includes('/app/'), `go/${slug} has no store links`);
    for (const [other, name] of Object.entries(NAMES)) {
      if (other === slug) continue;
      assert.ok(!html.includes(name), `go/${slug} must not mention ${name}`);
      assert.ok(!html.includes(`icons/${other}`), `go/${slug} must not show ${other} icon`);
    }
  }
});

test('/app page has no "other apps" section', async () => {
  for (const slug of Object.keys(EXPECTED)) {
    const html = await (await get(`/app/${slug}`)).text();
    for (const other of Object.keys(EXPECTED)) {
      if (other !== slug) assert.ok(!html.includes(`/app/${other}`), `app/${slug} links to ${other}`);
    }
  }
});

test('install button is labelled "Install" and Google Play green', async () => {
  const html = await (await get('/go/washatv')).text();
  assert.ok(html.includes('Install</a>'));
  assert.ok(!html.includes('Pakua'));
  assert.ok(html.includes('background:#01875f'));
  const home = await (await get('/')).text();
  assert.ok(!home.includes('>Pakua<') && home.includes('Install</span>'));
});

test('utm params are passed to Play via referrer; base URL unchanged', async () => {
  const res = await get('/install/washatv?utm_source=facebook&utm_medium=paid&utm_campaign=nov&evil=https://x.com');
  const loc = res.headers.get('location');
  assert.ok(loc.startsWith(`${EXPECTED.washatv}&referrer=`));
  assert.equal(
    decodeURIComponent(loc.split('&referrer=')[1]),
    'utm_source=facebook&utm_medium=paid&utm_campaign=nov',
  );
  assert.ok(!loc.includes('evil'));
});

test('unknown slug never guesses an app — back to store', async () => {
  for (const p of ['/go/nope', '/install/nope', '/app/nope', '/go/..%2f..%2fetc']) {
    const res = await get(p);
    assert.equal(res.status, 302, p);
    assert.equal(res.headers.get('location'), '/');
  }
});

test('home lists all 4 apps with their icons; icons are served', async () => {
  const html = await (await get('/')).text();
  for (const slug of Object.keys(EXPECTED)) {
    assert.ok(html.includes(`/app/${slug}`));
    assert.ok(html.includes(`/store-assets/icons/${slug}-192.png`));
    for (const f of [`${slug}.png`, `${slug}-192.png`]) {
      const img = await get(`/store-assets/icons/${f}`);
      assert.equal(img.status, 200);
      assert.equal(img.headers.get('content-type'), 'image/png');
    }
  }
});

test('detail pages render and install button points at /install/:slug', async () => {
  for (const slug of Object.keys(EXPECTED)) {
    const html = await (await get(`/app/${slug}`)).text();
    assert.ok(html.includes(`href="/install/${slug}"`));
    assert.ok(html.includes('property="og:image"'));
  }
});
