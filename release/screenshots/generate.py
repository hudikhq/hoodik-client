#!/usr/bin/env python3
"""
Generate App Store / Play Store-ready screenshots with device frames.

iPhone:          Uses pre-made iPhone 15 Pro mockup frames (sources/iphone-framed/)
iPad:            Draws a clean iPad frame programmatically from raw screenshots
Android phone:   Draws a Pixel-style frame (canvas matches source dimensions)
Android tablet:  Draws a Pixel-style frame for 7" (1200x1920) and 10" (1600x2560)
Feature graphic: 1024x500 banner for Google Play

Output dimensions:
  - iPhone:          1284x2778 (6.5" display requirement)
  - iPad:            2048x2732 (13" display requirement)
  - macOS:           2880x1800
  - Android phone:   matches source (e.g. 1080x2400 for 9:20 screens)
  - Android 7" tab:  1200x1920
  - Android 10" tab: 1600x2560
  - Feature graphic:  1024x500

Usage:
    cd release/screenshots/
    python3 generate.py

    # Or from project root:
    python3 release/screenshots/generate.py

Prerequisites:
    pip3 install Pillow
"""

import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# ---------------------------------------------------------------------------
# Paths — all relative to this script's location
# ---------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).resolve().parent
SOURCES_DIR = SCRIPT_DIR / "sources"
OUTPUT_DIR = SCRIPT_DIR / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

IPHONE_RAW_DIR = SOURCES_DIR / "iphone"
IPHONE_FRAMED_DIR = SOURCES_DIR / "iphone-framed"
IPAD_RAW_DIR = SOURCES_DIR / "ipad"
ANDROID_RAW_DIR = SOURCES_DIR / "android"
ANDROID_TABLET_DIR = SOURCES_DIR / "android-tablet"
MACOS_RAW_DIR = SOURCES_DIR / "macos"

# ---------------------------------------------------------------------------
# Hoodik brand colors
# ---------------------------------------------------------------------------

BG_TOP = (30, 24, 22)
BG_BOTTOM = (18, 14, 13)
TEXT_WHITE = (240, 235, 230)
TEXT_DIM = (160, 148, 140)

# ---------------------------------------------------------------------------
# Screenshot definitions
#
# To update: replace source PNGs in sources/, keep the same filenames,
# and re-run this script.
# ---------------------------------------------------------------------------

IPHONE_SCREENSHOTS = [
    {
        "file": "01_files.png",
        "headline": "Your Files, Fully Encrypted",
        "subtitle": "Browse folders and thumbnails with\nend-to-end encryption on every file.",
    },
    {
        "file": "02_transfers.png",
        "headline": "Lightning-Fast Transfers",
        "subtitle": "Upload and download large files with\nreal-time speed and progress tracking.",
    },
    {
        "file": "03_preview.png",
        "headline": "Preview Without Compromise",
        "subtitle": "View images, videos, and documents\ndecrypted locally on your device.",
    },
    {
        "file": "04_actions.png",
        "headline": "Everything at Your Fingertips",
        "subtitle": "Preview, export, rename, share, and manage\nfiles with a single tap.",
    },
    {
        "file": "05_details.png",
        "headline": "Encryption You Can Verify",
        "subtitle": "See the cipher, hashes, and metadata\nfor every encrypted file.",
    },
    {
        "file": "06_sharing.png",
        "headline": "Share Securely with Anyone",
        "subtitle": "Create encrypted public links\nthat protect your file keys.",
    },
    {
        "file": "07_pin.png",
        "headline": "Protected by PIN & Biometrics",
        "subtitle": "Lock your vault with a PIN, Face ID,\nor fingerprint for quick secure access.",
    },
    {
        "file": "08_server.png",
        "headline": "Self-Hosted & Multi-Server",
        "subtitle": "Connect to your own Hoodik servers.\nYour data never touches third parties.",
    },
]

