# JamboPlus

IPTV streaming platform for Tanzania — **JamboPlus** user app + **JamboAd** admin panel + **Node.js API**.

## Project structure

| Folder | Description |
|--------|-------------|
| `lib/` | JamboPlus user Flutter app |
| `adplus/` | JamboAd admin Flutter app |
| `server/` | Node.js API (deploy to Railway) |
| `jamboad_server/` | Legacy Dart backend (deprecated — use `server/`) |

## Run locally

### 1. Start API
```bash
cd server
npm install
npm start
```

### 2. User app (JamboPlus)
```bash
flutter run
```

### 3. Admin app (JamboAd)
```bash
cd adplus
flutter run
```

Login: `jamboplus@gmail.com` / `Chundabadi6%`

## Deploy API to Railway

```bash
cp scripts/railway.env.example scripts/railway.env
railway login
chmod +x scripts/*.sh
./scripts/deploy-railway.sh --setup
```

See [server/README.md](server/README.md) and [scripts/deploy-railway.sh](scripts/deploy-railway.sh).

**Production API:** https://jamboplus-api-production.up.railway.app

Repository: [github.com/Jamboplus/JamboPlus](https://github.com/Jamboplus/JamboPlus)

## Local development

```bash
./scripts/run-local.sh
```
