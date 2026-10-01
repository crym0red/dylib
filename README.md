# DELvEK Theme dylib

Standalone Objective-C/UIKit iOS dylib for the DELvEK/KayakTime UI customization project.

## Features

- Default accent: `#34C759` (Apple green).
- Recolors UIKit elements that are already using a blue accent.
- Adds a Theme Manager to the detected settings table.
- Native `UIColorWell` / `UIColorPickerViewController` color wheel.
- HEX color entry and persistent selection via `NSUserDefaults`.
- Does not replace the application's existing screens or content.

## GitHub Actions

`.github/workflows/build-dylib.yml` builds an arm64 iOS dylib on a macOS GitHub runner and uploads `DELvEKTheme-dylib.zip`.

The workflow uses the runner's installed stable Xcode rather than pinning a potentially unavailable Xcode version.

## Local build

```sh
make clean
make
```

Output:

```text
build/DELvEKTheme.dylib
```

This project only builds the component. Loading/injection and signing remain separate steps in the app's existing build/install process.
