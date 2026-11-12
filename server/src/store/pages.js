const { APPS } = require('./catalog');

const STRINGS = {
  sw: {
    storeName: 'JamboPlus AppStore',
    heroTitle: 'Apps zetu',
    heroSub: 'Pakua apps zetu moja kwa moja kutoka Google Play.',
    install: 'Install',
    installOn: 'Install',
    redirecting: 'Tunakupeleka Google Play kupakua app hii…',
    openingTitle: 'Tunakupeleka Google Play…',
    openingSub: 'Subiri kidogo, utaelekezwa kupakua {name}.',
    openNow: 'Fungua Google Play sasa',
    backToStore: 'Tazama apps zote',
    about: 'Kuhusu app hii',
    features: 'Vipengele',
    more: 'Apps nyingine',
    back: 'Rudi',
    onPlay: 'Inapatikana Google Play',
    footer: 'Apps zote zinapatikana rasmi kwenye Google Play.',
    otherLang: 'English',
    otherLangCode: 'en',
    htmlLang: 'sw',
  },
  en: {
    storeName: 'JamboPlus AppStore',
    heroTitle: 'Our apps',
    heroSub: 'Download our apps straight from Google Play.',
    install: 'Install',
    installOn: 'Install',
    redirecting: 'Taking you to Google Play to install this app…',
    openingTitle: 'Taking you to Google Play…',
    openingSub: 'One moment, you are being sent to install {name}.',
    openNow: 'Open Google Play now',
    backToStore: 'See all apps',
    about: 'About this app',
    features: 'Features',
    more: 'More apps',
    back: 'Back',
    onPlay: 'Available on Google Play',
    footer: 'All apps are officially available on Google Play.',
    otherLang: 'Kiswahili',
    otherLangCode: 'sw',
    htmlLang: 'en',
  },
};

const UTM_KEYS = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term'];

