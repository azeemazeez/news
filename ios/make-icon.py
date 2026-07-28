#!/usr/bin/env python3
"""Render the 1024x1024 App Store icon.

Deliberately dependency-free so it runs anywhere, including CI, without a
Pillow install. Draws the same mark as public/favicon.svg: a white "N" on the
brand purple. Output is opaque RGB — App Store icons must not carry an alpha
channel.
"""

import struct
import zlib
from pathlib import Path

SIZE = 1024
BACKGROUND = (0x6B, 0x33, 0xBE)
FOREGROUND = (0xFF, 0xFF, 0xFF)
SAMPLES = 3  # supersampling factor per axis, for antialiased edges

# The "N", as three filled polygons on a 1024 grid.
STROKE_POLYGONS = [
    [(300, 292), (392, 292), (392, 732), (300, 732)],              # left stem
    [(632, 292), (724, 292), (724, 732), (632, 732)],              # right stem
    [(300, 292), (392, 292), (724, 732), (632, 732)],              # diagonal
]


def point_in_polygon(x, y, polygon):
    """Standard ray-casting test."""
    inside = False
    count = len(polygon)
    j = count - 1
    for i in range(count):
        xi, yi = polygon[i]
        xj, yj = polygon[j]
        if (yi > y) != (yj > y):
            if x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                inside = not inside
        j = i
    return inside


def coverage(px, py):
    """Fraction of the pixel covered by the glyph, via supersampling."""
    hits = 0
    step = 1.0 / SAMPLES
    offset = step / 2.0
    for sy in range(SAMPLES):
        y = py + offset + sy * step
        for sx in range(SAMPLES):
            x = px + offset + sx * step
            if any(point_in_polygon(x, y, poly) for poly in STROKE_POLYGONS):
                hits += 1
    return hits / float(SAMPLES * SAMPLES)


def build_rows():
    # Precompute the vertical span the glyph occupies so we skip empty rows fast.
    min_y = min(y for poly in STROKE_POLYGONS for _, y in poly)
    max_y = max(y for poly in STROKE_POLYGONS for _, y in poly)
    min_x = min(x for poly in STROKE_POLYGONS for x, _ in poly)
    max_x = max(x for poly in STROKE_POLYGONS for x, _ in poly)

    background_row = bytes(BACKGROUND) * SIZE
    rows = []

    for py in range(SIZE):
        if py < min_y - 1 or py > max_y + 1:
            rows.append(b"\x00" + background_row)
            continue

        row = bytearray(b"\x00")  # PNG filter type 0 (None)
        for px in range(SIZE):
            if px < min_x - 1 or px > max_x + 1:
                row += bytes(BACKGROUND)
                continue

            alpha = coverage(px, py)
            if alpha <= 0.0:
                row += bytes(BACKGROUND)
            elif alpha >= 1.0:
                row += bytes(FOREGROUND)
            else:
                row += bytes(
                    int(round(bg + (fg - bg) * alpha))
                    for bg, fg in zip(BACKGROUND, FOREGROUND)
                )
        rows.append(bytes(row))

    return b"".join(rows)


def chunk(tag, payload):
    return (
        struct.pack(">I", len(payload))
        + tag
        + payload
        + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    )


def main():
    raw = build_rows()

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)  # 8-bit truecolour RGB
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )

    out = Path(__file__).parent / "TheNuus/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(png)
    print(f"Wrote {out} ({len(png):,} bytes)")


if __name__ == "__main__":
    main()
