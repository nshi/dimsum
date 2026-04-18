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
