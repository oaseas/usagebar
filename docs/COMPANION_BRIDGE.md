# Optional local companion bridge

UsageBar includes a small file-based bridge for trusted companion tools running under the same macOS user account.

It does not include a dashboard server and it does not open a network port.

## Files

UsageBar uses its own Application Support directory:

```text
~/Library/Application Support/UsageBar/
```

The public bridge consists of:

- `status.json`, written by UsageBar
- `command.json`, optionally written by a trusted local companion and consumed by UsageBar

The directory is kept owner-only and UsageBar writes `status.json` with owner-only permissions.

## Status schema

The current status payload contains a version number, running state, process ID, heartbeat timestamp, provider readings, sanitized provider errors, and non-sensitive display settings.

It does not include prompts, conversations, authentication tokens, browser cookies, passwords, or account files.

## Command validation

UsageBar accepts only a small whitelist of command keys:

- `service`
- `width`
- `color`
- `showUsed`
- `interval`
- `mock`
- `startup`
- `action`

Accepted actions are currently:

- `refresh`
- `quit`

The command file must be a regular file, must remain below the size limit, must contain valid JSON, and must not contain unknown command keys.

Individual setting values are validated again by the app before they are applied.

## Companion dashboard security

A web-based companion is outside UsageBar itself.

If a companion dashboard exposes HTTP controls, it should:

- bind only to loopback unless the user deliberately chooses otherwise
- authenticate control requests
- validate the request origin for state-changing requests
- write only the documented command file and permitted keys
- never expose UsageBar provider credentials because UsageBar does not provide them

The private Endeavor dashboard is not part of this repository.
