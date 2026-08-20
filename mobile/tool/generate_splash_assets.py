#!/usr/bin/env python3
"""Generate splash / launcher assets from repo root logo.jpg."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
LOGO_JPG = ROOT / "logo.jpg"
MOBILE = ROOT / "mobile"
ASSETS = MOBILE / "assets" / "images"
ANDROID_RES = MOBILE / "android" / "app" / "src" / "main" / "res"
IOS_LAUNCH = MOBILE / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"

BRAND_DARK = (0, 104, 101)  # #006865
BRAND_DEEP = (0, 72, 69)
BRAND_LIGHT = (10, 143, 136)


def load_logo_square() -> Image.Image:
    im = Image.open(LOGO_JPG).convert("RGBA")
    w, h = im.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    return im.crop((left, top, left + side, top + side))


def resize(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.Resampling.LANCZOS)


def extract_circular_emblem(source: Image.Image, size: int) -> Image.Image:
    """Giữ phần huy hiệu tròn (từ viền xanh trở vào), nền ngoài trong suốt."""
    logo = resize(source, size)
    w, h = logo.size
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    # Hơi thu vào để cắt sạch viền trắng vuông ngoài huy hiệu.
    inset = max(1, int(size * 0.012))
    draw.ellipse((inset, inset, w - 1 - inset, h - 1 - inset), fill=255)
    out = logo.copy()
    out.putalpha(mask)
    return out


def soft_glow(size: int, radius: float, alpha: int) -> Image.Image:
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    cx = cy = size // 2
    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=(255, 255, 255, alpha),
    )
    return glow.filter(ImageFilter.GaussianBlur(radius=size * 0.028))


def paste_center(canvas: Image.Image, layer: Image.Image) -> None:
    x = (canvas.width - layer.width) // 2
    y = (canvas.height - layer.height) // 2
    canvas.alpha_composite(layer, (x, y))


def brand_gradient(size: tuple[int, int]) -> Image.Image:
    w, h = size
    base = Image.new("RGB", size, BRAND_DARK)
    draw = ImageDraw.Draw(base)
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(BRAND_DEEP[0] * (1 - t) + BRAND_LIGHT[0] * t)
        g = int(BRAND_DEEP[1] * (1 - t) + BRAND_LIGHT[1] * t)
        b = int(BRAND_DEEP[2] * (1 - t) + BRAND_LIGHT[2] * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    return base.convert("RGBA")


def make_logo_hd(source: Image.Image, size: int = 1024) -> Image.Image:
    return extract_circular_emblem(source, size)


def make_splash_badge(source: Image.Image, size: int = 1024) -> Image.Image:
    """Huy hiệu tròn + hào quang nhẹ — không nền trắng."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    emblem_size = int(size * 0.82)
    emblem = extract_circular_emblem(source, emblem_size)
    glow = soft_glow(size, size * 0.40, 42)
    paste_center(canvas, glow)
    paste_center(canvas, emblem)
    return canvas


def make_splash_mark(source: Image.Image, size: int = 432, emblem_ratio: float = 0.68) -> Image.Image:
    """Android 12+ — nền trong suốt, logo trong vùng an toàn."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    emblem = extract_circular_emblem(source, int(size * emblem_ratio))
    paste_center(canvas, emblem)
    return canvas


def make_launch_screen(source: Image.Image, width: int, height: int) -> Image.Image:
    canvas = brand_gradient((width, height))
    emblem = extract_circular_emblem(source, int(min(width, height) * 0.34))
    x = (width - emblem.width) // 2
    y = int(height * 0.30)
    canvas.alpha_composite(emblem, (x, y))
    return canvas


def save_png(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    im.save(path, "PNG", optimize=True)
    print(f"wrote {path}")


def main() -> None:
    if not LOGO_JPG.is_file():
        raise SystemExit(f"Missing source logo: {LOGO_JPG}")

    source = load_logo_square()
    logo_hd = make_logo_hd(source)
    splash_badge = make_splash_badge(source)
    splash_mark = make_splash_mark(source)

    save_png(logo_hd, ASSETS / "logo_hd.png")
    save_png(logo_hd, ASSETS / "logo.png")
    save_png(splash_badge, ASSETS / "splash_logo_badge.png")
    save_png(splash_mark, ANDROID_RES / "drawable" / "splash_mark.png")

    for density, w in (
        ("mdpi", 360),
        ("hdpi", 540),
        ("xhdpi", 720),
        ("xxhdpi", 1080),
        ("xxxhdpi", 1440),
    ):
        launch = make_launch_screen(source, w, int(w * 16 / 9))
        folder = ANDROID_RES / f"drawable-{density}"
        save_png(launch, folder / "launch_brand.png")
    save_png(make_launch_screen(source, 1080, 1920), ANDROID_RES / "drawable" / "launch_brand.png")

    save_png(make_launch_screen(source, 360, 640), IOS_LAUNCH / "LaunchImage.png")
    save_png(make_launch_screen(source, 720, 1280), IOS_LAUNCH / "LaunchImage@2x.png")
    save_png(make_launch_screen(source, 1080, 1920), IOS_LAUNCH / "LaunchImage@3x.png")


if __name__ == "__main__":
    main()
