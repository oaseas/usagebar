# UsageBar 0.4.0

Adds the display variations developed after 0.3.0.

## New display options

- At gauge widths of 260 pt and above, cycle through 5-hour, weekly, side-by-side gauges, and a 5-hour reset countdown.
- Select the current layout directly from the View menu.
- Save a startup layout through Default view; clicking through layouts does not change that default.
- Wide layouts fall back to the 5-hour view at narrow widths.
- The exhausted weekly allowance continues to take priority.

The countdown redraws locally once per second only while visible. Provider polling and caching remain unchanged.

## Install

Download the Universal macOS ZIP, quit UsageBar, and replace UsageBar.app in Applications. Existing preferences are retained. macOS 13 or later is required. The workflow appends the signing status of this release.
