#!/usr/bin/env python3
"""
Generate a 1024x1024 app icon for WalkCue.

Design: a stride-forward chevron motif on a green→emerald vertical
gradient, with a walking-figure silhouette centered. Opaque PNG.
"""
from PIL import Image, ImageDraw, ImageFilter
import os, math

SIZE = 1024
OUT = os.path.join(
    os.path.dirname(__file__), "..",
    "WalkCue", "Resources", "Assets.xcassets",
    "AppIcon.appiconset", "AppIcon-1024.png",
)


def lerp(a, b, t): return int(a + (b - a) * t)


def vertical_gradient(size, top, bottom):
    img = Image.new("RGB", (size, size), top)
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        draw.line([(0, y), (size, y)],
                  fill=(lerp(top[0], bottom[0], t), lerp(top[1], bottom[1], t), lerp(top[2], bottom[2], t)))
    return img


def draw_chevrons(img):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    # Three ascending chevrons angled upward-right to suggest forward motion
    for i, opacity in enumerate([40, 70, 110]):
        cx = SIZE * (0.35 + i * 0.12)
        cy = SIZE * (0.72 - i * 0.10)
        w = SIZE * 0.22
        h = SIZE * 0.05
        pts = [
            (cx - w, cy + h * 1.2),
            (cx, cy),
            (cx + w, cy + h * 1.2),
            (cx + w - h * 1.6, cy + h * 2.2),
            (cx, cy + h * 1.1),
            (cx - w + h * 1.6, cy + h * 2.2),
        ]
        draw.polygon(pts, fill=(255, 255, 255, opacity))
    img.paste(overlay, (0, 0), overlay)


def draw_walker(img):
    """Simple centered figure: head + body + forward-stepping legs."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    cx = int(SIZE * 0.52)
    cy = int(SIZE * 0.46)
    color = (255, 255, 255, 240)
    # Head
    r = int(SIZE * 0.055)
    draw.ellipse([cx - r, cy - r * 2 - int(SIZE * 0.04),
                  cx + r, cy - int(SIZE * 0.04)], fill=color)
    # Body (lean forward)
    body_w = int(SIZE * 0.038)
    draw.line([(cx - body_w // 2, cy - int(SIZE * 0.02)),
               (cx + body_w // 2, cy + int(SIZE * 0.12))], fill=color, width=body_w)
    # Arm swinging forward
    arm_w = int(SIZE * 0.032)
    draw.line([(cx - int(SIZE * 0.01), cy + int(SIZE * 0.02)),
               (cx + int(SIZE * 0.10), cy + int(SIZE * 0.08))], fill=color, width=arm_w)
    # Back leg
    leg_w = int(SIZE * 0.036)
    draw.line([(cx + int(SIZE * 0.03), cy + int(SIZE * 0.12)),
               (cx - int(SIZE * 0.08), cy + int(SIZE * 0.26))], fill=color, width=leg_w)
    # Front leg (stepping)
    draw.line([(cx + int(SIZE * 0.03), cy + int(SIZE * 0.12)),
               (cx + int(SIZE * 0.13), cy + int(SIZE * 0.24))], fill=color, width=leg_w)
    img.paste(overlay, (0, 0), overlay)


def main():
    img = vertical_gradient(SIZE, (34, 138, 80), (16, 76, 48)).convert("RGBA")
    draw_chevrons(img)
    draw_walker(img)
    final = Image.new("RGB", (SIZE, SIZE), (16, 76, 48))
    final.paste(img, (0, 0), img)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    final.save(OUT, "PNG", optimize=True)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
