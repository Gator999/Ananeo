#!/usr/bin/env python3
# Draws the Ananeo app icon: the two-arrow loop in white and Spark on the Renewal gradient.
# Usage: scripts/draw-app-icon.py Ananeo/Assets.xcassets/AppIcon.appiconset/AppIcon.png  (needs Pillow)
# Same geometry as LoopArrowShape in the app, rendered at 4x and downsampled for smooth edges.
import math, sys
from PIL import Image, ImageDraw

SIZE = 1024
SS = 4
W = SIZE * SS

FOREST = (0x0B, 0x3B, 0x2C)
LEAF = (0x15, 0x93, 0x5B)
MINT = (0xA9, 0xF0, 0xCD)
SPARK = (0xD9, 0xF9, 0x61)
WHITE = (255, 255, 255)

def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))

LEAF_LIGHT = (0x4C, 0xB9, 0x7E)

def gradient_color(t):
    # Forest 0 -> Leaf 0.7 -> mid green 1, the button gradient, so the Spark arrow keeps its contrast.
    if t < 0.7:
        return lerp(FOREST, LEAF, t / 0.7)
    return lerp(LEAF, LEAF_LIGHT, (t - 0.7) / 0.3)

# Background: 135 degree gradient, built as a 1D ramp and sheared.
ramp = Image.new("RGB", (W * 2, 1))
rp = ramp.load()
for x in range(W * 2):
    rp[x, 0] = gradient_color(x / (W * 2 - 1))
bg = Image.new("RGB", (W, W))
bp = bg.load()
for y in range(W):
    row = ramp.crop((y, 0, y + W, 1))
    bg.paste(row, (0, y))

draw = ImageDraw.Draw(bg)

# Loop geometry, as in LoopArrowShape: radius leaves room for the arrowheads.
side = W * 0.78            # the mark occupies 78% of the icon
line = side * 0.11
radius = side / 2 - line * 1.4
cx = cy = W / 2

def point(angle):
    return (cx + radius * math.cos(angle), cy + radius * math.sin(angle))

def arc(start_deg, end_deg, color):
    # A ring sector as one polygon: the outer edge forward, the inner edge back, then round caps.
    angles = [math.radians(start_deg + (end_deg - start_deg) * i / 240) for i in range(241)]
    outer = [(cx + (radius + line / 2) * math.cos(a), cy + (radius + line / 2) * math.sin(a)) for a in angles]
    inner = [(cx + (radius - line / 2) * math.cos(a), cy + (radius - line / 2) * math.sin(a)) for a in reversed(angles)]
    draw.polygon(outer + inner, fill=color)
    # Round cap at the start only; the arrowhead covers the end.
    p = point(angles[0])
    draw.ellipse((p[0] - line / 2, p[1] - line / 2, p[0] + line / 2, p[1] + line / 2), fill=color)
    # Arrowhead at the end, pointing clockwise.
    a = math.radians(end_deg)
    ex, ey = point(a)
    tx, ty = -math.sin(a), math.cos(a)
    nx, ny = math.cos(a), math.sin(a)
    tip = (ex + tx * 0.9 * line, ey + ty * 0.9 * line)
    base1 = (ex - tx * 1.3 * line + nx * 1.3 * line, ey - ty * 1.3 * line + ny * 1.3 * line)
    base2 = (ex - tx * 1.3 * line - nx * 1.3 * line, ey - ty * 1.3 * line - ny * 1.3 * line)
    draw.polygon([tip, base1, base2], fill=color)

# Angles are clockwise from three o'clock, with y down, matching the app.
arc(200, 340, WHITE)   # top arrow
arc(20, 160, SPARK)    # bottom arrow

out = bg.resize((SIZE, SIZE), Image.LANCZOS)
out.save(sys.argv[1], "PNG")
print("icon written", out.size)
