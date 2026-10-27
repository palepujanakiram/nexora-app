import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

import worker, { isOriginAllowed, parseTarget, isOrderRequest } from '../src/index.js';

const env = { ALLOWED_ORIGINS: 'http://localhost:*,https://app.example.com', ALLOW_ORDERS: 'false' };
const PROXY = 'https://proxy.example.workers.dev/';

let upstreamCalls;
beforeEach(() => {
  upstreamCalls = [];
  globalThis.fetch = async (url, init) => {
    upstreamCalls.push({ url, init });
    return new Response(JSON.stringify({ status: 'success', data: { ok: true } }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  };
});

const req = (target, { method = 'GET', origin = 'http://localhost:52341', headers = {}, body } = {}) =>
  new Request(PROXY + target, { method, headers: { ...(origin ? { Origin: origin } : {}), ...headers }, body });

test('origin matching supports exact origins and :* ports', () => {
  assert.ok(isOriginAllowed('http://localhost:52341', env.ALLOWED_ORIGINS));
  assert.ok(isOriginAllowed('https://app.example.com', env.ALLOWED_ORIGINS));
  assert.ok(!isOriginAllowed('http://localhost.evil.com:80', env.ALLOWED_ORIGINS));
  assert.ok(!isOriginAllowed('https://evil.com', env.ALLOWED_ORIGINS));
});

test('only broker hosts over https are valid targets', () => {
  assert.equal(parseTarget(PROXY + 'https://api.kite.trade/instruments/BFO').hostname, 'api.kite.trade');
  assert.equal(parseTarget(PROXY + 'https:/api.upstox.com/v2/option/contract?x=1').search, '?x=1');
  assert.equal(parseTarget(PROXY + 'https://evil.com/x'), null);
  assert.equal(parseTarget(PROXY + 'http://api.kite.trade/x'), null);
  assert.equal(parseTarget(PROXY + 'not a url'), null);
});

test('order endpoints are detected per broker', () => {
  const t = (u) => new URL(u);
  assert.ok(isOrderRequest(t('https://api.kite.trade/orders/regular'), 'POST'));
  assert.ok(isOrderRequest(t('https://api.kite.trade/gtt/triggers'), 'POST'));
  assert.ok(isOrderRequest(t('https://api-hft.upstox.com/v3/order/place'), 'POST'));
  assert.ok(isOrderRequest(t('https://api.upstox.com/v3/order/gtt/place'), 'POST'));
  assert.ok(!isOrderRequest(t('https://api.kite.trade/session/token'), 'POST'));
  assert.ok(!isOrderRequest(t('https://api.upstox.com/v2/login/authorization/token'), 'POST'));
  assert.ok(!isOrderRequest(t('https://api.kite.trade/orders'), 'GET'));
});

test('preflight returns CORS headers for allowed origins', async () => {
  const res = await worker.fetch(req('https://api.kite.trade/instruments/BFO', { method: 'OPTIONS' }), env);
  assert.equal(res.status, 204);
  assert.equal(res.headers.get('Access-Control-Allow-Origin'), 'http://localhost:52341');
  assert.match(res.headers.get('Access-Control-Allow-Headers'), /X-Kite-Version/);
  assert.equal(upstreamCalls.length, 0);
});

test('requests from unknown or missing origins are rejected', async () => {
  for (const origin of ['https://evil.com', null]) {
    const res = await worker.fetch(req('https://api.kite.trade/instruments/BFO', { origin }), env);
    assert.equal(res.status, 403);
  }
  assert.equal(upstreamCalls.length, 0);
});

test('forwards allowed calls with auth headers, without origin/cookies, and adds CORS', async () => {
  const res = await worker.fetch(
    req('https://api.kite.trade/quote/ltp?i=BFO%3ASENSEX', {
      headers: { Authorization: 'token k:t', 'X-Kite-Version': '3', Cookie: 'a=b' },
    }),
    env,
  );
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('Access-Control-Allow-Origin'), 'http://localhost:52341');
  const [call] = upstreamCalls;
  assert.equal(call.url, 'https://api.kite.trade/quote/ltp?i=BFO%3ASENSEX');
  assert.equal(call.init.headers.get('authorization'), 'token k:t');
  assert.equal(call.init.headers.get('x-kite-version'), '3');
  assert.equal(call.init.headers.get('origin'), null);
  assert.equal(call.init.headers.get('cookie'), null);
});

test('blocks orders in each broker\'s error format unless ALLOW_ORDERS is true', async () => {
  const kite = await worker.fetch(req('https://api.kite.trade/orders/regular', { method: 'POST', body: 'x=1' }), env);
  assert.equal(kite.status, 403);
  assert.match((await kite.json()).message, /disabled/);

  const upstox = await worker.fetch(req('https://api-hft.upstox.com/v3/order/place', { method: 'POST', body: '{}' }), env);
  assert.match((await upstox.json()).errors[0].message, /disabled/);
  assert.equal(upstreamCalls.length, 0);

  const allowed = await worker.fetch(
    req('https://api.kite.trade/orders/regular', { method: 'POST', body: 'x=1' }),
    { ...env, ALLOW_ORDERS: 'true' },
  );
  assert.equal(allowed.status, 200);
  assert.equal(upstreamCalls.length, 1);
});

test('rejects targets outside the broker allowlist', async () => {
  const res = await worker.fetch(req('https://evil.com/steal'), env);
  assert.equal(res.status, 400);
  assert.equal(upstreamCalls.length, 0);
});

test('works with no configuration: localhost allowed, orders blocked', async () => {
  const ok = await worker.fetch(req('https://api.kite.trade/instruments/BFO'), {});
  assert.equal(ok.status, 200);
  const blocked = await worker.fetch(req('https://api.kite.trade/orders/regular', { method: 'POST', body: 'x=1' }));
  assert.equal(blocked.status, 403);
  const other = await worker.fetch(req('https://api.kite.trade/instruments/BFO', { origin: 'https://evil.com' }), {});
  assert.equal(other.status, 403);
});

test('/health reports origin and order status', async () => {
  const good = await worker.fetch(req('health'), env);
  assert.equal(good.headers.get('Access-Control-Allow-Origin'), 'http://localhost:52341');
  assert.deepEqual(await good.json(), {
    ok: true, service: 'nexora-cors-proxy', origin: 'http://localhost:52341', originAllowed: true, ordersEnabled: false,
  });

  const bad = await worker.fetch(req('health', { origin: 'https://other.app' }), env);
  const body = await bad.json();
  assert.equal(body.ok, false);
  assert.equal(body.originAllowed, false);
  assert.equal(bad.headers.get('Access-Control-Allow-Origin'), 'https://other.app');
  assert.equal(upstreamCalls.length, 0);
});