IPAD_SCREENSHOTS = [
    {
        "file": "01_files.png",
        "headline": "Your Files, Fully Encrypted",
        "subtitle": "Browse folders and thumbnails with\nend-to-end encryption on every file.",
    },
    {
        "file": "02_transfers.png",
        "headline": "Lightning-Fast Transfers",
        "subtitle": "Upload and download large files with\nreal-time speed and progress tracking.",
    },
    {
        "file": "03_preview.png",
        "headline": "Preview Without Compromise",
        "subtitle": "View images, videos, and documents\ndecrypted locally on your device.",
    },
    {
        "file": "04_actions.png",
        "headline": "Everything at Your Fingertips",
        "subtitle": "Preview, export, rename, share, and manage\nfiles with a single tap.",
    },
    {
        "file": "05_details.png",
        "headline": "Encryption You Can Verify",
        "subtitle": "See the cipher, hashes, and metadata\nfor every encrypted file.",
    },
    {
        "file": "06_sharing.png",
        "headline": "Share Securely with Anyone",
        "subtitle": "Create encrypted public links\nthat protect your file keys.",
    },
    {
        "file": "07_pin.png",
        "headline": "Protected by PIN & Biometrics",
        "subtitle": "Lock your vault with a PIN, Face ID,\nor fingerprint for quick secure access.",
    },
    {
        "file": "08_server.png",
        "headline": "Self-Hosted & Multi-Server",
        "subtitle": "Connect to your own Hoodik servers.\nYour data never touches third parties.",
    },
]

ANDROID_SCREENSHOTS = [
    {
        "file": "01_files.png",
        "headline": "Your Files, Fully Encrypted",
        "subtitle": "Browse folders and thumbnails with\nend-to-end encryption on every file.",
    },
    {
        "file": "02_transfers.png",
        "headline": "Lightning-Fast Transfers",
        "subtitle": "Upload and download large files with\nreal-time speed and progress tracking.",
    },
    {
        "file": "03_preview.png",
        "headline": "Preview Without Compromise",
        "subtitle": "View images, videos, and documents\ndecrypted locally on your device.",
    },
    {
        "file": "04_actions.png",
        "headline": "Everything at Your Fingertips",
        "subtitle": "Preview, export, rename, share, and manage\nfiles with a single tap.",
    },
    {
        "file": "05_details.png",
        "headline": "Encryption You Can Verify",
        "subtitle": "See the cipher, hashes, and metadata\nfor every encrypted file.",
    },
    {
        "file": "06_sharing.png",
        "headline": "Share Securely with Anyone",
        "subtitle": "Create encrypted public links\nthat protect your file keys.",
    },
    {
        "file": "07_pin.png",
        "headline": "Protected by PIN & Biometrics",
        "subtitle": "Lock your vault with a PIN, Face ID,\nor fingerprint for quick secure access.",
    },
    {
        "file": "08_server.png",
        "headline": "Self-Hosted & Multi-Server",
        "subtitle": "Connect to your own Hoodik servers.\nYour data never touches third parties.",
    },
]

ANDROID_TABLET_SCREENSHOTS = [
    {
        "file": "01_files.png",
        "headline": "Your Files, Fully Encrypted",
        "subtitle": "Browse folders and thumbnails with\nend-to-end encryption on every file.",
    },
    {
        "file": "02_transfers.png",
        "headline": "Lightning-Fast Transfers",
        "subtitle": "Upload and download large files with\nreal-time speed and progress tracking.",
    },
    {
        "file": "03_preview.png",
        "headline": "Preview Without Compromise",
        "subtitle": "View images, videos, and documents\ndecrypted locally on your device.",
    },
    {
        "file": "04_actions.png",
        "headline": "Everything at Your Fingertips",
        "subtitle": "Preview, export, rename, share, and manage\nfiles with a single tap.",
    },
    {
        "file": "05_details.png",
        "headline": "Encryption You Can Verify",
        "subtitle": "See the cipher, hashes, and metadata\nfor every encrypted file.",
    },
    {
        "file": "06_sharing.png",
        "headline": "Share Securely with Anyone",
        "subtitle": "Create encrypted public links\nthat protect your file keys.",
    },
    {
        "file": "07_pin.png",
        "headline": "Protected by PIN & Biometrics",
        "subtitle": "Lock your vault with a PIN, Face ID,\nor fingerprint for quick secure access.",
    },
    {
        "file": "08_server.png",
        "headline": "Self-Hosted & Multi-Server",
        "subtitle": "Connect to your own Hoodik servers.\nYour data never touches third parties.",
    },
]

