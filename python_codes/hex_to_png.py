"""
hex_to_png.py — Convert a Verilog $writememh-style .hex dump back to a PNG.

Expects one value per line, raster order, matching png_to_hex.py's format:
    grayscale : 8-bit  value per line  -> e.g. "a3"
    RGB       : 24-bit value per line  -> packed as {R,G,B}, e.g. "ff8000"

You must know the destination width/height (e.g. your scaler's
DST_W=1280, DST_H=720) since the hex file has no header.

Usage:
    python3 hex_to_png.py output.hex result.png --width 1280 --height 720
    python3 hex_to_png.py output.hex result.png --width 1280 --height 720 --rgb
"""

import argparse
from PIL import Image


def hex_to_png(in_path, out_path, width, height, rgb=False):
    with open(in_path) as f:
        values = [int(line.strip(), 16) for line in f if line.strip()]

    expected = width * height
    if len(values) != expected:
        print(f"Warning: expected {expected} lines for {width}x{height}, "
              f"got {len(values)}. Truncating/padding to fit.")
        values = (values + [0] * expected)[:expected]

    mode = "RGB" if rgb else "L"
    img = Image.new(mode, (width, height))
    pixels = img.load()

    idx = 0
    for y in range(height):
        for x in range(width):
            if rgb:
                packed = values[idx]
                r = (packed >> 16) & 0xFF
                g = (packed >> 8) & 0xFF
                b = packed & 0xFF
                pixels[x, y] = (r, g, b)
            else:
                pixels[x, y] = values[idx] & 0xFF
            idx += 1

    img.save(out_path)
    print(f"Wrote {width}x{height} {'RGB (24-bit/pixel)' if rgb else 'grayscale (8-bit/pixel)'} "
          f"PNG to {out_path}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("input_hex")
    ap.add_argument("output_png")
    ap.add_argument("--width", type=int, required=True)
    ap.add_argument("--height", type=int, required=True)
    ap.add_argument("--rgb", action="store_true", help="input lines are 24-bit packed RGB instead of 8-bit grayscale")
    args = ap.parse_args()

    hex_to_png(args.input_hex, args.output_png, args.width, args.height, rgb=args.rgb)
