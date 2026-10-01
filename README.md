# DELvEK Theme + Custom Home Top Bar

This project builds an Objective-C iOS arm64 dynamic library for the DELvEK app.

## Features

- Default accent: `#34C759` (green)
- Runtime accent recoloring for the existing blue/cyan UI accents
- Settings footer entry: **Theme Manager**
- Native `UIColorWell` / color wheel
- HEX color entry and persistent save using `NSUserDefaults`
- Immediate accent refresh after saving
- Custom Home top bar: title on the left, Search / History / Download icons on the right
- Tapping Search expands a search field underneath the custom top bar
- Existing content below the top bar is left alone

## GitHub Actions

`.github/workflows/build-dylib.yml` builds an arm64 iOS dylib on `macos-latest` and uploads `DELvEKTheme-dylib.zip`.
