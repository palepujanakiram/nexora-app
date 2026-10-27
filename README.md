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
flutter test
flutter run -d chrome     # or an iOS simulator / Android device
```

## Notes and limits

- **Web needs a CORS proxy.** Browsers block direct calls to `api.kite.trade` / `api.upstox.com`. Put your own proxy URL in Settings; it is prepended to every API URL. iOS and Android don't need one. A ready-made Cloudflare Worker for testing (orders blocked by default) is in [proxy/cloudflare-worker](proxy/cloudflare-worker/README.md).
- **Upstox** contract lookup currently covers indices only (NIFTY, BANKNIFTY, FINNIFTY, MIDCPNIFTY, SENSEX, BANKEX).
- The Kite GTT stop-loss leg uses a limit price 5% past the trigger so it still fills on a fast move.
- **Verify with paper mode and one lot first.** The broker API calls follow the published docs but haven't been run against live accounts.
- **Regulation:** SEBI's 2025 retail algo-trading framework applies to API orders (static IP whitelisting, order-rate limits, broker registration of algos). Check what your brokers require before running this live.
