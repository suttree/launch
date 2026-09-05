# Menu

A time-only clock in the top-right corner of the primary display. Menu runs independently of Launch and has no Dock icon or menu-bar item.

The clock uses 24-hour time, black 13-point numerals without a shadow. It stays above app windows and follows Spaces, including full-screen apps. The clock is centred in the macOS menu bar row. When the menu bar appears, it covers Menu so the system clock takes over. Right-click the time to quit.

## Build and run

```sh
Scripts/build-app.sh
open .build/Menu.app
```

Run these commands from this directory. Requires macOS 13 or later and Xcode.

To start Menu at login, add the built app in System Settings > General > Login Items. Keep the app at that path, or copy it to Applications first.

Menu updates at each minute and after wake or display changes. It uses no network access or screen-recording permission. Text colour does not sample the wallpaper. Media controls are a possible later addition.
