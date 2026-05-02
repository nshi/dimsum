# Dimsum

Dimsum is a minimalist macOS menu bar utility designed to eliminate the cognitive load of
tracking active focus in cluttered workspaces. By automatically dimming background windows,
it provides an immediate visual feedback loop that confirms exatly where your keystrokes are
going. Keep your attention on what matters.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ with Swift 5.9+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Build

```bash
# Generate the Xcode project
xcodegen generate

# Build from command line
xcodebuild -scheme Dimsum -configuration Debug build

# Or open in Xcode
open Dimsum.xcodeproj
```

## Run

1. Build and run from Xcode (Cmd+R), or launch the built `.app` from DerivedData.
2. A menu bar icon (half-filled circle) appears. There is no Dock icon.
3. macOS prompts for **Accessibility permission** — grant it in System Settings > Privacy & Security > Accessibility.
4. Restart the app after granting permission. Dimming activates automatically.

## Usage

Click the menu bar icon to open the popover:

- **Enable Dimming** — master on/off toggle. When off, all overlays are removed.
- **Dimming Intensity** — slider from 0 (no dim) to 1 (fully black). Changes apply in real time.
- **Start on Login** — registers the app as a login item so it launches automatically. Requires the app to be in `/Applications`.

The app dims all unfocused windows across all displays. Switching focus (click, Cmd+Tab) animates overlays smoothly. Full-screen apps and Space transitions are handled automatically.

## Release Build

```bash
# Generate project (if not already done)
xcodegen generate

# Archive
xcodebuild archive \
  -scheme Dimsum \
  -configuration Release \
  -archivePath build/Dimsum.xcarchive

# Export the .app from the archive
xcodebuild -exportArchive \
  -archivePath build/Dimsum.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/release

# The built app is at build/release/Dimsum.app
```

To install, drag `build/release/Dimsum.app` into `/Applications`.

> **Note:** The app is ad-hoc signed. macOS Gatekeeper may block it on first launch — right-click the app and choose "Open" to bypass.

## Tests

```bash
xcodebuild test -scheme Dimsum -destination 'platform=macOS'
```
