# Changelog

Notable changes to UsageBar will be documented here.

## 0.3.0

First public release.

### Added

- Working Launch at login support using macOS Service Management
- About panel logo and creator credit for oaseas with GitHub and X links
- Optional private local status/control bridge for trusted same-user companion dashboards
- Public companion bridge documentation and command validation
- Universal Intel and Apple Silicon release packaging
- Release checksums and CI release artifact validation

### Improved

- Reuses one persistent Codex helper
- Caches ordinary Codex allowance reads for 30 seconds
- Keeps display refresh separate from actual provider fetching
- Prevents overlapping refresh work
- Retains exponential retry backoff after provider errors
- Documents Codex allowance scope and optional Claude cache behavior more explicitly
- Preserves macOS 13 compatibility

### Known limitations

- ChatGPT monitoring reflects Codex allowance only.
- Claude reset times are not available from the local cache.
- Claude's local cache format is undocumented and may change.
- Claude histories with multiple organization IDs are rejected as ambiguous.
- Ad-hoc releases can require manual approval in macOS Privacy & Security if Developer ID signing and notarization are unavailable.

## 0.2.0

Private development milestone used to establish the initial public repository, CI, Universal build tooling, app icon, privacy documentation, and provider tests.
