# Automatic TestFlight builds with Xcode Cloud

Pushing to `main` builds NexoraApp and uploads it to TestFlight automatically, using Apple's own CI (Xcode Cloud) instead of running `fastlane beta` by hand (see [testflight.md](testflight.md), which still works and is useful for a one-off build).

[`ios/ci_scripts/ci_post_clone.sh`](../ios/ci_scripts/ci_post_clone.sh) is already in the repo and needs no further changes — it's what makes an Xcode Cloud build work for a Flutter project at all:

- Installs the Flutter SDK (Xcode Cloud's macOS image doesn't have it).
- Gives the build a TestFlight-safe build number, using Xcode Cloud's own `$CI_BUILD_NUMBER`.
- Runs `flutter analyze` and the 95% coverage gate (`dart run tool/coverage.dart`) — a failure here stops the build before Xcode archives anything, the same as `fastlane beta`'s checks.

Everything else — connecting the repo and creating the workflow that triggers on `main` — can only be done in Xcode or App Store Connect, on a Mac. There's no file to commit or API call for that part; do it once, yourself:

## One-time setup (on a Mac, in Xcode)

This needs Xcode's GUI wizard — there's no way to create the *first* Xcode Cloud workflow from the App Store Connect website or an API. If nobody on the team has a Mac, a short paid session on a cloud Mac (e.g. MacinCloud, Scaleway's Apple Silicon instances) is enough — once this workflow exists, every build after it runs in Apple's cloud, no Mac needed again. Budget about 15–20 minutes.

1. **Install Xcode** from the Mac App Store if it isn't already, and open it once to accept its license.
2. **Get the code onto the Mac**: `git clone https://github.com/palepujanakiram/nexora-app.git` (or download/unzip it), then open **`ios/Runner.xcworkspace`** in Xcode — double-click it, or `open ios/Runner.xcworkspace` in Terminal. **Not** `Runner.xcodeproj` — that opens without the Flutter/CocoaPods-equivalent configuration Xcode Cloud needs.
3. **Sign in**: Xcode menu (top-left, next to the Apple logo) → **Settings…** → **Accounts** tab → **+** (bottom-left) → **Apple ID** → sign in with an account in team **WR859F2ZHY** that can manage certificates (Account Holder, Admin, or App Manager) — the same account [testflight.md](testflight.md) describes. Close Settings.
4. **Check signing is ready**: in the left Navigator, click the blue **Runner** project icon at the top → under **TARGETS** click **Runner** → **Signing & Capabilities** tab. Confirm **Automatically manage signing** is checked and **Team** shows your team (WR859F2ZHY / its name). If Team is blank, pick it from the dropdown.
5. **Start the wizard**: menu bar → **Product → Xcode Cloud → Create Workflow…** (if you don't see "Xcode Cloud" under Product, Xcode is still indexing the project — wait a few seconds and check again).
6. **Grant access**, first time only:
   - Xcode shows a screen confirming the App Store Connect app it found (bundle ID `com.srisarani.nexora`, app "Srisarani Stocks" / "NexoraApp"). Click **Next**.
   - It then asks to connect to your source control provider. Click **Grant Access** (or **Connect**) next to GitHub. This opens your browser to GitHub asking you to install/authorize the **"Xcode Cloud"** GitHub App — sign in to GitHub if needed, choose **Only select repositories**, pick `palepujanakiram/nexora-app`, and click **Install & Authorize** (or **Save**). Return to Xcode; it should show the repo as connected.
7. **Xcode now shows a workflow editor** pre-filled with a suggested workflow (usually named after the scheme, "Runner"). Edit it:
   - **Name** (top of the editor): click it, rename to `TestFlight on main`.
   - **Start Conditions** tab (left side of the editor): there's likely a default "Branch Changes" condition for every branch, or none at all. Click it (or **+ Add Start Condition** → **Branch Changes** if there isn't one) → under **Branch**, choose **main** specifically (not "Any branch") from the dropdown — it lists branches Xcode Cloud found in the repo. Remove any other start condition (e.g. "Tag Changes", "Pull Request Changes") by hovering it and clicking the **−** that appears, unless you also want those to build.
   - **Environment** tab: leave **Xcode Version** and **macOS Version** at their suggested/latest values unless you have a reason to pin older ones.
   - **Actions** tab: there's probably a default **Archive** action already (if not, click **+ Add Action** → **Archive**). Leave its **Scheme** as **Runner** and **Platform** as **iOS**. Xcode Cloud runs `ios/ci_scripts/ci_post_clone.sh` automatically right after cloning, before this Archive action, so Flutter gets installed and `flutter analyze` / the coverage gate run before anything is archived. You can remove a separate "Build" or "Test" action if Xcode added one by default — Archive already builds; a Test action would only additionally run the native `RunnerTests` XCTest target, which is optional and unrelated to the Dart tests.
   - Still on the **Archive** action, find **Post-Actions** (below/beside it in the same tab) → **+ Add Post-Action** → **TestFlight Internal Testing**. In its settings, tick the internal testing group(s) to notify (e.g. the default "App Store Connect Users" group, or whichever group you've set up under **TestFlight → Internal Testing** in App Store Connect). Only add **TestFlight External Testing** too if you want every `main` push to go straight to external testers — most teams don't.
8. **Save**: click **Save Workflow** (or the checkmark) at the top-right of the editor. Xcode doesn't commit anything to the repo for this — the workflow lives in App Store Connect, tied to this app record, not in a file.
9. **Test it immediately** (don't wait for a push): in Xcode's left sidebar icons, click the **Report Navigator** (the icon that looks like a speech bubble/graph, or use **Window → Cloud Workflows**), find your new workflow, and click **Start Build** (or right-click it → **Start Build…**) → choose branch **main** → **Start Build**. Watch it progress through "Clone" → "ci_post_clone.sh" (this is where you'll see the Flutter install and analyze/coverage output — check here first if anything fails) → "Archive" → "TestFlight Internal Testing".
10. Once it finishes, the build shows up under **TestFlight** in App Store Connect (and in your testers' TestFlight app after Apple finishes processing, usually 10–30 minutes).

From here on, every push to `main` triggers this automatically — nobody needs to touch Xcode again unless the workflow itself needs changing (which you *can* often do afterwards from the App Store Connect website's **Xcode Cloud** tab, without Xcode).

## After that

- **Watch builds** in Xcode's Report Navigator (Cloud tab) or at [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → your app → **Xcode Cloud**. Both show the `ci_post_clone.sh` log, so an `analyze`/coverage failure is visible there, same as a CI log.
- **Compute usage** is metered by your App Store Connect plan (a free allotment of compute hours per month, more on a paid plan) — pushing to `main` often will use it faster than the on-demand `fastlane beta` flow did.
- **Missing Compliance**: same as any build, per [testflight.md](testflight.md) — `Info.plist` already declares `ITSAppUsesNonExemptEncryption = NO`, so this shouldn't prompt unless that changes.
- To stop automatic builds without deleting the workflow, edit it and disable or remove the branch start condition.
