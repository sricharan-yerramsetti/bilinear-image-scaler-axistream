"""
png_to_hex.py — Convert a PNG image to a .hex file for Verilog $readmemh.

One line per pixel, raster order (row 0 left->right, then row 1, ...):
    grayscale : 8-bit  value per line  -> e.g. "a3"
    RGB       : 24-bit value per line  -> packed as {R,G,B}, e.g. "ff8000"
                (R in bits [23:16], G in [15:8], B in [7:0] — matches a
                 single NUM_CH*CH_W-wide AXI-Stream tdata word per pixel)

Usage:
    python3 png_to_hex.py input.png output.hex
    python3 png_to_hex.py input.png output.hex --rgb
    python3 png_to_hex.py input.png output.hex --width 1920 --height 1080
"""

import argparse
from PIL import Image


def png_to_hex(in_path, out_path, rgb=False, width=None, height=None):
    img = Image.open(in_path)

    if width and height:
        img = img.resize((width, height))

    img = img.convert("RGB") if rgb else img.convert("L")
    w, h = img.size
    pixels = img.load()

    with open(out_path, "w") as f:
        for y in range(h):
            for x in range(w):
                if rgb:
                    r, g, b = pixels[x, y]
                    packed = (r << 16) | (g << 8) | b
                    f.write(f"{packed:06x}\n")
                else:
                    val = pixels[x, y]
                    f.write(f"{val:02x}\n")

    print(f"Wrote {w}x{h} {'RGB (24-bit/pixel)' if rgb else 'grayscale (8-bit/pixel)'} "
          f"image ({w*h} lines) to {out_path}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("input_png")
    ap.add_argument("output_hex")
    ap.add_argument("--rgb", action="store_true", help="24-bit packed RGB per line instead of 8-bit grayscale")
    ap.add_argument("--width", type=int, default=None, help="resize width before conversion")
    ap.add_argument("--height", type=int, default=None, help="resize height before conversion")
    args = ap.parse_args()

    png_to_hex(args.input_png, args.output_hex, rgb=args.rgb,
               width=args.width, height=args.height)
