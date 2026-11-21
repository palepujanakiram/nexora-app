# Automatic TestFlight builds with Xcode Cloud

Pushing to `main` builds NexoraApp and uploads it to TestFlight automatically, using Apple's own CI (Xcode Cloud) instead of running `fastlane beta` by hand (see [testflight.md](testflight.md), which still works and is useful for a one-off build).

[`ios/ci_scripts/ci_post_clone.sh`](../ios/ci_scripts/ci_post_clone.sh) is already in the repo and needs no further changes — it's what makes an Xcode Cloud build work for a Flutter project at all:

- Installs the Flutter SDK (Xcode Cloud's macOS image doesn't have it).
- Gives the build a TestFlight-safe build number, using Xcode Cloud's own `$CI_BUILD_NUMBER`.
- Runs `flutter analyze` and the 95% coverage gate (`dart run tool/coverage.dart`) — a failure here stops the build before Xcode archives anything, the same as `fastlane beta`'s checks.

Everything else — connecting the repo and creating the workflow that triggers on `main` — can only be done in Xcode or App Store Connect, on a Mac. There's no file to commit or API call for that part; do it once, yourself:

## One-time setup (on a Mac, in Xcode)

1. **Open the project**: `ios/Runner.xcworkspace` (not `.xcodeproj`) in Xcode, signed in to Xcode with an Apple ID in team **WR859F2ZHY** (Settings → Accounts) — the same account [testflight.md](testflight.md) describes.
2. **Product → Xcode Cloud → Create Workflow.** The first time, Xcode asks to connect your source control provider (GitHub) and install the **Xcode Cloud** GitHub App on `palepujanakiram/nexora-app` (or wherever this repo lives) — approve that.
3. In the workflow editor:
   - **Name:** e.g. `TestFlight on main`.
   - **Start Conditions:** Branch Changes → `main`. Remove any other default condition (e.g. pull requests) unless you also want those building.
   - **Environment:** latest Xcode, macOS version Xcode suggests. Leave **Clean Build** as Xcode defaults it.
   - **Actions:** add **Archive** (this is what produces a distributable build; Xcode Cloud runs `ci_post_clone.sh` automatically before it).
   - **Post-Actions:** add **TestFlight (Internal Testing)** so a successful archive uploads and distributes to your internal testers without another manual step. Add **TestFlight (External Testing)** too only if you want every `main` push to go out to external testers as well — most teams don't.
4. **Save.** Xcode commits nothing for this step; the workflow lives in App Store Connect, tied to this app record (bundle ID `com.srisarani.nexora`), not in the repository.
5. Push to `main` (or click **Start Build** in Xcode's Cloud tab to test it right away without waiting for a push).

## After that

- **Watch builds** in Xcode's Report Navigator (Cloud tab) or at [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → your app → **Xcode Cloud**. Both show the `ci_post_clone.sh` log, so an `analyze`/coverage failure is visible there, same as a CI log.
- **Compute usage** is metered by your App Store Connect plan (a free allotment of compute hours per month, more on a paid plan) — pushing to `main` often will use it faster than the on-demand `fastlane beta` flow did.
- **Missing Compliance**: same as any build, per [testflight.md](testflight.md) — `Info.plist` already declares `ITSAppUsesNonExemptEncryption = NO`, so this shouldn't prompt unless that changes.
- To stop automatic builds without deleting the workflow, edit it and disable or remove the branch start condition.
