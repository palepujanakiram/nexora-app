# NexoraApp

Flutter app (iOS, Android, web) that parses option trade signals and places orders on Zerodha, Upstox and Groww accounts. See [README.md](README.md) for what it does and how the code is laid out.

## Architecture

- Clean Architecture. Each screen lives in `lib/screens/<screen>/` with `view/`, `viewmodel/`, `model/` and `usecase/` folders. Code shared by screens lives in `lib/common/`.
- Domain code (`lib/common/domain/`) is pure Dart: no Flutter, HTTP or storage imports.
- Dependencies are wired in `lib/common/di/injector.dart` (`get_it`, accessed as `sl`).
- Account keys, secrets and tokens are stored only through `flutter_secure_storage`, never in shared preferences or logs.
- New accounts default to paper mode. Never place a real order from tests or tooling.

## Code coverage is mandatory

Every change must come with tests. **Line coverage of `lib/` must stay at or above 95%**, and CI fails any pull request below that.

- Add or update tests in the same change as the code. A new file under `lib/` needs tests that execute it; code that no test imports counts as 0%.
- Check before you finish:
  ```bash
  dart run tool/coverage.dart
  ```
  It runs `flutter test --coverage`, counts every file under `lib/` (including ones no test imports), lists files below 95% and fails if the total is below 95%.
- Aim for every file to be at or above 95%, not just the total. Don't add files to an exclusion list or lower the threshold to get a change through; if code is genuinely untestable, restructure it so the logic can be tested and say so in the PR.
- Test behaviour, not just lines: assert on results, state changes and error messages, including failure paths.
- The Cloudflare Worker in `proxy/cloudflare-worker` has the same 95% rule: `npm run coverage` in that folder.

## Testing conventions

- Tests mirror `lib/` under `test/` (e.g. `lib/screens/signal/usecase/x.dart` → `test/screens/signal/usecase/x_test.dart`).
- Use the fakes in `test/fakes.dart` for repositories; extend them there rather than duplicating.
- Broker and proxy HTTP calls are tested with `package:http/testing.dart`'s `MockClient`. Tests never call real broker APIs or the network.
- Widget tests that build a screen register what the screen pulls from `sl` (reset it in `setUp`) and use fakes for repositories.
- Platform plugins (secure storage, shared preferences, url_launcher, clipboard) are faked through their test APIs or mock method channels.

## Commands

```bash
flutter pub get
flutter analyze                 # must report no issues
dart run tool/coverage.dart     # all tests + 95% coverage gate
cd proxy/cloudflare-worker && npm run coverage
```
