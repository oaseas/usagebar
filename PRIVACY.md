# Privacy

UsageBar is designed to work locally on your Mac.

## What UsageBar reads

Depending on the selected service, UsageBar may read:

- Remaining and used usage percentages
- Usage window information
- Reset times when the provider exposes them
- The timestamp of the latest available usage sample

For ChatGPT, usage information is requested from the locally running Codex app server.

For Claude, usage information is read from Claude Desktop's local `plan-usage-history.json` file.

## What UsageBar does not read

UsageBar does not need to read:

- Your ChatGPT conversations
- Your Claude conversations
- Your prompts
- Your generated content
- Your work documents
- Browser cookies
- Authentication tokens
- Passwords

## What UsageBar does not do

UsageBar does not:

- Sell your data
- Upload your usage history to a UsageBar server
- Include advertising trackers
- Make AI model calls to obtain the displayed allowance
- Ask you to send your ChatGPT or Claude password to the developer
- Store copies of your conversation history

No separate UsageBar account is required.

## ChatGPT authentication

UsageBar starts one local Codex app-server helper and asks it for rate-limit information. Codex remains responsible for its own authentication.

UsageBar does not parse or copy Codex authentication files.

## Claude local cache

Claude support is optional.

UsageBar reads only the local usage history file needed to obtain Claude's cached usage percentages. The file is read-only from UsageBar's perspective.

The Claude file format is not a public Anthropic API and may change. Claude reset times are not available from this file.

## Optional local companion bridge

UsageBar can write non-sensitive status information to its own Application Support folder and accept a small whitelist of commands from a trusted local companion running as the same macOS user.

The bridge does not publish a web server, session token, private dashboard, prompts, conversations, or provider credentials.

See [docs/COMPANION_BRIDGE.md](docs/COMPANION_BRIDGE.md) for the public schema and validation rules.

## Analytics

UsageBar does not include third-party analytics or telemetry.

If this changes in a future release, this document should be updated clearly before that release.

## Reporting problems safely

Please do not include passwords, tokens, cookies, account files, local usage-history files, or private companion dashboard files when opening an issue.

A screenshot of the gauge and the exact visible error message are usually enough to start troubleshooting.
