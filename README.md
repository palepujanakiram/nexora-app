# NexoraApp

Flutter app (iOS, Android, web) that turns option signals like

```
BUY SENSEX 29 OCT 73100 PUT AT 400-420 WITH SL OF 300 TGT1 540, TGT2 600
```

into orders on any number of Zerodha (Kite Connect) and Upstox accounts.

<p align="center">
  <img src="docs/screenshots/signal.jpg" width="200" alt="Signal screen">
  <img src="docs/screenshots/results.jpg" width="200" alt="Execution results">
  <img src="docs/screenshots/accounts.jpg" width="200" alt="Accounts screen">
  <img src="docs/screenshots/settings.jpg" width="200" alt="Settings screen">
</p>

## How it works

The app has four tabs: **Signal**, **Accounts**, **Activity** and **Settings**. Screenshots are from the web build with two demo accounts in paper mode.

### 1. Add your broker accounts

| | |
|---|---|
| <img src="docs/screenshots/add-account.jpg" width="260" alt="Add account form"> | **Accounts → Add account.** Pick the stock broker with the radio buttons (Zerodha or Upstox); the fields change to match it (Upstox also needs the redirect URI from your Upstox app).<br><br>For each account set the **lots per signal**, the **product** (NRML carry forward or MIS intraday) and **Paper mode**. Paper mode is on by default: the app simulates the orders and sends nothing to the broker.<br><br>Below the form, **How to get your … API keys** lists the steps and links to the broker's developer console and docs. |
| <img src="docs/screenshots/accounts.jpg" width="260" alt="Accounts list"> | Accounts are grouped by broker, and you can add as many keys per broker as you need. Each card shows the masked key, lots, product, **PAPER** / **LIVE** and whether today's session is active.<br><br>**Use by default** decides whether the account is ticked on the Signal screen.<br><br>**Login** (daily): opens the broker's login page; paste back the URL you land on and the app exchanges the `request_token` (Kite) or `code` (Upstox) for an access token. Kite sessions expire at 06:00 IST and Upstox sessions at 03:30 IST. |

### 2. Paste a signal and execute it

| | |
|---|---|
| <img src="docs/screenshots/signal.jpg" width="260" alt="Parsed signal"> | **Signal tab.** Paste the signal and tap **Parse signal**. The card shows what was understood: side, contract (`SENSEX 29 OCT 2026 73100 PE`), exchange (BFO for SENSEX/BANKEX, otherwise NFO), entry range, the limit price that will be used, stop loss, targets and the exit orders.<br><br>Tick the accounts to use and tap **BUY on N account(s)**. The app asks for confirmation, and says whether it's a paper or live trade. |
| <img src="docs/screenshots/results.jpg" width="260" alt="Execution results"> | The orders go to all selected accounts in parallel. For each account the app:<ul><li>looks up the exact option contract and lot size from the broker (when logged in),</li><li>places a LIMIT entry for `lots × lot size` at the chosen end of the entry range,</li><li>optionally places the stop loss and target on the broker's side:<ul><li>**Zerodha**: entry order + two-leg GTT OCO for SL and target.</li><li>**Upstox**: one GTT `MULTIPLE` order (entry + target + stop loss).</li></ul></li></ul>Results show the order IDs, or the error, per account. |

### 3. Review activity

| | |
|---|---|
| <img src="docs/screenshots/activity.jpg" width="260" alt="Activity log"> | **Activity tab.** Every execution is kept with the time, the original signal, the contract, and the order IDs or error (the last 200, stored on the device). **Clear** empties it. |

### 4. Settings

| | |
|---|---|
| <img src="docs/screenshots/settings.jpg" width="260" alt="Settings"> | <ul><li>**Theme colour**: eleven colours, saved on the device.</li><li>**Limit price within the entry range**: low end, middle or high end (for `AT 400-420`: 400, 410 or 420).</li><li>**Exit orders**: entry only, or entry + stop loss & target (GTT).</li><li>**Target used for the GTT exit**: TGT1–TGT3; falls back to the last target if the signal has fewer.</li><li>**Web CORS proxy** (web only, see below).</li></ul> |
| <img src="docs/screenshots/proxy-guide.jpg" width="260" alt="Cloudflare Worker proxy guide"> | **Web only.** Browsers block direct calls to the broker APIs, so the web build needs your own proxy. **How to create the proxy** walks you through a free Cloudflare Worker in four steps: **Copy proxy code** copies the worker (or **View code** shows it to select by hand), and the links open Cloudflare's dashboard and docs.<br><br>**Test proxy** checks the URL and tells you whether it's connected, rejecting this app's address, not the NexoraApp proxy, or unreachable. |

