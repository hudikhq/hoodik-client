# App Store Screenshots

Generates store-ready screenshots with device frames and marketing text for iOS App Store and Google Play.

## Directory Structure

```
release/screenshots/
  generate.py              # The generator script
  README.md                # This file
  sources/
    iphone/                # Raw iPhone simulator screenshots (1206x2622)
    iphone-framed/         # iPhone screenshots with device mockup frame (1419x2796)
    ipad/                  # Raw iPad simulator screenshots (1640x2360)
    android/               # Raw Android emulator screenshots (1080x2400)
  output/                  # Generated store-ready images
    iphone_*.png           # 1290x2796 — iPhone 6.7" App Store
    ipad_*.png             # 2048x2732 — iPad 12.9" App Store
    android_*.png          # 1080x1920 — Android Phone Google Play
```

## Usage

```bash
# Install dependency (one time)
pip3 install Pillow

# Generate all screenshots
python3 release/screenshots/generate.py
```

Output goes to `release/screenshots/output/`.

## Updating Screenshots

### Replace a screenshot

1. Take a new simulator screenshot
2. Replace the matching file in `sources/iphone/` (raw) and `sources/iphone-framed/` (with device frame)
3. For iPad, replace in `sources/ipad/`
4. Re-run `python3 release/screenshots/generate.py`

### iPhone device frames

The iPhone screenshots use pre-made mockup frames (iPhone 15 Pro Black Titanium). To re-generate framed versions from raw screenshots, use a mockup tool like [MockUPhone](https://mockuphone.com) or [Shots.so](https://shots.so) — upload the raw PNGs from `sources/iphone/` and download the portrait-framed versions into `sources/iphone-framed/`.

### iPad device frames

iPad frames are drawn programmatically by the script (minimal space grey bezels with rounded corners). No external tool needed.

### Android device frames

Android (Pixel) frames are drawn programmatically by the script, similar to iPad. Source screenshots go in `sources/android/` as raw emulator captures (1080x2400). No external tool needed.

### Change marketing text

Edit the `IPHONE_SCREENSHOTS` and `IPAD_SCREENSHOTS` lists in `generate.py`. Each entry has:
- `file` — source filename (must exist in the sources directory)
- `headline` — large white text at top
- `subtitle` — smaller grey text below headline (use `\n` for line breaks)

## App Store Requirements

| Device | Dimensions | Required |
|--------|-----------|----------|
| iPhone 6.7" (15 Pro Max) | 1290 x 2796 | Yes |
| iPhone 6.5" (11 Pro Max) | 1242 x 2688 | Optional (auto-scaled from 6.7") |
| iPad 12.9" (Pro) | 2048 x 2732 | Yes (if app supports iPad) |
| Android Phone | 1080 x 1920 | Yes (Google Play, min 2 up to 8) |