MACOS_SCREENSHOTS = [
    {
        "file": "01_files.png",
        "headline": "Your Files, Fully Encrypted",
        "subtitle": "Browse folders and thumbnails with\nend-to-end encryption on every file.",
    },
    {
        "file": "02_transfers.png",
        "headline": "Lightning-Fast Transfers",
        "subtitle": "Upload and download large files with\nreal-time speed and progress tracking.",
    },
    {
        "file": "03_preview.png",
        "headline": "Preview Without Compromise",
        "subtitle": "View images, videos, and documents\ndecrypted locally on your device.",
    },
    {
        "file": "04_actions.png",
        "headline": "Everything at Your Fingertips",
        "subtitle": "Preview, export, rename, share, and manage\nfiles with a single tap.",
    },
    {
        "file": "05_details.png",
        "headline": "Encryption You Can Verify",
        "subtitle": "See the cipher, hashes, and metadata\nfor every encrypted file.",
    },
    {
        "file": "06_sharing.png",
        "headline": "Share Securely with Anyone",
        "subtitle": "Create encrypted public links\nthat protect your file keys.",
    },
    {
        "file": "07_pin.png",
        "headline": "Protected by PIN & Biometrics",
        "subtitle": "Lock your vault with a PIN, Touch ID,\nor password for quick secure access.",
    },
    {
        "file": "08_server.png",
        "headline": "Self-Hosted & Multi-Server",
        "subtitle": "Connect to your own Hoodik servers.\nYour data never touches third parties.",
    },
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_gradient(w: int, h: int, top: tuple, bottom: tuple) -> Image.Image:
    """Create a vertical linear gradient."""
    img = Image.new("RGB", (w, h))
    pixels = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        for x in range(w):
            pixels[x, y] = (r, g, b)
    return img


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    """Try to load SF Pro or Helvetica Neue, fall back to default."""
    candidates = [
        "/System/Library/Fonts/SFPro.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default(size=size)


def draw_text_block(draw, canvas_w, y_start, headline, subtitle,
                    font_h, font_s):
    """Draw centered headline + subtitle. Returns y after last line."""
    bbox = draw.textbbox((0, 0), headline, font=font_h)
    hw = bbox[2] - bbox[0]
    hh = bbox[3] - bbox[1]
    draw.text(((canvas_w - hw) // 2, y_start), headline,
              fill=TEXT_WHITE, font=font_h)

    sy = y_start + hh + 24
    for line in subtitle.split("\n"):
        bbox_s = draw.textbbox((0, 0), line, font=font_s)
        sw = bbox_s[2] - bbox_s[0]
        sh = bbox_s[3] - bbox_s[1]
        draw.text(((canvas_w - sw) // 2, sy), line,
                  fill=TEXT_DIM, font=font_s)
        sy += sh + 8

    return sy


def make_ipad_frame(screenshot: Image.Image) -> Image.Image:
    """Draw a minimal iPad frame (space grey, thin bezels) around a screenshot."""
    scr_w, scr_h = screenshot.size

    bezel = int(scr_w * 0.028)
    outer_radius = int(scr_w * 0.045)
    inner_radius = int(scr_w * 0.025)

    frame_w = scr_w + bezel * 2
    frame_h = scr_h + bezel * 2

    body_color = (58, 58, 60)
    edge_color = (75, 75, 77)
    inner_shadow = (30, 30, 32)

    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)

    # Outer body
    d.rounded_rectangle(
        [(0, 0), (frame_w - 1, frame_h - 1)],
        radius=outer_radius, fill=body_color, outline=edge_color, width=2,
    )

    # Inner shadow
    d.rounded_rectangle(
        [(bezel - 2, bezel - 2),
         (bezel + scr_w + 1, bezel + scr_h + 1)],
        radius=inner_radius + 2, fill=inner_shadow,
    )

    # Screen with rounded corners
    mask = Image.new("L", (scr_w, scr_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (scr_w - 1, scr_h - 1)], radius=inner_radius, fill=255,
    )
    screenshot = screenshot.convert("RGBA")
    screenshot.putalpha(mask)
    frame.paste(screenshot, (bezel, bezel), screenshot)

    # Camera dot
    cam_x, cam_y, cam_r = frame_w // 2, bezel // 2, max(4, bezel // 5)
    d.ellipse(
        [(cam_x - cam_r, cam_y - cam_r), (cam_x + cam_r, cam_y + cam_r)],
        fill=(40, 40, 42), outline=(70, 70, 72),
    )

    return frame


def make_iphone_frame(screenshot: Image.Image) -> Image.Image:
    """Draw a minimal iPhone-style frame around a screenshot."""
    scr_w, scr_h = screenshot.size

    bezel = int(scr_w * 0.025)
    outer_radius = int(scr_w * 0.065)
    inner_radius = int(scr_w * 0.050)

    frame_w = scr_w + bezel * 2
    frame_h = scr_h + bezel * 2

    body_color = (28, 28, 30)
    edge_color = (58, 58, 60)
    inner_shadow = (20, 20, 22)

    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)

    # Outer body
    d.rounded_rectangle(
        [(0, 0), (frame_w - 1, frame_h - 1)],
        radius=outer_radius, fill=body_color, outline=edge_color, width=2,
    )

    # Inner shadow
    d.rounded_rectangle(
        [(bezel - 2, bezel - 2),
         (bezel + scr_w + 1, bezel + scr_h + 1)],
        radius=inner_radius + 2, fill=inner_shadow,
    )

    # Screen with rounded corners
    mask = Image.new("L", (scr_w, scr_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (scr_w - 1, scr_h - 1)], radius=inner_radius, fill=255,
    )
    screenshot = screenshot.convert("RGBA")
    screenshot.putalpha(mask)
    frame.paste(screenshot, (bezel, bezel), screenshot)

    # Dynamic Island (pill shape at top center)
    pill_w = int(scr_w * 0.25)
    pill_h = int(scr_w * 0.028)
    pill_x = (frame_w - pill_w) // 2
    pill_y = bezel + int(scr_h * 0.012)
    pill_r = pill_h // 2
    d.rounded_rectangle(
        [(pill_x, pill_y), (pill_x + pill_w, pill_y + pill_h)],
        radius=pill_r, fill=(15, 15, 17),
    )

    return frame


def make_android_frame(screenshot: Image.Image) -> Image.Image:
    """Draw a minimal Pixel-style Android frame around a screenshot."""
    scr_w, scr_h = screenshot.size

    bezel = int(scr_w * 0.022)
    outer_radius = int(scr_w * 0.055)
    inner_radius = int(scr_w * 0.040)

    frame_w = scr_w + bezel * 2
    frame_h = scr_h + bezel * 2

    body_color = (44, 44, 46)
    edge_color = (65, 65, 67)
    inner_shadow = (25, 25, 27)

    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)

    # Outer body
    d.rounded_rectangle(
        [(0, 0), (frame_w - 1, frame_h - 1)],
        radius=outer_radius, fill=body_color, outline=edge_color, width=2,
    )

    # Inner shadow
    d.rounded_rectangle(
        [(bezel - 2, bezel - 2),
         (bezel + scr_w + 1, bezel + scr_h + 1)],
        radius=inner_radius + 2, fill=inner_shadow,
    )

    # Screen with rounded corners
    mask = Image.new("L", (scr_w, scr_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (scr_w - 1, scr_h - 1)], radius=inner_radius, fill=255,
    )
    screenshot = screenshot.convert("RGBA")
    screenshot.putalpha(mask)
    frame.paste(screenshot, (bezel, bezel), screenshot)

    # Punch-hole camera (centered at top of screen area)
    cam_r = max(6, int(scr_w * 0.009))
    cam_x = frame_w // 2
    cam_y = bezel + int(scr_h * 0.012)
    d.ellipse(
        [(cam_x - cam_r, cam_y - cam_r), (cam_x + cam_r, cam_y + cam_r)],
        fill=(20, 20, 22), outline=(45, 45, 47),
    )

    return frame


# ---------------------------------------------------------------------------
# Generators
# ---------------------------------------------------------------------------

def generate_iphone(config: dict):
    """Generate iPhone screenshot with programmatic device frame.

    Output: 1284x2778 (App Store 6.5" display requirement).
    """
    src_path = IPHONE_RAW_DIR / config["file"]
    out_name = f"iphone_{config['file']}"

    print(f"  {out_name} ...")

    raw = Image.open(src_path).convert("RGBA")
    framed = make_iphone_frame(raw)

    # App Store required dimensions for iPhone 6.5" display
    canvas_w, canvas_h = 1284, 2778

    canvas = make_gradient(canvas_w, canvas_h, BG_TOP, BG_BOTTOM).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # Scale fonts relative to canvas width
    font_scale = canvas_w / 1290
    text_bottom = draw_text_block(
        draw, canvas_w, int(100 * font_scale),
        config["headline"], config["subtitle"],
        load_font(int(72 * font_scale), bold=True),
        load_font(int(42 * font_scale)),
    )

    # Scale framed device to fit below text
    shot_top = text_bottom + int(40 * font_scale)
    available_h = canvas_h - shot_top - int(20 * font_scale)
    max_w = canvas_w - int(80 * font_scale)

    scale = min(max_w / framed.width, available_h / framed.height)
    new_w, new_h = int(framed.width * scale), int(framed.height * scale)
    resized = framed.resize((new_w, new_h), Image.LANCZOS)

    canvas.paste(resized, ((canvas_w - new_w) // 2, shot_top), resized)

    canvas.convert("RGB").save(OUTPUT_DIR / out_name, "PNG", optimize=True)
    print(f"    -> output/{out_name}")


def generate_ipad(config: dict):
    """Generate iPad screenshot with programmatic device frame.

    Output: 2048x2732 (App Store 13" display requirement).
    """
    src_path = IPAD_RAW_DIR / config["file"]
    out_name = f"ipad_{config['file']}"

    print(f"  {out_name} ...")

    raw = Image.open(src_path).convert("RGBA")
    framed = make_ipad_frame(raw)

    # App Store required dimensions for iPad 13" display
    canvas_w, canvas_h = 2048, 2732

    canvas = make_gradient(canvas_w, canvas_h, BG_TOP, BG_BOTTOM).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # Scale fonts relative to canvas width
    font_scale = canvas_w / 2048
    text_bottom = draw_text_block(
        draw, canvas_w, int(80 * font_scale),
        config["headline"], config["subtitle"],
        load_font(int(90 * font_scale), bold=True),
        load_font(int(50 * font_scale)),
    )

    # Scale framed iPad to fit below text
    shot_top = text_bottom + int(40 * font_scale)
    available_h = canvas_h - shot_top - int(30 * font_scale)
    max_w = canvas_w - int(120 * font_scale)

    scale = min(max_w / framed.width, available_h / framed.height)
    new_w, new_h = int(framed.width * scale), int(framed.height * scale)
    resized = framed.resize((new_w, new_h), Image.LANCZOS)

    canvas.paste(resized, ((canvas_w - new_w) // 2, shot_top), resized)

    canvas.convert("RGB").save(OUTPUT_DIR / out_name, "PNG", optimize=True)
    print(f"    -> output/{out_name}")


def generate_android(config: dict):
    """Generate Android screenshot with programmatic Pixel device frame."""
    src_path = ANDROID_RAW_DIR / config["file"]
    out_name = f"android_{config['file']}"

    # Detect canvas size from source image aspect ratio
    with Image.open(src_path) as probe:
        src_w, src_h = probe.size
    canvas_w = src_w
    canvas_h = src_h

    print(f"  {out_name} ...")

    raw = Image.open(src_path).convert("RGBA")
    framed = make_android_frame(raw)

    canvas = make_gradient(canvas_w, canvas_h, BG_TOP, BG_BOTTOM).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    text_bottom = draw_text_block(
        draw, canvas_w, 80, config["headline"], config["subtitle"],
        load_font(56, bold=True), load_font(32),
    )

    # Scale framed device to fit below text
    shot_top = text_bottom + 30
    available_h = canvas_h - shot_top - 20
    max_w = canvas_w - 80  # 40px side padding

    scale = min(max_w / framed.width, available_h / framed.height)
    new_w, new_h = int(framed.width * scale), int(framed.height * scale)
    resized = framed.resize((new_w, new_h), Image.LANCZOS)

    canvas.paste(resized, ((canvas_w - new_w) // 2, shot_top), resized)

    canvas.convert("RGB").save(OUTPUT_DIR / out_name, "PNG", optimize=True)
    print(f"    -> output/{out_name}")


def generate_android_tablet(config: dict, target_w: int, target_h: int,
                            prefix: str):
    """Generate Android tablet screenshot with programmatic device frame.

    Works for both 7-inch and 10-inch tablet slots by accepting target
    dimensions. The raw screenshot is framed, then composited onto a canvas
    of the target size with marketing text.
    """
    src_path = ANDROID_TABLET_DIR / config["file"]
    out_name = f"{prefix}_{config['file']}"
    canvas_w, canvas_h = target_w, target_h

    print(f"  {out_name} ...")

    raw = Image.open(src_path).convert("RGBA")
    framed = make_android_frame(raw)

    canvas = make_gradient(canvas_w, canvas_h, BG_TOP, BG_BOTTOM).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # Scale fonts relative to canvas width
    font_scale = canvas_w / 1080
    text_bottom = draw_text_block(
        draw, canvas_w, int(80 * font_scale),
        config["headline"], config["subtitle"],
        load_font(int(56 * font_scale), bold=True),
        load_font(int(32 * font_scale)),
    )

    # Scale framed device to fit below text
    shot_top = text_bottom + int(30 * font_scale)
    available_h = canvas_h - shot_top - int(20 * font_scale)
    max_w = canvas_w - int(80 * font_scale)

    scale = min(max_w / framed.width, available_h / framed.height)
    new_w, new_h = int(framed.width * scale), int(framed.height * scale)
    resized = framed.resize((new_w, new_h), Image.LANCZOS)

    canvas.paste(resized, ((canvas_w - new_w) // 2, shot_top), resized)

    canvas.convert("RGB").save(OUTPUT_DIR / out_name, "PNG", optimize=True)
    print(f"    -> output/{out_name}")


def generate_macos(config: dict):
    """Generate macOS App Store screenshot.

    Output: 2880x1800 (App Store Mac requirement).
    The app window is centered on the canvas with marketing text above.
    """
    src_path = MACOS_RAW_DIR / config["file"]
    out_name = f"macos_{config['file']}"

    print(f"  {out_name} ...")

    raw = Image.open(src_path).convert("RGBA")

    # App Store required dimensions for macOS
    canvas_w, canvas_h = 2880, 1800

    canvas = make_gradient(canvas_w, canvas_h, BG_TOP, BG_BOTTOM).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # Marketing text at the top
    text_bottom = draw_text_block(
        draw, canvas_w, 40,
        config["headline"], config["subtitle"],
        load_font(90, bold=True),
        load_font(50),
    )

    # Scale the app window to fit below the text
    shot_top = text_bottom + 40
    available_h = canvas_h - shot_top - 40
    max_w = canvas_w - 160  # 80px side padding

    scale = min(max_w / raw.width, available_h / raw.height)
    new_w, new_h = int(raw.width * scale), int(raw.height * scale)
    resized = raw.resize((new_w, new_h), Image.LANCZOS)

    canvas.paste(resized, ((canvas_w - new_w) // 2, shot_top), resized)

    canvas.convert("RGB").save(OUTPUT_DIR / out_name, "PNG", optimize=True)
    print(f"    -> output/{out_name}")


# ---------------------------------------------------------------------------
# Feature graphic (Google Play Store — 1024x500)
# ---------------------------------------------------------------------------

ICON_PATH = SCRIPT_DIR.parent.parent / "assets" / "icon.png"

def generate_feature_graphic():
    """Generate a 1024x500 feature graphic for Google Play Store."""
    canvas_w, canvas_h = 1024, 500
    out_name = "feature_graphic.png"

    print(f"  {out_name} ...")

    canvas = make_gradient(canvas_w, canvas_h, BG_TOP, BG_BOTTOM).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # Load and place the app icon (mascot)
    icon_size = 200
    if ICON_PATH.exists():
        icon = Image.open(ICON_PATH).convert("RGBA")
        icon = icon.resize((icon_size, icon_size), Image.LANCZOS)

        # Create circular mask for the icon
        mask = Image.new("L", (icon_size, icon_size), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [(0, 0), (icon_size - 1, icon_size - 1)],
            radius=40, fill=255,
        )
        icon.putalpha(mask)

        icon_x = (canvas_w - icon_size) // 2
        icon_y = 40
        canvas.paste(icon, (icon_x, icon_y), icon)
    else:
        icon_y = 40
        print("    WARNING: icon.png not found, skipping mascot")

    # App name
    font_title = load_font(64, bold=True)
    title = "Hoodik"
    bbox = draw.textbbox((0, 0), title, font=font_title)
    tw = bbox[2] - bbox[0]
    title_y = icon_y + icon_size + 20
    draw.text(((canvas_w - tw) // 2, title_y), title,
              fill=TEXT_WHITE, font=font_title)

    # Tagline
    font_tagline = load_font(28)
    tagline = "Your files. Your keys. Your server."
    bbox_t = draw.textbbox((0, 0), tagline, font=font_tagline)
    tgw = bbox_t[2] - bbox_t[0]
    tagline_y = title_y + (bbox[3] - bbox[1]) + 16
    draw.text(((canvas_w - tgw) // 2, tagline_y), tagline,
              fill=TEXT_DIM, font=font_tagline)

    # Subtitle
    font_sub = load_font(20)
    subtitle = "End-to-End Encrypted Cloud Storage"
    bbox_s = draw.textbbox((0, 0), subtitle, font=font_sub)
    sw = bbox_s[2] - bbox_s[0]
    sub_y = tagline_y + (bbox_t[3] - bbox_t[1]) + 10
    draw.text(((canvas_w - sw) // 2, sub_y), subtitle,
              fill=(120, 110, 105), font=font_sub)

    canvas.convert("RGB").save(OUTPUT_DIR / out_name, "PNG", optimize=True)
    print(f"    -> output/{out_name}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print(f"Source:  {SOURCES_DIR}/")
    print(f"Output:  {OUTPUT_DIR}/\n")

    count = 0

    print("--- iPhone (sources/iphone/) ---")
    for config in IPHONE_SCREENSHOTS:
        src = IPHONE_RAW_DIR / config["file"]
        if not src.exists():
            print(f"  SKIP: sources/iphone/{config['file']} not found")
            continue
        generate_iphone(config)
        count += 1

    print("\n--- iPad (sources/ipad/) ---")
    for config in IPAD_SCREENSHOTS:
        src = IPAD_RAW_DIR / config["file"]
        if not src.exists():
            print(f"  SKIP: sources/ipad/{config['file']} not found")
            continue
        generate_ipad(config)
        count += 1

    print("\n--- Android Phone (1080x1920) ---")
    for config in ANDROID_SCREENSHOTS:
        src = ANDROID_RAW_DIR / config["file"]
        if not src.exists():
            print(f"  SKIP: sources/android/{config['file']} not found")
            continue
        generate_android(config)
        count += 1

    if ANDROID_TABLET_DIR.exists():
        print("\n--- Android 7-inch Tablet (1200x1920) ---")
        for config in ANDROID_TABLET_SCREENSHOTS:
            src = ANDROID_TABLET_DIR / config["file"]
            if not src.exists():
                print(f"  SKIP: sources/android-tablet/{config['file']} not found")
                continue
            generate_android_tablet(config, 1200, 1920, "android_tablet_7")
            count += 1

        print("\n--- Android 10-inch Tablet (1600x2560) ---")
        for config in ANDROID_TABLET_SCREENSHOTS:
            src = ANDROID_TABLET_DIR / config["file"]
            if not src.exists():
                print(f"  SKIP: sources/android-tablet/{config['file']} not found")
                continue
            generate_android_tablet(config, 1600, 2560, "android_tablet_10")
            count += 1
    else:
        print("\n--- Android Tablet ---")
        print("  SKIP: sources/android-tablet/ not found")
        print("  To generate tablet screenshots, capture raw screenshots")
        print("  from an Android tablet emulator and save them to:")
        print(f"  {ANDROID_TABLET_DIR}/")

    if MACOS_RAW_DIR.exists():
        print("\n--- macOS App Store ---")
        for config in MACOS_SCREENSHOTS:
            src = MACOS_RAW_DIR / config["file"]
            if not src.exists():
                print(f"  SKIP: sources/macos/{config['file']} not found")
                continue
            generate_macos(config)
            count += 1
    else:
        print("\n--- macOS ---")
        print("  SKIP: sources/macos/ not found")

    print("\n--- Feature Graphic (1024x500) ---")
    generate_feature_graphic()
    count += 1

    print(f"\nDone! {count} screenshots -> output/")


if __name__ == "__main__":
    main()
