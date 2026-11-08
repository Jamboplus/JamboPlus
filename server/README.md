# JamboPlus API (Node.js)

Backend for **JamboPlus** (user app) and **JamboAd** (admin app).

## Quick start (local)

```bash
cd server
npm install
npm start
```

Health check: [http://127.0.0.1:8080/health](http://127.0.0.1:8080/health)

### Default admin login
| Field | Value |
|-------|-------|
| Email | `jamboplus@gmail.com` |
| Password | `Chundabadi6%` |

### App HMAC secret (must match Flutter `--dart-define=JAMBO_APP_SECRET`)
`jamboplus-dev-secret-change-in-production`

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | HTTP port (Railway sets this automatically) |
| `HOST` | `0.0.0.0` | Bind address |
| `JWT_SECRET` | dev value | Admin JWT signing secret — **change in production** |
| `DB_PATH` | `./data/jamboad.db` | SQLite database file |
| `APP_API_KEY` | `jamboplus-dev-key` | App API key (seed only) |
| `APP_API_SECRET` | dev secret | HMAC secret (seed only) |
| `ADMIN_PASSWORD` | `Admin@Jambo2026!` | Initial admin password (seed only) |

Copy `.env.example` to `.env` for local runs (`dotenv` loads it automatically).

**Production API:** https://jamboplus-api-production.up.railway.app

## AppStore website (promo for JamboPlus, Washa TV, LeoTena TV)

The same server hosts a mobile-first app store site. Apps/URLs live in `src/store/catalog.js`; icons in `src/store/public/icons/`.

| Path | What it does |
|------|--------------|
| `/` | Store home (all apps). `?lang=en` for English, default Kiswahili |
| `/app/:slug` | App page with **Install** button |
| `/go/:slug` | **Use this in Facebook ads.** Shows the app briefly, then auto-redirects to Google Play |
| `/install/:slug` | Instant 302 to Google Play |

Slugs: `jamboplus`, `washatv`, `leotena` (aliases such as `washa-tv`, `leotena-tv` also work; unknown slugs go to `/`).
`utm_*` params on `/go` and `/install` are forwarded to Play as `referrer`, e.g.
`/go/washatv?utm_source=facebook&utm_medium=paid&utm_campaign=nov`.

Optional `PUBLIC_BASE_URL` (e.g. `https://your-domain`) forces the absolute URL used in share previews (`og:image`); otherwise it is derived from the request.
Tests: `npm test`.

## Railway deployment

### One-command deploy (recommended)

```bash
cp scripts/railway.env.example scripts/railway.env   # edit secrets if you want
railway login
chmod +x scripts/*.sh
./scripts/deploy-railway.sh --setup                # first time
./scripts/deploy-railway.sh                        # redeploy after changes
./scripts/deploy-railway.sh --build-apk            # deploy + release APKs
```

The script will:
1. Push env vars (`JWT_SECRET`, `APP_API_SECRET`, `DB_PATH=/data/jamboad.db`, …)
2. Add a `/data` volume (first `--setup` run)
3. Generate a public Railway domain
4. Deploy the API
5. Update Flutter production URLs in both apps
6. Health-check `/health`

Secrets are saved to `scripts/railway.env` (gitignored).

### Manual Railway setup

1. Push repo to GitHub → Railway → New Project → set **Root Directory** to `server`
2. Add volume at `/data`, set `DB_PATH=/data/jamboad.db`
3. Or use `./scripts/deploy-railway.sh --setup` from repo root

## API routes

| Auth | Prefix | Routes |
|------|--------|--------|
| None | `/health` | Health check |
| HMAC | `/v1/app/*` | bootstrap, channels, carousel, pricing |
| JWT | `/v1/admin/*` | login, dashboard, users, channels, carousel, pricing, app-config |

HMAC headers: `X-Jambo-Timestamp`, `X-Jambo-Signature`  
Signature: `HMAC-SHA256(secret, timestamp + METHOD + path)`
