# UsageBar 0.2.0

The first public release of UsageBar.

UsageBar started from a simple need: I wanted to see how much of my AI usage allowance I had left without repeatedly opening account settings.

This first public version puts that information directly in the macOS menu bar.

It is also my first public software release, which makes this version a little special to me. I am glad to finally put something out there that other people might find useful.

## Included

- Native Swift and AppKit macOS app
- ChatGPT Codex usage monitoring
- Claude Desktop cached usage monitoring
- 5-hour and weekly ChatGPT gauges
- Click to switch between usage windows
- Remaining or used percentage display
- Automatic weekly display when the weekly allowance becomes the limiting factor
- Configurable gauge widths
- Monochrome, blue, and capacity-based color styles
- Automatic and manual refresh
- Mock mode for testing
- Stale-reading indication for Claude

## Please note

- ChatGPT values represent the Codex allowance, not every ChatGPT model or feature limit.
- Claude values come from Claude Desktop's local cache, which can update less frequently.
- Claude reset times are not available from that local cache.
- Launch at login is not implemented yet.

UsageBar is still a small early project, so feedback is very welcome.

If something looks wrong or is confusing, please open an issue and let me know.
