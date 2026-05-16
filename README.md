# Dimsum

Dimsum is a minimalist macOS menu bar utility designed to eliminate the cognitive load of
tracking active focus in cluttered workspaces. By automatically dimming background windows,
it provides an immediate visual feedback loop that confirms exatly where your keystrokes are
going. Keep your attention on what matters.

<img width="640" height="471" alt="output-640" src="https://github.com/user-attachments/assets/3ff8f4fe-3a47-4f7f-a130-ceb18f4944ce" />

## Requirements

- macOS 13 (Ventura) or later

## Install

Download the latest release straight to `/Applications` from the terminal. Fetching via `curl` avoids the `com.apple.quarantine` xattr that browsers attach, so Gatekeeper won't block the unsigned app on launch:

```bash
curl -L https://github.com/nshi/dimsum/releases/latest/download/Dimsum.zip -o /tmp/Dimsum.zip && unzip -o /tmp/Dimsum.zip -d /Applications && rm /tmp/Dimsum.zip && open /Applications/Dimsum.app
```

On first launch:

1. A menu bar icon (a small dim sum steamer basket) appears. There is no Dock icon.
2. macOS prompts for **Accessibility permission** — grant it in System Settings > Privacy & Security > Accessibility.
3. Restart the app after granting permission. Dimming activates automatically.

## Usage

Click the menu bar icon to open the popover:

- **Enable Dimming** — master on/off toggle. When off, all overlays are removed.
- **Dimming Intensity** — slider from 0 (no dim) to 1 (fully black). Changes apply in real time.
- **Start on Login** — registers the app as a login item so it launches automatically. Requires the app to be in `/Applications`.

The app dims all unfocused windows across all displays. Switching focus (click, Cmd+Tab) animates overlays smoothly. Full-screen apps and Space transitions are handled automatically.

## Development

### Requirements

- Xcode 15+ with Swift 5.9+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

### Build

```bash
# Generate the Xcode project
xcodegen generate

# Build from command line
xcodebuild -scheme Dimsum -configuration Debug build

# Or open in Xcode
open Dimsum.xcodeproj
```

### Tests

```bash
xcodebuild test -scheme Dimsum -destination 'platform=macOS'
```

### Release Build

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

> **Note:** The app is ad-hoc signed. If you copied the `.app` from a browser download or another machine, macOS Gatekeeper may block it on first launch — either right-click the app and choose "Open" to bypass, or strip the quarantine attribute with `xattr -dr com.apple.quarantine /Applications/Dimsum.app`.
