# Store Release Status

Which platforms are published, and where. `just release-check` reads the table
below to decide whose store screenshots under `shotkit/screenshots/store/`
need to be refreshed before the next tag.

| Platform | Store | Status | Date |
|----------|-------|--------|------|
| Android | Google Play Store | Released | 2026-04-01 |
| iOS | Apple App Store | Released | 2026-06-11 |
| macOS | Mac App Store | Released | 2026-06-11 |

Windows and Linux are not shipped yet, blocked on the markdown editor: it
renders in a WebView and `webview_flutter` has no implementation for either
platform. The scaffolding stays in the tree for when that is solved. Desktop
users there use the [web frontend](https://github.com/hudikhq/hoodik).
