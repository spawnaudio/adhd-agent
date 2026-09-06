# Focus

A small macOS app to keep one task in view when other things pull your attention away.

## Use

1. Open `dist/Focus.app` after building.
2. Paste a Linear issue link, copied issue contents, or task text.
3. Write one small next action and choose **Start focus**.
4. Save distracting ideas in **Saved for later**.
5. Choose **Pause focus to continue** and confirm a break length, or end the session.

The app brings its focus window forward when a pause expires while it is running. The menu-bar icon lets you reopen the window. Tasks and saved ideas stay locally on your Mac across launches. Ending a session keeps them; saved ideas can be deleted individually.

This version does not fetch Linear issue details, use AI, monitor browsing, or block websites/apps. A pasted issue link provides an **Open issue in Linear** shortcut. Pauses are initiated by you.

## Build

Requires macOS 14 or later and a Swift 6 toolchain (Xcode or Command Line Tools). No third-party packages.

```sh
sh scripts/build-app.sh --simple
```

The resulting `dist/Focus.app` is ad-hoc signed for local use, not notarized for distribution. It is not installed automatically.

## Tests

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" swift test --disable-sandbox
```

## Layout

- `Sources/FocusApp`: native window, menu bar, and local persistence.
- `Sources/FocusCore`: focus session and pause state.
- `Tests/FocusCoreTests`: state and URL handling tests.
- `.agents-cli-spec.md`: current scope and limitations.

## Manual check

Launch the app; paste task text and a Linear issue URL; enter a next action; start focus; save an idea; confirm and resume a pause; then allow a pause to expire. Check that the window returns after expiry and after sleep. Quit/relaunch to verify restoration. Close the window and reopen from the menu bar. End the session and verify the task and ideas remain.

The interface uses Apple's [SwiftUI window and menu-bar APIs](https://developer.apple.com/documentation/swiftui/menubarextra).