## How account keys are stored

API keys, secrets and access tokens are stored only through `flutter_secure_storage`, never in plain preferences:

- **iOS**: Keychain, readable only while the device is unlocked, not synced to iCloud and not restored to another device.
- **Android**: AES-GCM encrypted with a hardware-backed Android Keystore key. Auto Backup is turned off so the encrypted values are never restored onto a device that doesn't have the key.
- **Web**: encrypted with WebCrypto, but the key lives in the same browser profile. Treat web as convenience only and prefer the mobile apps for live trading accounts.

## Project structure (Clean Architecture)

```
lib/
  main.dart                 init dependencies, runApp
  app.dart                  MaterialApp; rebuilds theme from the saved theme colour
  common/                   code shared by every screen
    di/injector.dart        get_it wiring: data sources → repositories → use cases
    domain/                 pure Dart, no Flutter or HTTP
      entities/             TradeSignal, BrokerAccount, AppSettings, TradePlan, ExecutionResult
      repositories/         abstract interfaces (accounts, settings, activity, broker)
      services/             SignalParser, TradePricing
      usecases/             shared use cases (watch accounts, watch settings)
    data/
      models/               JSON mappers for entities
      datasources/local/    secure storage (keys/tokens), shared preferences
      datasources/remote/   Zerodha Kite Connect and Upstox APIs
      repositories/         repository implementations (in-memory cache + change stream)
    presentation/           shared widgets and theme
    error/  utils/
  screens/<screen>/         signal, accounts, account_edit, activity, settings, home
    view/                   widgets only; reads state from the view model
    viewmodel/              ChangeNotifier; calls use cases, exposes state
    model/                  the screen's UI state / form model
    usecase/                operations this screen performs
```

Dependencies point inward: views → view models → use cases → repository interfaces ← data layer.

## Run

```bash
flutter pub get
flutter run -d chrome     # or an iOS simulator / Android device
```

## Tests and coverage

Every change needs tests, and line coverage of `lib/` must stay at or above **95%** (see [CLAUDE.md](CLAUDE.md)).

```bash
dart run tool/coverage.dart                      # all tests + 95% gate; lists files below 95%
cd proxy/cloudflare-worker && npm run coverage   # worker tests + 95% gate
```

`tool/coverage.dart` counts every file under `lib/`, including files no test imports, so untested code can't hide. The [CI workflow](.github/workflows/ci.yml) runs both checks on every pull request and push to `main`, and uploads the Flutter coverage to qlty.

## Notes and limits

- **Web needs a CORS proxy.** Browsers block direct calls to `api.kite.trade` / `api.upstox.com`. Put your own proxy URL in Settings; it is prepended to every API URL. iOS and Android don't need one. A ready-made Cloudflare Worker for testing (orders blocked by default) is in [proxy/cloudflare-worker](proxy/cloudflare-worker/README.md).
- **Upstox** contract lookup currently covers indices only (NIFTY, BANKNIFTY, FINNIFTY, MIDCPNIFTY, SENSEX, BANKEX).
- The Kite GTT stop-loss leg uses a limit price 5% past the trigger so it still fills on a fast move.
- **Verify with paper mode and one lot first.** The broker API calls follow the published docs but haven't been run against live accounts.
- **Regulation:** SEBI's 2025 retail algo-trading framework applies to API orders (static IP whitelisting, order-rate limits, broker registration of algos). Check what your brokers require before running this live.

## Testing with the real Zerodha and Upstox APIs

Test in three stages. Each stage uses more of the real API, and only the last one sends orders. Neither broker offers this app a sandbox, so everything below talks to your real account.

> **Stay in paper mode until stages 1 and 2 work.** A paper account calls the broker only to log in and look up contracts. It never sends an order.

### Before you start

