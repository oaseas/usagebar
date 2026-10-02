# Changelog

Notable changes to UsageBar will be documented here.

## 0.2.0

First public release candidate.

### Added

- Native Swift and AppKit menu bar gauge
- ChatGPT Codex allowance monitoring through the local Codex app server
- Claude Desktop cached usage monitoring
- 5-hour and weekly usage views
- Left-click switching between usage windows
- Automatic weekly display when the weekly allowance is exhausted
- Remaining and used display modes
- Configurable gauge widths
- Monochrome, blue, and capacity-based color styles
- Configurable refresh intervals
- Manual refresh
- Mock scenarios for testing
- Stale-data indication for Claude
- Local reset-time display when available

### Known limitations

- ChatGPT monitoring currently reflects the Codex allowance only.
- Claude reset times are not available from the local cache.
- Claude's local cache format is undocumented and may change.
- Claude histories with multiple organization IDs are currently rejected as ambiguous.
- Launch at login is not implemented yet.
