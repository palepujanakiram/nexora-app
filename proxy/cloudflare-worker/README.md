# NexoraApp CORS proxy (Cloudflare Worker)

Lets the **Flutter web** build call the Zerodha and Upstox APIs, which browsers otherwise block (CORS). iOS and Android don't need it.

**For testing and paper trading only.** Cloudflare's outgoing IP addresses are shared and change, so you can't register them with your broker as the static IP that SEBI's API-trading rules require. For live trading, use a server with a static IP.

## What it allows

| | |
|---|---|
| Target hosts | `api.kite.trade`, `api.upstox.com`, `api-hft.upstox.com` only |
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

## Test locally

```bash
node --test        # unit tests, no network
npx wrangler dev   # runs the worker on http://localhost:8787
```

With `wrangler dev` running, set the app's proxy to `http://localhost:8787`.
