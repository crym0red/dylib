# DELvEK Theme dylib

A small Objective-C/UIKit runtime customization dylib for the DELvEK/KayakTime UI.

## What it does

- Default accent is Apple green `#34C759`.
- Recolors UIKit elements that are already using the app's blue accent.
- Adds a **Theme Manager** control to the settings table footer.
- Theme Manager provides:
  - native iOS color wheel (`UIColorWell` / `UIColorPickerViewController`)
  - HEX entry
  - live preview
  - persistent theme color using `NSUserDefaults`
- Does not rebuild the app's existing content screens.
- Uses Objective-C runtime hooks on `UIViewController` lifecycle/layout methods.

## Build

Run on macOS with Xcode:

```sh
make
```

The output is:

```text
build/DELvEKTheme.dylib
```

GitHub Actions builds the same dylib and uploads it as `DELvEKTheme-dylib`.

## Integration

The dylib is intentionally built as a standalone native component. Your existing app/injection workflow can package and load it using the mechanism already used by your project. The dylib itself does not contain signing credentials or attempt to bypass code-signing controls.
