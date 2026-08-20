#!/usr/bin/env python3
"""Generate HRM app launcher icons — Minh An brand."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MOBILE = ROOT / "mobile"
ASSETS = MOBILE / "assets" / "images"
ANDROID_RES = MOBILE / "android" / "app" / "src" / "main" / "res"
IOS_ICON = MOBILE / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

BASE = 256.0
BG_TOP = (4, 91, 87)
BG_MID = (8, 122, 117)
BG_BOTTOM = (10, 143, 136)
GOLD = (185, 135, 22)
WHITE = (255, 255, 255)

# Căn giữa MA quanh tâm icon (128, 128).
MA_ORIGIN = (141.0, 130.0)
MA_TARGET = (128.0, 136.0)
MA_SCALE = 0.84


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def blend(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t))


def rounded_rect_mask(size: int, radius: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def to_px(x: float, y: float, icon_size: int) -> tuple[float, float]:
    s = icon_size / BASE
    return x * s, y * s


def transform_ma_point(x: float, y: float) -> tuple[float, float]:
    ox, oy = MA_ORIGIN
    tx, ty = MA_TARGET
    return (x - ox) * MA_SCALE + tx, (y - oy) * MA_SCALE + ty


def transform_poly(pts: list[tuple[float, float]], icon_size: int) -> list[tuple[float, float]]:
    return [to_px(*transform_ma_point(x, y), icon_size) for x, y in pts]


def draw_background(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        ty = y / max(size - 1, 1)
        tx = 0.35 + ty * 0.35
        top = blend(BG_TOP, BG_MID, tx)
        bottom = blend(BG_MID, BG_BOTTOM, ty)
        row = blend(top, bottom, ty)
        for x in range(size):
            px[x, y] = row + (255,)
    mask = rounded_rect_mask(size, size * 0.21875)
    img.putalpha(mask)
    return img


def draw_glow(draw: ImageDraw.ImageDraw, size: int) -> None:
    cx = cy = size / 2
    for ratio, alpha in ((0.34, 22), (0.26, 34), (0.18, 46)):
        r = size * ratio
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=WHITE + (alpha,))


def draw_ring(draw: ImageDraw.ImageDraw, size: int) -> None:
    cx = cy = size / 2
    r = size * 0.305
    draw.ellipse(
        (cx - r, cy - r, cx + r, cy + r),
        outline=WHITE + (36,),
        width=max(2, size // 128),
    )


def draw_person(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    head_r: float,
    body_w: float,
    body_h: float,
    alpha: int = 255,
) -> None:
    fill = WHITE + (alpha,)
    draw.ellipse(
        (cx - head_r, cy - head_r, cx + head_r, cy + head_r * 0.95),
        fill=fill,
    )
    top = cy + head_r * 0.85
    left = cx - body_w / 2
    draw.rounded_rectangle(
        (left, top, left + body_w, top + body_h),
        radius=body_w / 2,
        fill=fill,
    )


def draw_people(draw: ImageDraw.ImageDraw, size: int) -> None:
    """Ba nhân sự cân đối — hàng trên, không đè lên MA."""
    for cx, alpha in ((96, 215), (128, 255), (160, 215)):
        x, y = to_px(cx, 62, size)
        s = size / BASE
        draw_person(draw, x, y, 7.5 * s, 17 * s, 11 * s, alpha=alpha)


def ma_polygons_raw() -> tuple[list[tuple[float, float]], list[tuple[float, float]], list[tuple[float, float]]]:
    m = [
        (54, 172), (54, 88), (76, 88), (100, 140), (124, 88), (146, 88),
        (146, 172), (126, 172), (126, 122), (108, 164), (96, 164),
        (78, 122), (78, 172),
    ]
    a_outer = [
        (156, 172), (180, 88), (204, 88), (228, 172), (206, 172),
        (201.5, 156), (174.5, 156), (170, 172),
    ]
    a_hole = [(183, 138), (201, 138), (192, 106)]
    return m, a_outer, a_hole


def punch_hole(layer: Image.Image, hole: list[tuple[float, float]]) -> Image.Image:
    mask = Image.new("L", layer.size, 255)
    draw = ImageDraw.Draw(mask)
    draw.polygon(hole, fill=0)
    r, g, b, a = layer.split()
    a = ImageChops.multiply(a, mask)
    return Image.merge("RGBA", (r, g, b, a))


def draw_ma_layer(size: int) -> Image.Image:
    m, a_outer, a_hole = ma_polygons_raw()
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.polygon(transform_poly(m, size), fill=WHITE + (255,))
    draw.polygon(transform_poly(a_outer, size), fill=WHITE + (255,))
    return punch_hole(layer, transform_poly(a_hole, size))


def draw_gold_bar(draw: ImageDraw.ImageDraw, size: int) -> None:
    s = size / BASE
    bar_w = 78 * s
    bar_h = 5.5 * s
    cx = size / 2
    y = 186 * s
    x1 = cx - bar_w / 2
    draw.rounded_rectangle(
        (x1, y, x1 + bar_w, y + bar_h),
        radius=bar_h / 2,
        fill=GOLD + (255,),
    )


def draw_sheen(base: Image.Image) -> None:
    size = base.width
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = overlay.load()
    for y in range(size):
        t = max(0.0, 1.0 - y / (size * 0.55))
        alpha = int(34 * t)
        if alpha <= 0:
            continue
        for x in range(size):
            px[x, y] = WHITE + (alpha,)
    base.alpha_composite(overlay)


def render_emblem(size: int, include_bg: bool) -> Image.Image:
    canvas = draw_background(size) if include_bg else Image.new("RGBA", (size, size), (0, 0, 0, 0))

    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw_glow(draw, size)
    draw_ring(draw, size)
    draw_people(draw, size)
    draw_gold_bar(draw, size)
    canvas.alpha_composite(layer)
    canvas.alpha_composite(draw_ma_layer(size))

    if include_bg:
        draw_sheen(canvas)
    return canvas


def render_foreground(size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    emblem = render_emblem(int(size * 0.68), include_bg=False)
    offset = (size - emblem.width) // 2
    canvas.alpha_composite(emblem, (offset, offset))
    return canvas


def save_png(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG", optimize=True)
    print(f"wrote {path}")


def export_android(full: Image.Image, fg: Image.Image) -> None:
    sizes = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
        "mipmap-mdpi/ic_launcher_foreground.png": 108,
        "mipmap-hdpi/ic_launcher_foreground.png": 162,
        "mipmap-xhdpi/ic_launcher_foreground.png": 216,
        "mipmap-xxhdpi/ic_launcher_foreground.png": 324,
        "mipmap-xxxhdpi/ic_launcher_foreground.png": 432,
    }
    for rel, px in sizes.items():
        src = fg if "foreground" in rel else full
        save_png(src.resize((px, px), Image.Resampling.LANCZOS), ANDROID_RES / rel)


def export_ios(full: Image.Image) -> None:
    contents = json.loads((IOS_ICON / "Contents.json").read_text(encoding="utf-8"))
    for item in contents["images"]:
        if not item.get("filename"):
            continue
        points = float(item["size"].split("x")[0])
        scale = int(str(item["scale"]).rstrip("x"))
        px = int(round(points * scale))
        save_png(full.resize((px, px), Image.Resampling.LANCZOS), IOS_ICON / item["filename"])


def write_adaptive_xml() -> None:
    anydpi = ANDROID_RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    (anydpi / "ic_launcher.xml").write_text(xml, encoding="utf-8")
    (anydpi / "ic_launcher_round.xml").write_text(xml, encoding="utf-8")
    print(f"wrote {anydpi / 'ic_launcher.xml'}")


def main() -> None:
    master = render_emblem(1024, include_bg=True)
    foreground = render_foreground(1024)

    save_png(master, ASSETS / "app_icon.png")
    save_png(foreground, ASSETS / "app_icon_foreground.png")

    export_android(master, foreground)
    export_ios(master)
    write_adaptive_xml()


if __name__ == "__main__":
    main()
