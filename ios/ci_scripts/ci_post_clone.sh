#!/bin/zsh

# Xcode Cloud's macOS image has no Flutter SDK, so every build needs this
# before Xcode can build ios/Runner.xcworkspace. Xcode Cloud runs this
# automatically after cloning the repo, for every workflow that uses it — see
# docs/xcode-cloud.md for the one-time workflow setup (branch trigger,
# TestFlight distribution), which has to be done in Xcode/App Store Connect
# and isn't something a script can do.
#
# A non-zero exit here fails the whole build before Xcode archives anything,
# so the analyze/coverage gate below doubles as a release gate, the same as
# `fastlane beta`'s "checks" step (see docs/testflight.md).

set -e
set -o pipefail

cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "Installing Flutter (stable channel)…"
git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"
flutter --version
flutter precache --ios

# TestFlight refuses a build number it's already seen for this bundle ID, so
# every Xcode Cloud build needs a new one. The Xcode project's
# CURRENT_PROJECT_VERSION is already "$(FLUTTER_BUILD_NUMBER)" (see
# ios/Runner.xcodeproj), which Flutter writes into
# ios/Flutter/Generated.xcconfig from pubspec.yaml's version suffix — so
# rewriting that suffix here is all that's needed; nothing in the Xcode
# project itself has to change.
if [ -n "$CI_BUILD_NUMBER" ]; then
  sed -i '' -E "s/^(version: [0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+/\1+$CI_BUILD_NUMBER/" pubspec.yaml
fi

flutter pub get

echo "Running flutter analyze…"
flutter analyze

echo "Running the tests with the 95% coverage gate…"
dart run tool/coverage.dart

echo "Xcode Cloud post-clone checks passed."
