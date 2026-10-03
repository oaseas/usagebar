# Security

UsageBar is a local menu bar utility and should not require users to share credentials with the project.

## Please do not post secrets in public issues

Do not attach or paste:

- Passwords
- API keys
- Authentication tokens
- Browser cookies
- Codex authentication files
- Claude account files
- `plan-usage-history.json`
- Private companion dashboard files or session tokens

For normal bug reports, the UsageBar version, macOS version, service name, visible error message, and a screenshot are usually enough.

## Local companion bridge

UsageBar's optional companion bridge is file-based and restricted to its Application Support directory for the current user.

Commands are size-limited and must match a small whitelist of keys and actions. UsageBar itself does not expose an HTTP server or a network control endpoint.

Any external companion dashboard is responsible for its own localhost binding, authentication, origin validation, and secure session handling.

## Reporting a security issue

Until a dedicated private security contact is configured, please avoid publishing credential material in a GitHub issue. If a report can be demonstrated without sensitive data, open an issue describing the affected component and request a private follow-up channel.
