/**
 * NexoraApp CORS proxy for the Flutter web build (testing / paper trading).
 *
 * The app prefixes every broker API URL with this worker's URL:
 *   https://<worker>.workers.dev/https://api.kite.trade/instruments/BFO
 *
 * Safety rules:
 *  - Only forwards to the Zerodha, Upstox and Groww API hosts.
 *  - Only answers browsers whose Origin is in ALLOWED_ORIGINS.
 *  - Blocks order placement/modification unless ALLOW_ORDERS is "true".
 *
 * Works with no configuration: if ALLOWED_ORIGINS isn't set, only localhost
 * and 127.0.0.1 (any port) may call it, and orders stay blocked. That lets you
 * paste this file straight into the Cloudflare dashboard editor.
 *
 * GET /health reports whether the calling origin is allowed and whether
 * orders are enabled; NexoraApp's "Test proxy" button uses it.
 *
 * Note: Cloudflare's outgoing IPs are shared and change, so this can't be
 * registered as a static IP with brokers. Use it for testing only.
 */

const ALLOWED_HOSTS = new Set([
  'api.kite.trade',
  'api.upstox.com',
  'api-hft.upstox.com',
  'api.groww.in',
  'growwapi-assets.groww.in',
]);

// Endpoints that create, modify or cancel orders. Login, instruments, quotes
// and option-contract lookups stay allowed so paper trading resolves real contracts.
const ORDER_PATHS = {
  'api.kite.trade': [/^\/orders(\/|$)/, /^\/gtt(\/|$)/],
  'api.upstox.com': [/^\/v\d\/order(\/|$)/],
  'api-hft.upstox.com': [/^\/v\d\/order(\/|$)/],
  'api.groww.in': [/^\/v1\/order(-advance)?(\/|$)/],
};

const DEFAULT_ALLOWED_ORIGINS = 'http://localhost:*,http://127.0.0.1:*';

const ALLOWED_HEADERS = 'Authorization, Content-Type, Accept, X-Kite-Version';

// Request headers that must not be forwarded to the broker.
const STRIPPED_HEADERS = ['origin', 'referer', 'host', 'cookie'];

export default {
  async fetch(request, env = {}) {
    const ordersEnabled = env.ALLOW_ORDERS === 'true';
    const origin = request.headers.get('Origin');
    const originAllowed = !!origin && isOriginAllowed(origin, env.ALLOWED_ORIGINS || DEFAULT_ALLOWED_ORIGINS);

    if (new URL(request.url).pathname === '/health') {
      return health(origin, originAllowed, ordersEnabled);
    }
    if (!originAllowed) {
      return new Response('Origin not allowed', { status: 403 });
    }
    return handleAllowedOrigin(request, corsHeaders(origin), ordersEnabled);
  },
};

/** Readable by any origin so the app can explain a rejected origin. */
function health(origin, originAllowed, ordersEnabled) {
  return json(
    { ok: originAllowed, service: 'nexora-cors-proxy', origin, originAllowed, ordersEnabled },
    200,
    { 'Access-Control-Allow-Origin': origin || '*', Vary: 'Origin' },
  );
}

function handleAllowedOrigin(request, cors, ordersEnabled) {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors });
  }
  const target = parseTarget(request.url);
  if (!target) {
    return json({ status: 'error', message: 'Proxy: unsupported target URL.' }, 400, cors);
  }
  if (!ordersEnabled && isOrderRequest(target, request.method)) {
    return blockedOrder(target, cors);
  }
  return forward(request, target, cors);
}

async function forward(request, target, cors) {
  const headers = new Headers(request.headers);
  for (const h of STRIPPED_HEADERS) headers.delete(h);
  for (const h of [...headers.keys()]) if (h.startsWith('cf-')) headers.delete(h);

  const upstream = await fetch(target.toString(), {
    method: request.method,
    headers,
    body: ['GET', 'HEAD'].includes(request.method) ? undefined : request.body,
    redirect: 'manual',
  });

  const response = new Response(upstream.body, upstream);
  for (const [k, v] of Object.entries(cors)) response.headers.set(k, v);
  return response;
}

/** Supports exact origins and a `:*` port wildcard, e.g. `http://localhost:*`. */
export function isOriginAllowed(origin, allowedList = '') {
  return allowedList
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
    .some((allowed) => {
      if (allowed === origin) return true;
      if (allowed.endsWith(':*')) {
        const base = allowed.slice(0, -2);
        return origin === base || new RegExp(`^${escapeRegExp(base)}:\\d+$`).test(origin);
      }
      return false;
    });
}

/** Extracts the broker URL from `https://worker/https://host/path?query`. */
export function parseTarget(requestUrl) {
  const url = new URL(requestUrl);
  // Some clients collapse "https://" to "https:/" inside a path; accept both.
  const raw = (url.pathname.slice(1) + url.search).replace(/^(https?):\/(?!\/)/, '$1://');
  let target;
  try {
    target = new URL(raw);
  } catch {
    return null;
  }
  if (target.protocol !== 'https:' || !ALLOWED_HOSTS.has(target.hostname)) return null;
  return target;
}

export function isOrderRequest(target, method) {
  if (method === 'GET' || method === 'HEAD' || method === 'OPTIONS') return false;
  return (ORDER_PATHS[target.hostname] ?? []).some((re) => re.test(target.pathname));
}

/** Errors in each broker's own format so the app shows the message. */
function blockedOrder(target, cors) {
  const message = 'Order placement is disabled on this proxy (ALLOW_ORDERS is not "true").';
  const body = {
    'api.kite.trade': { status: 'error', message, error_type: 'PermissionException' },
    'api.groww.in': { status: 'FAILURE', error: { code: 'PROXY_BLOCKED', message } },
  }[target.hostname] ?? { status: 'error', errors: [{ errorCode: 'PROXY_BLOCKED', message }] };
  return json(body, 403, cors);
}

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': ALLOWED_HEADERS,
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

function json(body, status, cors) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...cors },
  });
}

function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
