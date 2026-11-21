# NexoraApp Cloudflare Worker

Two unrelated jobs live in this one Worker:

1. **CORS proxy** for the **Flutter web** build's broker calls (Zerodha, Upstox, Groww), which browsers otherwise block. iOS and Android don't need it. **For testing and paper trading only** — see [What it allows](#what-it-allows) below.
2. **`/signals` proxy** for the app's **Feed tab**, on every platform. It adds Nexora's EMA Pivot signals API key from the `EPS_API_KEY` secret so that key never ships in app or browser code — see [Signals proxy](#signals-proxy-feed-tab).

## CORS proxy (broker calls)

**For testing and paper trading only.** Cloudflare's outgoing IP addresses are shared and change, so you can't register them with your broker as the static IP that SEBI's API-trading rules require. For live trading, use a server with a static IP.

## What it allows

| | |
|---|---|
| Target hosts | `api.kite.trade`, `api.upstox.com`, `api-hft.upstox.com`, `api.groww.in`, `growwapi-assets.groww.in` only |
| Callers | Browser origins listed in `ALLOWED_ORIGINS` (default: `localhost` / `127.0.0.1`, any port) |
| Orders | **Blocked** while `ALLOW_ORDERS = "false"` (default): placing, modifying or cancelling orders and GTTs returns an error. Login, instrument lists, quotes and option-contract lookups still work, so paper trades resolve real contracts. |

Your API key and access token pass through the worker in request headers. The worker doesn't log or store them, but deploy it only to **your own** Cloudflare account.

## Deploy from the Cloudflare dashboard (no command line)

This is the same flow NexoraApp shows in **Settings → Web CORS proxy → How to create the proxy**.

1. Create a free Cloudflare account and open **Workers & Pages**.
2. Create a Worker from the "Hello World" starter (e.g. `nexora-cors-proxy`) and deploy it.
3. Click **Edit code**, replace the sample with `src/index.js` (the app's **Copy proxy code** button copies it), and deploy.
4. Paste the Worker URL into the app's proxy field and tap **Test proxy**.

No variables are needed: without `ALLOWED_ORIGINS` it accepts only `localhost` / `127.0.0.1`, and orders stay blocked unless `ALLOW_ORDERS` is `"true"`.

## Deploy with the command line

You need a free Cloudflare account and Node.js.

```bash
cd proxy/cloudflare-worker
npx wrangler login
npx wrangler deploy
```

Wrangler prints the URL, e.g. `https://nexora-cors-proxy.<your-subdomain>.workers.dev`.

In NexoraApp → **Settings → Web CORS proxy**, paste that URL. The app adds the trailing slash itself.

## Configure

Edit `[vars]` in `wrangler.toml`, then run `npx wrangler deploy` again:

- `ALLOWED_ORIGINS`: add your hosted web app's origin, e.g. `http://localhost:*,https://nexora.example.com`
- `ALLOW_ORDERS`: leave as `"false"` for testing

## Health check

`GET /health` returns `{"ok", "service", "origin", "originAllowed", "ordersEnabled"}`. The app's **Test proxy** button uses it to tell you whether the proxy is reachable and accepts the app's address.

Only functions and handlers may be exported from `src/index.js`: the Workers runtime refuses other named exports.

## Signals proxy (Feed tab)

`GET /signals` forwards to Nexora's EMA Pivot signals API (`GET https://zxrzvywkyhyssajdkdpy.supabase.co/functions/v1/eps-api`), adding the vendor's `x-api-key` header from the `EPS_API_KEY` secret. The app's `EpsSignalsApi` never sends that key itself, on any platform — this route is what keeps it server-side, as the vendor requires.

1. Deploy the Worker (either method above).
2. Set the vendor's key as a secret (not a `[vars]` entry, so it's encrypted and never committed):
   ```bash
   cd proxy/cloudflare-worker
   npx wrangler secret put EPS_API_KEY
   ```
   Or from the dashboard: **Settings → Variables and Secrets → Add → Secret**.
3. Build the app pointing at your Worker:
   ```bash
   flutter build web --dart-define=EPS_SIGNALS_PROXY_URL=https://nexora-cors-proxy.<your-subdomain>.workers.dev
   ```
   (same for `flutter build apk` / `flutter build ios` / `flutter run`). Without it, the Feed tab shows setup instructions instead of calling out.

Only `symbols`, `tfs`, `history`, `options` and `levels` are forwarded as query parameters (anything else is dropped); the route is open to any origin since it carries no account credentials, and it refuses anything but `GET`. Rows the vendor marks `measured: false` (3m/5m timeframes, option premium signals) are filtered out again in the app ([`EpsFeedModel`](../../lib/common/data/models/eps_signal_model.dart)) as a second line of defence.

## Test locally

```bash
node --test        # unit tests, no network
npx wrangler dev   # runs the worker on http://localhost:8787
```

With `wrangler dev` running, set the app's proxy to `http://localhost:8787`.
