# Launch

Launch is a small macOS launcher and bookmark bar for the places you want to go and the things you want to return to.

It lives beneath the macOS menu bar. The main bar contains app shortcuts and user-created categories such as READ, WATCH, or COOK. Each category opens a dropdown containing application shortcuts and saved links.

## Current capabilities

- Launch macOS applications from the main bar or a category.
- Create, rename, remove, and reorder categories.
- Drag URLs onto a category or its dropdown to save them.
- Fetch page titles and show favicons for saved links.
- Mark items as favourites and sort favourites before newer items.
- Edit bookmark titles in place.
- Reorder items within a dropdown.
- Remove bookmarks and app shortcuts without deleting installed applications.
- Persist categories, bookmarks, and app shortcuts locally.
- Press Option-Space to focus Launch, then use the arrow keys, Space, Enter, and Escape to navigate without a mouse.

Launch stores category data in `~/Library/Application Support/GOTO/sections.json` and main-bar app shortcuts in UserDefaults.

## Building

```sh
swift build
```

The executable is built as a native SwiftUI and AppKit macOS application.

The bundle identifier, storage directory, and preference keys retain the GOTO identity so existing libraries and shortcuts carry over.

Build a runnable app with `Scripts/build-app.sh`, then open `.build/Launch.app`.
