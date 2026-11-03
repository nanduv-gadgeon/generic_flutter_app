# Branding source files

Source art for each customer. **Not bundled in the app**: Flutter only ships what is under `assets/` and listed in `pubspec.yaml`.

| File | Use |
| --- | --- |
| `<customer>/app_icon.svg` | Master artwork for the app icon (1024 × 1024) |

The app icon and the native launch screen live in the Android and iOS projects, not in Flutter assets. They will be generated per customer flavor from these masters, using a 1024 × 1024 PNG export, when the customer flavors are set up.

In-app logos are in `assets/brand/<customer>/`.
