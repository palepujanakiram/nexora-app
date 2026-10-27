fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios checks

```sh
[bundle exec] fastlane ios checks
```

Run the analyzer and the tests with the 95% coverage gate

### ios build

```sh
[bundle exec] fastlane ios build
```

Build a signed App Store .ipa without uploading it

Options: build_number:<n> (default: latest TestFlight build + 1), skip_checks:true

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build, sign and upload to TestFlight

Options: build_number:<n>, skip_checks:true, changelog:"…", groups:"Internal,QA", wait:true

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
