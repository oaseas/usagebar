# Releasing UsageBar

This document is for maintainers preparing a public macOS release.

## Release goals

A normal public binary should be:

- Built for both Apple Silicon and Intel Macs
- Signed with a Developer ID Application certificate
- Built with the hardened runtime
- Notarized by Apple
- Stapled with the notarization ticket
- Packaged without account files, credentials, or local usage data

## 1. Run the tests

```sh
swift test
```

## 2. Build the Universal app

```sh
./scripts/build-release.sh
```

Without a signing identity, the script creates an ad-hoc signed Universal build for testing.

For public distribution, provide a Developer ID identity:

```sh
USAGEBAR_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-release.sh
```

The script uses the permanent bundle identifier:

```text
io.github.oaseas.usagebar
```

## 3. Verify the build

```sh
lipo -archs dist/UsageBar.app/Contents/MacOS/UsageBar
codesign --verify --deep --strict --verbose=2 dist/UsageBar.app
spctl --assess --type execute --verbose=4 dist/UsageBar.app
```

The executable should contain both `arm64` and `x86_64` before public distribution.

## 4. Notarize

Apple notarization requires an Apple Developer Program account and a Developer ID Application certificate.

Store notarization credentials in the macOS keychain rather than in this repository:

```sh
xcrun notarytool store-credentials "usagebar-notary"
```

Then submit the packaged release:

```sh
xcrun notarytool submit dist/UsageBar-0.2.0-macos-universal.zip \
  --keychain-profile "usagebar-notary" \
  --wait
```

Staple the ticket to the app:

```sh
xcrun stapler staple dist/UsageBar.app
xcrun stapler validate dist/UsageBar.app
```

Recreate the ZIP after stapling so the downloadable copy contains the notarization ticket.

## 5. Final safety check

Before publishing, confirm that the release contains none of the following:

- `.env` files
- API keys
- Authentication tokens
- Browser cookies
- Codex auth files
- Claude usage-history files
- Developer signing certificates or private keys
- Personal absolute paths

## 6. GitHub release

Suggested first public tag:

```text
v0.2.0
```

Attach the notarized Universal ZIP and publish the release notes from `docs/RELEASE_NOTES_0.2.0.md`.
