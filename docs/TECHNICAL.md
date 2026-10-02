# Technical notes

This document explains where UsageBar gets its data and what the current implementation deliberately does not do.

## Architecture

Every provider maps its source into a `UsageSnapshot` containing:

- 5-hour remaining fraction
- Weekly remaining fraction
- Reset dates when available
- Sample or fetch time
- Human-readable source label
- Cache state

Missing data is treated as unavailable. UsageBar does not invent a percentage or silently replace a failed live reading with mock data.

## ChatGPT provider

`CodexUsageProvider` starts one persistent local `codex app-server` process and completes the normal initialize handshake.

It requests:

```text
account/rateLimits/read
```

UsageBar selects the `codex` rate-limit bucket and currently expects:

- a 300-minute window for the 5-hour allowance
- a 10080-minute window for the weekly allowance

`usedPercent` is converted into a remaining percentage, and `resetsAt` is converted from its Unix timestamp into a local date.

UsageBar does not directly read or store Codex tokens, browser cookies, or passwords.

Executable discovery checks:

1. `USAGEBAR_CODEX_PATH`, when explicitly supplied by the user
2. The Codex helper bundled with ChatGPT
3. The Codex app
4. Apple Silicon Homebrew
5. Intel Homebrew

If no usable local helper exists, the app reports the problem instead of displaying demo data as though it were live.

### Scope of the ChatGPT number

The `codex` bucket is a Codex allowance. It should not be described as a universal ChatGPT quota.

Other ChatGPT models and features can have different or additional usage limits.

## Claude provider

`ClaudeUsageProvider` reads:

```text
~/Library/Application Support/Claude/plan-usage-history.json
```

The path is resolved from the current user's home directory. No machine-specific username is stored in the source.

The current decoder accepts version 2 and maps:

- `fh` to 5-hour utilization
- `sd` to weekly utilization
- `t` to the sample timestamp in milliseconds

Utilization is converted from used percentage to remaining percentage.

The provider does not fabricate reset times because this local file does not contain them.

The file format is not a public Anthropic API. UsageBar therefore fails clearly on unknown versions, invalid values, missing windows, or ambiguous histories containing multiple organization IDs.

The decoded snapshot is cached until the file modification time changes, so frequent menu refreshes do not repeatedly parse an unchanged history file.

## Refresh behavior

Refresh requests are asynchronous and ordinary polling does not overlap.

The Codex provider keeps a single local helper process alive rather than creating a new process on every refresh. Repeated failures trigger exponential retry backoff up to 60 seconds.

When UsageBar switches away from the live ChatGPT provider, the Codex helper is disconnected so it does not remain running unnecessarily.

Claude reads are local. If the usage-history file has not changed, the last decoded snapshot is reused.

## Testing

Logic tests currently cover:

- Automatic weekly selection when the weekly allowance is exhausted
- Safe percentage normalization
- Remaining versus used calculations
- Codex bucket and window mapping
- Missing Codex window rejection
- Claude cache mapping and timestamp handling
- Claude ambiguous organization rejection
- Claude missing-data rejection

The live check commands are read-only with respect to AI usage and do not start an AI prompt:

```sh
dist/UsageBar.app/Contents/MacOS/UsageBar --check-live
dist/UsageBar.app/Contents/MacOS/UsageBar --check-claude
```

Visual testing on Intel and Apple Silicon Macs, including notched displays and light/dark appearances, is still recommended before each public release.
