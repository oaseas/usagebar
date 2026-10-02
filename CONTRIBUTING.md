# Contributing

Thanks for taking an interest in UsageBar.

UsageBar is my first public software project, so I am learning the open-source side of things as I go. Suggestions, bug reports, fixes, and improvements are very welcome.

You do not need to be a developer to contribute.

## Found a bug?

Please open an issue and include:

- Your macOS version
- Your Mac architecture, Intel or Apple Silicon
- Your UsageBar version
- Which service you were using, ChatGPT or Claude
- What you expected to happen
- What actually happened
- A screenshot if it helps explain the problem

Please do not include passwords, authentication tokens, browser cookies, account files, or local usage-history files.

## Have an idea?

Feature suggestions are welcome.

I would like UsageBar to remain simple, so not every idea will necessarily become a feature. Useful suggestions are still appreciated, especially when they make the app easier to understand or more reliable.

## Want to contribute code?

Feel free to open a pull request.

For larger changes, opening an issue first is helpful so we can discuss the idea before you spend too much time implementing it.

Before submitting a pull request:

```sh
swift test
./scripts/build-app.sh
```

Please keep new dependencies to a minimum. UsageBar currently has no third-party runtime dependencies, and keeping it lightweight is intentional.

## One principle

UsageBar should remain easy to understand for someone who does not consider themselves technical.

If a feature makes the app significantly more complicated, it should provide a meaningful benefit.
