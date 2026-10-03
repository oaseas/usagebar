# UsageBar 0.3.0

The first public release of UsageBar.

UsageBar started from a simple need: I wanted to see how much of my AI usage allowance I had left without repeatedly opening account settings.

This release puts that information directly in the macOS menu bar and adds the pieces needed to make UsageBar useful as a small everyday utility.

It is also my first public software release, which makes this version a little special to me. I am glad to finally put something out there that other people might find useful.

## What's included

- Native Swift and AppKit macOS app
- Universal Intel and Apple Silicon build
- macOS 13 or later support
- ChatGPT Codex allowance monitoring
- Optional Claude Desktop cached usage monitoring
- 5-hour and weekly usage gauges
- Click to switch between usage windows
- Remaining or used percentage display
- Automatic weekly display when the weekly allowance becomes the limiting factor
- Configurable gauge widths and colors
- Working Launch at login support
- About logo and Made by oaseas credit
- Automatic and manual refresh
- Low-resource Codex caching and one persistent helper
- Optional private local status/control bridge for trusted same-user companion tools
- SHA-256 checksum alongside the download

## Install

1. Download `UsageBar-0.3.0-macos-universal.zip`.
2. Unzip it.
3. Move `UsageBar.app` to Applications.
4. Open UsageBar.

Claude is optional.

## Usage data notes

ChatGPT readings represent the **Codex allowance** exposed by the local Codex app server. They do not represent every ordinary ChatGPT model or feature limit.

Claude reads optional cached percentages from Claude Desktop. Claude reset times are unavailable from that local cache and are not fabricated.

UsageBar does not require a separate account and does not make AI model calls to obtain these readings.

## Signing

The GitHub release workflow appends the exact signing status for the downloadable build. If Developer ID credentials and Apple notarization credentials are available, the workflow uses them. Otherwise the release is clearly labeled as ad-hoc signed and not notarized.
