# UsageBar

A lightweight native macOS menu bar gauge for keeping an eye on your AI usage limits.

UsageBar keeps your current allowance visible in the menu bar, so you do not have to keep opening account settings just to see how much you have left. It currently supports ChatGPT/Codex and Claude, with room to add more AI services over time.

It is native, lightweight, local-first, and intentionally simple.

## Why I made this

I made UsageBar because not everyone has unlimited resources.

Some of us genuinely need to keep an eye on our remaining usage, especially before starting a long coding session, research task, or other work that can consume a meaningful part of the available allowance.

Opening settings repeatedly just to check a percentage started to feel unnecessary. I wanted something quieter and simpler: a small gauge that stays visible when I need it and gets out of the way when I do not.

Heavy users are very much welcome too. I actually like the idea that something made to solve a small personal annoyance might also be useful to people who use these tools all day.

UsageBar is also my first public software project. I have had a GitHub account for a while, but this is the first time I am releasing something I made for anyone to use. I am genuinely glad to finally contribute something back, even if it started as a small tool I wanted for myself.

If it happens to be useful to you too, that already makes publishing it worthwhile.

## What it does

UsageBar puts a horizontal usage gauge directly in the macOS menu bar.

For ChatGPT, the default view shows the current 5-hour Codex allowance. Left-click the gauge to switch between the 5-hour and weekly views.

If the weekly allowance reaches zero while the current 5-hour window still has capacity, UsageBar automatically shows the weekly limit so the menu bar reflects the limit that is actually blocking you.

You can also switch the app to Claude and view the latest usage percentages stored locally by Claude Desktop.

## Features

- Native Swift and AppKit macOS app
- No Electron
- No third-party dependencies
- Wide configurable menu bar gauge
- ChatGPT and Claude support
- 5-hour and weekly ChatGPT views
- Left-click to switch between ChatGPT usage windows
- Remaining or used percentage display
- 120, 180, 260, and 320 point gauge widths
- Monochrome, blue, or capacity-based color styles
- Automatic and manual refresh
- Refresh intervals from 1 second to 15 minutes
- Small service badges for ChatGPT and Claude
- Mock mode for testing
- No Dock icon

## Where the numbers come from

UsageBar does not estimate your allowance from message counts.

### ChatGPT

UsageBar reads the Codex allowance from the local Codex app server associated with the ChatGPT account already signed in on your Mac.

It displays the 5-hour and weekly Codex windows returned for that account, including reset times when available.

**Important:** this is the Codex allowance. It is not a claim to measure every ChatGPT model, feature, or message cap.

### Claude

UsageBar reads the percentages Claude Desktop stores locally in its usage history file.

Claude's local data is cached rather than a live UsageBar network request. It can update less frequently than the ChatGPT reading, and reset times are not stored in this file. UsageBar shows the sample time and marks old readings as stale instead of inventing missing information.

The Claude cache format is not a public Anthropic API and may change in a future Claude Desktop update.

More technical detail is available in [docs/TECHNICAL.md](docs/TECHNICAL.md).

## Installation

Public builds will be available from the GitHub Releases page.

1. Download the latest `UsageBar` release.
2. Move `UsageBar.app` to your Applications folder.
3. Open UsageBar.
4. Keep ChatGPT/Codex or Claude signed in normally, depending on which service you want to monitor.

No separate UsageBar account is required.

### macOS security

For a normal public release, the app should be signed with a Developer ID certificate and notarized by Apple.

Development and early test builds may use ad-hoc signing. macOS can show additional security warnings for those builds.

See [docs/RELEASING.md](docs/RELEASING.md) for the release process.

## How to use it

Once UsageBar is running, the gauge appears directly in the menu bar.

Example:

```text
G  5H R  ████████████████░░░░  78%
```

Left-click to switch to the weekly view:

```text
G  7D R  █████░░░░░░░░░░░░░░░  25%
```

Right-click the gauge to access:

- AI service
- Gauge width
- Remaining or used display
- Gauge color
- Data source
- Refresh interval
- Refresh now
- About
- Quit

## Privacy

UsageBar is designed as a local utility.

It does not operate a UsageBar server, does not need your ChatGPT or Claude password, and does not read the contents of your conversations.

For ChatGPT, authentication remains with Codex. For Claude, UsageBar reads only the local usage history needed for the gauge.

See [PRIVACY.md](PRIVACY.md) for the full explanation.

## Current limitations

UsageBar is still a small early project.

- ChatGPT values currently represent the Codex allowance, not every ChatGPT usage limit.
- Claude values come from an undocumented local cache and can become stale.
- Claude reset times are not available from that cache.
- Claude histories containing multiple organization IDs are currently treated as ambiguous instead of guessing which account to show.
- Launch at login is shown as a placeholder and is not implemented yet.
- Menu bar placement is controlled by macOS. A very wide gauge may be hidden by long app menus or a display notch.

## Building from source

UsageBar requires macOS 13 or later and Swift 6.

For a normal local build:

```sh
./scripts/build-app.sh
open dist/UsageBar.app
```

Run the logic tests with:

```sh
swift test
```

A release helper for a Universal macOS build is included in `scripts/build-release.sh`.

## Contributing

UsageBar is my first public software project, so I am learning the open-source side of things as I go.

Suggestions, bug reports, fixes, and improvements are very welcome. You do not need to be a developer to contribute.

One principle I would like to keep as the project grows: UsageBar should remain easy to understand for people who do not consider themselves technical.

That matters more to me than adding features simply because they are possible.

See [CONTRIBUTING.md](CONTRIBUTING.md) if you would like to help.

## Disclaimer

UsageBar is an independent open-source project. It is not affiliated with, endorsed by, or sponsored by OpenAI or Anthropic.

ChatGPT and OpenAI are trademarks of OpenAI. Claude and Anthropic are trademarks of Anthropic.

## License

UsageBar is available under the MIT License. See [LICENSE](LICENSE).
