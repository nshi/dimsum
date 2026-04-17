## Build

```bash
xcodegen generate          # regenerate Dimsum.xcodeproj from project.yml
xcodebuild -scheme Dimsum -configuration Debug build
xcodebuild test -scheme Dimsum -destination 'platform=macOS'
```

## Active Technologies
- Swift 5.9+ + ApplicationServices (AXObserver/AXUIElement), CoreGraphics (CGWindowList), AppKit (NSWindow/NSStatusItem/NSPopover), SwiftUI, ServiceManagement (SMAppService)
- UserDefaults (preferences only)
- Swift 5.9+ + AppKit (NSWindow, NSScreen, NSStatusItem), CoreGraphics (CGWindowListCopyWindowInfo), ApplicationServices (AXObserver/AXUIElement), SwiftUI, ServiceManagemen