function esc(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function pickLang(query) {
  return query && query.lang === 'en' ? 'en' : 'sw';
}

/**
 * Google Play URL for an app. The base URL is always the catalog URL. If the
 * visitor arrived with utm_* params (e.g. from a Facebook ad) they are passed
 * to Play through the standard `referrer` param so installs can be attributed.
 */
function utmParams(query = {}) {
  const params = new URLSearchParams();
  for (const key of UTM_KEYS) {
    const raw = query[key];
    const value = Array.isArray(raw) ? raw[0] : raw;
    if (typeof value === 'string' && value.trim()) params.set(key, value.trim().slice(0, 100));
  }
  return params;
}

function utmQueryString(query) {
  const qs = utmParams(query).toString();
  return qs ? `?${qs}` : '';
}

function playUrlFor(app, query = {}) {
  const referrer = utmParams(query).toString();
  return referrer ? `${app.playUrl}&referrer=${encodeURIComponent(referrer)}` : app.playUrl;
}

const icon = (app, size = 512) =>
  `/store-assets/icons/${app.slug}${size <= 192 ? '-192' : ''}.png`;

const CSS = `
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
:root{--bg:#f3f5fa;--card:#fff;--ink:#101828;--muted:#667085;--line:#e6e9f2;--brand:#1e6bff}
html{background:#dfe4ef}
body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;color:var(--ink);background:var(--bg);
  max-width:480px;margin:0 auto;min-height:100vh;min-height:100dvh;line-height:1.45;position:relative;
  box-shadow:0 0 40px rgba(16,24,40,.12);padding-bottom:env(safe-area-inset-bottom)}
a{color:inherit;text-decoration:none}
img{display:block;max-width:100%}
/* Play Store rounds app icons (~22%); some icons (LeoTena) are opaque squares */
.ico,.mini img,.top .logo{border-radius:22%}
.top{display:flex;align-items:center;gap:10px;padding:14px 16px;background:#fff;border-bottom:1px solid var(--line);position:sticky;top:0;z-index:5}
.top .logo{width:34px;height:34px}
.top .name{font-weight:800;font-size:17px;letter-spacing:-.2px;flex:1}
.top .name b{color:var(--brand)}
.lang{font-size:13px;font-weight:600;color:var(--brand);padding:6px 10px;border-radius:999px;background:#eaf1ff}
.back{font-size:22px;line-height:1;width:34px;height:34px;display:grid;place-items:center;border-radius:50%;background:#f0f2f8}
.hero{padding:26px 18px 8px}
.hero h1{font-size:26px;line-height:1.15;letter-spacing:-.5px}
.hero p{color:var(--muted);margin-top:8px;font-size:15px}
.list{padding:14px 14px 8px;display:grid;gap:12px}
.card{display:block;background:var(--card);border:1px solid var(--line);border-radius:20px;padding:14px;position:relative;overflow:hidden;
  box-shadow:0 1px 2px rgba(16,24,40,.04)}
.card::before{content:"";position:absolute;inset:0 auto 0 0;width:5px;background:var(--accent)}
.card-row{display:flex;gap:14px;align-items:center}
.card .ico{width:72px;height:72px;flex:none;object-fit:contain}
.card h2{font-size:18px;letter-spacing:-.2px}
.card .cat{font-size:12px;color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.4px}
.card .tag{font-size:14px;color:#475467;margin-top:4px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.card-foot{display:flex;align-items:center;justify-content:space-between;margin-top:12px;gap:10px}
.play{display:flex;align-items:center;gap:6px;font-size:12px;color:var(--muted);font-weight:600}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;border-radius:999px;font-weight:800;font-size:15px;
  padding:11px 22px;background:#01875f;color:#fff;border:0;cursor:pointer}
.btn:active{transform:scale(.97)}
.btn.block{display:flex;width:100%;padding:15px 22px;font-size:17px}
.foot{text-align:center;color:var(--muted);font-size:12.5px;padding:22px 18px 28px}
.detail-head{display:flex;gap:16px;align-items:center;padding:22px 18px 8px}
.detail-head .ico{width:104px;height:104px;object-fit:contain;flex:none}
.detail-head h1{font-size:26px;letter-spacing:-.5px;line-height:1.1}
.detail-head .cat{color:var(--accent-dark,var(--brand));font-weight:700;font-size:14px;margin-top:4px}
.detail-head .by{color:var(--muted);font-size:13px;margin-top:2px}
.cta{padding:14px 18px 6px}
.section{padding:20px 18px 0}
.section h3{font-size:18px;margin-bottom:8px;letter-spacing:-.2px}
.section p{color:#475467;font-size:15px}
.feat{list-style:none;display:grid;gap:9px}
.feat li{display:flex;gap:10px;align-items:flex-start;font-size:15px;color:#344054}
.feat li::before{content:"✓";flex:none;width:22px;height:22px;border-radius:50%;background:var(--accent);color:var(--accent-ink,#fff);
  font-size:13px;font-weight:800;display:grid;place-items:center;margin-top:1px}
.mini{display:flex;gap:12px;align-items:center;background:#fff;border:1px solid var(--line);border-radius:16px;padding:10px 12px;margin-bottom:10px}
.mini img{width:48px;height:48px;object-fit:contain;flex:none}
.mini div{flex:1;min-width:0}
.mini b{display:block;font-size:15px}
.mini span{font-size:12.5px;color:var(--muted)}
.sticky{position:sticky;bottom:0;padding:12px 16px calc(12px + env(safe-area-inset-bottom));background:linear-gradient(to top,var(--bg) 70%,rgba(243,245,250,0));margin-top:18px}
.band{height:6px;background:var(--accent)}
.note{display:flex;align-items:center;justify-content:center;gap:10px;margin-top:12px;font-size:13.5px;color:var(--muted);text-align:center}
.spin{flex:none;width:16px;height:16px;border-radius:50%;border:2.5px solid #d0d5dd;border-top-color:#01875f;animation:spin .8s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
`;

const GPLAY_ICON =
  '<svg width="14" height="14" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M6 3.5v17a1 1 0 0 0 1.5.9l14-8.5a1 1 0 0 0 0-1.8l-14-8.5A1 1 0 0 0 6 3.5z"/></svg>';

function layout({ lang, title, description, baseUrl, path, image, body, bodyClass = '', accent, head = '', noindex = false, siteName, favicon }) {
  const t = STRINGS[lang];
  const url = `${baseUrl}${path}`;
  const style = accent
    ? ` style="--accent:${esc(accent.accent)};--accent-ink:${esc(accent.accentText)}"`
    : '';
  return `<!doctype html>
<html lang="${t.htmlLang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<meta name="theme-color" content="#ffffff">
${noindex ? '<meta name="robots" content="noindex,nofollow">' : `<link rel="canonical" href="${esc(url)}">`}
<meta property="og:type" content="website">
<meta property="og:site_name" content="${esc(siteName || t.storeName)}">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${esc(url)}">
<meta property="og:image" content="${esc(baseUrl + image)}">
<meta name="twitter:card" content="summary">
<link rel="icon" type="image/png" href="${esc(favicon || '/store-assets/icons/jamboplus-192.png')}">
<link rel="apple-touch-icon" href="${esc(favicon || '/store-assets/icons/jamboplus-192.png')}">
${head}
<style>${CSS}</style>
</head>
<body class="${bodyClass}"${style}>
${body}
</body>
</html>`;
}

function withLang(path, lang) {
  return lang === 'en' ? `${path}${path.includes('?') ? '&' : '?'}lang=en` : path;
}

function topbar(lang, { backHref, langPath }) {
  const t = STRINGS[lang];
  const other = t.otherLangCode;
  const langHref = other === 'en' ? `${langPath}?lang=en` : langPath;
  const left = backHref
    ? `<a class="back" href="${esc(withLang(backHref, lang))}" aria-label="${esc(t.back)}">‹</a>`
    : `<img class="logo" src="${icon(APPS[0], 192)}" alt="" width="34" height="34">`;
  return `<header class="top">${left}<div class="name">Jambo<b>Plus</b> AppStore</div><a class="lang" href="${esc(langHref)}">${esc(t.otherLang)}</a></header>`;
}

function renderHome({ lang, baseUrl, query }) {
  const t = STRINGS[lang];
  const cards = APPS.map((app) => `
<a class="card" href="${esc(withLang(`/app/${app.slug}`, lang))}" style="--accent:${esc(app.accent)}">
  <div class="card-row">
    <img class="ico" src="${icon(app, 192)}" alt="${esc(app.name)}" width="72" height="72" loading="eager">
    <div>
      <div class="cat">${esc(app.category[lang])}</div>
      <h2>${esc(app.name)}</h2>
      <div class="tag">${esc(app.tagline[lang])}</div>
    </div>
  </div>
  <div class="card-foot">
    <span class="play">${GPLAY_ICON} ${esc(t.onPlay)}</span>
    <span class="btn">${GPLAY_ICON} ${esc(t.install)}</span>
  </div>
</a>`).join('');

  const body = `
${topbar(lang, { langPath: '/' })}
<section class="hero"><h1>${esc(t.heroTitle)}</h1><p>${esc(t.heroSub)}</p></section>
<main class="list">${cards}</main>
<footer class="foot">${esc(t.footer)}</footer>`;

  return layout({
    lang,
    title: t.storeName,
    description: `${t.heroSub} ${APPS.map((a) => a.name).join(', ')}.`,
    baseUrl,
    path: '/',
    image: icon(APPS[0]),
    body,
  });
}

/** Single-app body shared by the app page and the ad landing page. */
function appBody(app, lang, installHref) {
  const t = STRINGS[lang];
  return `
<div class="band"></div>
<section class="detail-head">
  <img class="ico" src="${icon(app)}" alt="${esc(app.name)}" width="104" height="104">
  <div>
    <h1>${esc(app.name)}</h1>
    <div class="cat">${esc(app.category[lang])}</div>
    <div class="by">${esc(t.onPlay)}</div>
  </div>
</section>
<section class="section" style="padding-top:6px"><p>${esc(app.tagline[lang])}</p></section>
<section class="section"><h3>${esc(t.features)}</h3><ul class="feat">${app.features[lang].map((f) => `<li>${esc(f)}</li>`).join('')}</ul></section>
<section class="section"><h3>${esc(t.about)}</h3><p>${esc(app.about[lang])}</p></section>`;
}

const installBtn = (href, label, extra = '') =>
  `<a class="btn block" href="${esc(href)}" rel="nofollow"${extra}>${GPLAY_ICON.replace('width="14" height="14"', 'width="20" height="20"')} ${esc(label)}</a>`;

function renderApp({ app, lang, baseUrl, query }) {
  const t = STRINGS[lang];
  const installHref = `/install/${app.slug}${utmQueryString(query)}`;
  const body = `
${topbar(lang, { backHref: '/', langPath: `/app/${app.slug}` })}
${appBody(app, lang, installHref)}
<div class="sticky">${installBtn(installHref, t.install)}</div>
<footer class="foot">${esc(t.footer)}</footer>`;

  return layout({
    lang,
    title: `${app.name} — ${t.storeName}`,
    description: app.tagline[lang],
    baseUrl,
    path: `/app/${app.slug}`,
    image: icon(app),
    body,
    accent: app,
  });
}

/**
 * Ad landing page: shows ONLY the targeted app, with a green Install button,
 * then auto-redirects to that app's Google Play page.
 */
function renderGo({ app, lang, baseUrl, query }) {
  const t = STRINGS[lang];
  const target = playUrlFor(app, query);
  const jsTarget = JSON.stringify(target).replace(/</g, '\\u003c');
  const body = `
<header class="top"><img class="logo" src="${icon(app, 192)}" alt="" width="34" height="34"><div class="name">${esc(app.name)}</div></header>
${appBody(app, lang, target)}
<div class="sticky">
  <a class="btn block" href="${esc(target)}" rel="noopener">${GPLAY_ICON.replace('width="14" height="14"', 'width="20" height="20"')} ${esc(t.install)}</a>
  <div class="note"><span class="spin" role="status" aria-label="${esc(t.openingTitle)}"></span><span>${esc(t.redirecting)}</span></div>
</div>
<script>
(function(){var u=${jsTarget};setTimeout(function(){window.location.replace(u)},2000)})();
</script>`;

  return layout({
    lang,
    title: `${app.name} — ${t.openingTitle}`,
    description: app.tagline[lang],
    baseUrl,
    path: `/go/${app.slug}`,
    image: icon(app),
    body,
    accent: app,
    noindex: true,
    siteName: app.name,
    favicon: icon(app, 192),
    head: `<meta http-equiv="refresh" content="5;url=${esc(target)}">`,
  });
}

module.exports = { renderHome, renderApp, renderGo, playUrlFor, pickLang, esc };
