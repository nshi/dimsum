## Build

```bash
xcodegen generate          # regenerate Dimsum.xcodeproj from project.yml
xcodebuild -scheme Dimsum -configuration Debug build
xcodebuild test -scheme Dimsum -destination 'platform=macOS'
```

## Active Technologies
- Swift 5.9+ + ApplicationServices (AXObserver/AXUIElement), CoreGraphics (CGWindowList), AppKit (NSWindow/NSStatusItem/NSPopover), SwiftUI, ServiceManagement (SMAppService)
- UserDefaults (preferences only)
- Swift 5.9+ + AppKit (NSWindow, NSScreen, NSStatusItem), CoreGraphics (CGWindowListCopyWindowInfo), ApplicationServices (AXObserver/AXUIElement), SwiftUI, ServiceManagement

## Problem Solving
- For event-driven bugs, trace the full notification/callback flow to find missing events rather than papering over with retries or timers.
- Prefer a single precise fix over belt-and-suspenders. If one AX notification covers the case, don't also add a workspace observer as a "safety net."
- When adding notifications or observers, coalesce rapid-fire callbacks to avoid redundant expensive work (e.g., CGWindowListCopyWindowInfo).
- Always evaluate whether new code can be combined with existing patterns before adding parallel mechanisms.
- Run `/simplify` after code changes to review for reuse, quality, and efficiency.

## Testing
- All dimming behavior lives in `DimmingController`, and every user-facing flow has a test in `DimmingControllerTests` or `AppFlowTests` (built on `DimmingHarness`): launch with and without permission, losing and regaining permission, the Enable Dimming switch, intensity, appearance, focus changes, Space changes, screen changes and wake. A new flow or a change to one gets a test there.
- Fix a bug by first writing a test that fails because of it, through the same path a user takes. Then confirm the test passes with the fix and fails without it.
- Tests use the real `PreferencesManager` and real overlay windows. Fake only what needs the system: the Accessibility tracker, the clock (`ManualScheduler`) and the notification centers. UI tests press the real SwiftUI controls through the accessibility tree, which also checks that VoiceOver can read them.
- `@Published` sends a new value before the property is updated. Outside SwiftUI views, observe preferences through `PreferencesManager`'s `...DidChange` publishers, which fire after the value is stored.
- Unit tests passing is not the same as the app working. Before a release, run the built app and go through the flows above.
