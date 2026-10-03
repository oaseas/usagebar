# Releasing UsageBar

The repository includes two workflows:

- `macOS CI` validates every main-branch update and builds an ad-hoc signed Universal release candidate.
- `Publish macOS Release` is triggered by a `release/vX.Y.Z` branch and publishes a GitHub Release after rebuilding and validating the app.

## Release validation

Every release build must:

- pass `swift test`
- contain both `arm64` and `x86_64`
- target macOS 13 or later
- include `AppIcon.icns`
- include `UsageBarLogo.png`
- pass `codesign --verify`
- include a SHA-256 checksum

## Signing

Without release secrets, the workflow creates an ad-hoc signed build and labels the release accordingly.

For Developer ID signing, configure these repository secrets:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_SIGN_IDENTITY`

For Apple notarization, also configure:

- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_PASSWORD`

If all signing and notarization values are available, the workflow imports the certificate into a temporary keychain, signs with the hardened runtime, submits the Universal ZIP to Apple, staples the ticket, validates with Gatekeeper, recreates the ZIP, and then publishes it.

Signing certificates, passwords, Apple credentials, account files, and local provider data must never be committed to the repository.

## Manual checks before creating the release branch

1. Confirm the latest `macOS CI` run on `main` is green.
2. Review the README and release notes.
3. Confirm the version in build scripts and release notes is consistent.
4. Create `release/vX.Y.Z` from the tested main commit.

The release workflow creates the Git tag and GitHub Release only after its own tests and Universal build checks pass.
