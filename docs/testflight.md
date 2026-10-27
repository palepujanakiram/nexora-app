# Releasing to TestFlight with fastlane

The fastlane setup in [`ios/fastlane`](../ios/fastlane/Fastfile) builds NexoraApp, signs it and uploads it to TestFlight in one command:

```bash
cd ios
bundle exec fastlane beta
```

| | |
|---|---|
| **App** | Bundle ID `com.srisarani.nexora`, team `WR859F2ZHY` (set in the Xcode project and [`ios/fastlane/Appfile`](../ios/fastlane/Appfile)) |
| **Minimum iOS** | 15.0 (the lowest Xcode 27 can build for) |
| **Version** | Taken from `version:` in `pubspec.yaml` (e.g. `1.0.0`) |
| **Build number** | Latest TestFlight build + 1, worked out automatically |
| **Signing** | Automatic: Xcode creates or downloads the distribution certificate and profile using the App Store Connect API key |
| **Sign-in** | App Store Connect API key, so no Apple ID password or 2FA prompts |

## One-time setup

### 1. Tools on the Mac

- Keep the project **outside iCloud Drive** (not in `~/Desktop` or `~/Documents` when "Desktop & Documents Folders" sync is on): code signing fails there.

- **Xcode** (with the iOS platform installed) and the **Flutter** SDK.
- **Ruby** with **Bundler**. fastlane itself is installed per project:

  ```bash
  cd ios
  bundle config set --local path vendor/bundle
  bundle install
  ```

- fastlane needs a UTF-8 locale. Add to your shell profile (`~/.zshrc`):

  ```bash
  export LC_ALL=en_US.UTF-8
  export LANG=en_US.UTF-8
  ```

### 2. Create the app in App Store Connect

TestFlight uploads need an app record, and the App Store Connect API can't create one, so do this once by hand:

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com) with an account in team **WR859F2ZHY**.
2. **Apps → + → New App**.
3. **Platform:** iOS. **Name:** NexoraApp (or the name you'll publish under). **Primary language:** your choice.
4. **Bundle ID:** choose **com.srisarani.nexora**. If it isn't listed, register it first at [developer.apple.com → Identifiers](https://developer.apple.com/account/resources/identifiers/list) (**+ → App IDs → App**, explicit Bundle ID `com.srisarani.nexora`).
5. **SKU:** any unique text, e.g. `nexora-ios`. Tap **Create**.

### 3. Create an App Store Connect API key

1. App Store Connect → **Users and Access → Integrations → App Store Connect API → Team Keys**. (If you've never used the API, request access first.)
2. Tap **+**, name it e.g. `fastlane`, and choose the **Admin** role. Admin is needed so Xcode can create the distribution certificate and profile; **App Manager** is enough if your certificate and profile already exist.
3. **Download** the `AuthKey_XXXXXXXXXX.p8` file. Apple lets you download it **only once**; store it somewhere safe, outside the repository.
4. Note the **Key ID** (next to the key) and the **Issuer ID** (top of the page).

### 4. Tell fastlane about the key

Set these environment variables, for example in `~/.zshrc` or in a file you `source` before releasing. Never commit them.

```bash
export ASC_KEY_ID="XXXXXXXXXX"                              # Key ID
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Issuer ID
export ASC_KEY_PATH="$HOME/keys/AuthKey_XXXXXXXXXX.p8"      # downloaded key file
```

On a CI server, store the key's contents as a secret instead of a file:

```bash
export ASC_KEY_CONTENT="$(base64 -i AuthKey_XXXXXXXXXX.p8)"  # used when ASC_KEY_PATH isn't set
```

## Releasing a build

```bash
cd ios
bundle exec fastlane beta
```

What it does:

1. Checks the API key settings.
2. Runs `flutter analyze` and the tests with the 95% coverage gate (`dart run tool/coverage.dart`). A failure stops the release.
3. Reads the latest TestFlight build number for `com.srisarani.nexora` and uses the next one.
4. Builds the Flutter app (`flutter build ios --release`) with the version from `pubspec.yaml` and that build number.
5. Archives and exports a signed App Store `.ipa` to `build/ios/fastlane/NexoraApp-<version>-<build>.ipa`.
6. Uploads it to TestFlight, with the last 10 commit messages as "What to Test".

The upload finishes in a few minutes; Apple then processes the build (usually 10–30 minutes) before testers can install it.

### Options

```bash
bundle exec fastlane beta build_number:42            # use a specific build number
bundle exec fastlane beta skip_checks:true           # skip analyze + tests (not for real releases)
bundle exec fastlane beta changelog:"Groww support"  # custom "What to Test" text
bundle exec fastlane beta groups:"Internal,QA"       # also give the build to these TestFlight groups (waits for processing)
bundle exec fastlane beta wait:true                  # wait until Apple finishes processing

bundle exec fastlane build                           # build and sign the .ipa without uploading
bundle exec fastlane checks                          # only analyze + tests
```

### Bumping the version

The build number goes up by itself. To release a new version (e.g. `1.1.0`), change `version:` in `pubspec.yaml`:

```yaml
version: 1.1.0+1
```

The `+1` part is ignored by the lane; it always uses the next TestFlight build number.

## After the upload

- **Export compliance:** the app only uses standard HTTPS. Until the Info.plist declares this, App Store Connect asks about encryption for each build (**TestFlight → the build → Manage**). To stop the question, add `ITSAppUsesNonExemptEncryption` = `NO` to `ios/Runner/Info.plist` once you've confirmed it applies to you.
- **Testers:** add internal testers under **TestFlight → Internal Testing**. External testers need a group and Apple's beta review.

## Troubleshooting

| Problem | Fix |
|---|---|
| *Set the ASC_KEY_ID environment variable* | Do step 4 of the setup in this shell, or `source` the file with the variables. |
| *Could not find App with App Identifier 'com.srisarani.nexora'* | The app record doesn't exist yet or is in another team. Do step 2. |
| *No signing certificate "iOS Distribution" found* / *requires a provisioning profile* | The API key isn't **Admin**, so Xcode couldn't create them. Use an Admin key, or create the certificate and an App Store profile on developer.apple.com. |
| *The bundle version must be higher than the previously uploaded version* | Another upload used that number. Run again (it fetches the latest), or pass `build_number:`. |
| *…is inside an iCloud Drive-synced folder…* or Xcode *Exited with status code 255* / *resource fork, Finder information, or similar detritus not allowed* | iCloud Drive ("Desktop & Documents" sync) adds file attributes that break code signing. Keep the project outside iCloud, e.g. `~/Personal/Github/nexora-app`. |
| *fastlane requires your locale to be set to UTF-8* | Set `LC_ALL` and `LANG` (setup step 1). |
| Tests or coverage fail | Fix them first; the release stops on purpose. `skip_checks:true` exists for emergencies. |
| *Missing Compliance* on the build in App Store Connect | Answer the encryption question for that build, or add `ITSAppUsesNonExemptEncryption` (see above). |