1. **Create a developer app with each broker** (the in-app guide under **Accounts → Add account** links to both):
   - **Zerodha:** [developers.kite.trade](https://developers.kite.trade/) → create an app. Set the redirect URL to something you can open, e.g. `https://127.0.0.1/`. Copy the API key and API secret.
   - **Upstox:** [account.upstox.com/developer/apps](https://account.upstox.com/developer/apps) → create an app with the same kind of redirect URL. Copy the API key (client_id) and secret. In NexoraApp, the Redirect URI must match the app's redirect URL exactly.
2. **Check the static IP rule before stage 3.** Under SEBI's retail algo-trading framework, brokers can require API orders to come from a static IP you've registered in their developer console. Orders from any other IP are rejected. Logging in and looking up contracts don't need it.
3. **Pick where to run the app:**
   - **Android or iOS (recommended):** calls the broker APIs directly, with no proxy.
     ```bash
     flutter run -d <device-id>      # flutter devices lists them
     ```
   - **Web:** browsers block direct calls to the broker APIs, so set up the CORS proxy first (**Settings → Web CORS proxy**, see the guide in the app). The proxy blocks orders by default, and Cloudflare's IPs aren't static, so on web you can only do stages 1 and 2.

### Stage 1: log in

1. **Accounts → Add account**: choose the broker, enter the API key and secret (plus the redirect URI for Upstox), and leave **Paper mode on**. Save.
2. On the account card, tap **Login → Open login page** and sign in to the broker in the browser.
3. You land on your redirect URL, e.g. `https://127.0.0.1/?request_token=…` (Zerodha) or `https://127.0.0.1/?code=…` (Upstox). The page itself won't load; that's expected. Copy the full address from the browser's address bar.
4. Paste it into the dialog and tap **Generate session**. The card should change to **Logged in**.

The login code is single-use and expires within minutes, so paste it straight away. Sessions end every day (Zerodha at 06:00 IST, Upstox at 03:30 IST), so log in again each morning.

### Stage 2: paper trade with real contract lookups

When a paper account is logged in, the app looks up the real contract on the broker (Zerodha's instrument list, Upstox's option-contract API) but sends no orders.

1. On the **Signal** tab, paste a signal for a **real upcoming expiry** and a strike that's listed, e.g. `BUY NIFTY <next expiry, e.g. 30 OCT> <listed strike> CE AT 100-110 WITH SL OF 80 TGT1 140`.
2. Tick the logged-in paper account and run it ("Run paper trade?").
3. Check the result card:
   - the **trading symbol** is the broker's real one, not the plain signal text;
   - the **quantity** is `lots × the broker's lot size`;
   - the order IDs start with `PAPER-`.

   If the contract isn't found, the expiry or strike isn't listed; check it in Kite or Upstox.

Upstox lookups currently support indices only (NIFTY, BANKNIFTY, FINNIFTY, MIDCPNIFTY, SENSEX, BANKEX).

### Stage 3: one live order (Android/iOS, from your registered IP)

The order calls follow the brokers' published docs but haven't yet been run against live accounts. Start with the smallest order you can afford to lose and watch the broker's own app the whole time.

1. Edit the account: set **Lots per signal** to 1, choose the product (NRML or MIS), and turn **Paper mode off**. The card now shows **LIVE**.
2. In **Settings**, choose the entry price (low / mid / high end of the range) and whether to place the stop loss and target (GTT).
3. Run a signal on that account only. The confirmation reads **"Place LIVE orders?"** and says how many accounts will send real orders.
4. Check in Kite or Upstox:
   - **Zerodha:** a LIMIT entry in **Orders**, plus a two-leg (OCO) **GTT** for the stop loss and target, if enabled.
   - **Upstox:** one **GTT** order with entry, target and stop-loss legs.
5. Cancel anything you don't want to keep (pending orders, GTTs, open positions) in the broker's app. NexoraApp can't cancel orders.

### Troubleshooting

| What you see | Likely cause |
|---|---|
| "Session expired — log in to … first" | The account isn't logged in today. Log in again (stage 1). |
| Error when generating the session | The code was already used or has expired, the API secret is wrong, or (Upstox) the redirect URI doesn't exactly match the app's. |
| Zerodha `TokenException` / 403 | The access token is invalid or expired. Log in again. |
| Contract not found | The expiry date or strike in the signal isn't listed. Check the exact contract in the broker's app. |
| Order rejected about IP, or permission errors | The request didn't come from your registered static IP, or your developer app isn't enabled for orders. |
| Web: requests fail or **Test proxy** fails | The proxy URL is wrong, or this app's address isn't in the Worker's `ALLOWED_ORIGINS`. |
| Web: "Order placement is disabled on this proxy" | Expected: the proxy blocks orders. Use Android/iOS for live orders. |
