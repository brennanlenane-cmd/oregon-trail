# Slice the Summer-generated 16-bit enemy sheet into per-enemy sprites with
# transparent backgrounds and the same sepia-quantize treatment as the family,
# so both sides of a fight are pieces from the same box.
# Usage: python tools/slice_enemy_sprites.py <sheet.png>

import os
import sys
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "enemies")

BOXES = {
    "wolf": (22, 470, 238, 622),
    "grizzly": (238, 385, 378, 622),
    "rattlesnake": (400, 472, 515, 618),
    "mountain-lion": (520, 522, 708, 622),
    "road-agent": (712, 448, 802, 622),
    "highwayman": (802, 415, 995, 618),
}

SEPIA_STRENGTH = 0.55


def process(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    pixels = img.load()
    width, height = img.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if r > 222 and g > 216 and b > 196 and abs(r - b) < 48:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            gray = 0.3 * r + 0.59 * g + 0.11 * b
            sr, sg, sb = gray * 1.04, gray * 0.92, gray * 0.72
            pixels[x, y] = (
                int(r * (1 - SEPIA_STRENGTH) + sr * SEPIA_STRENGTH),
                int(g * (1 - SEPIA_STRENGTH) + sg * SEPIA_STRENGTH),
                int(b * (1 - SEPIA_STRENGTH) + sb * SEPIA_STRENGTH),
                a,
            )
    alpha = img.getchannel("A")
    quantized = img.convert("RGB").quantize(colors=8).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


if __name__ == "__main__":
    sheet = Image.open(sys.argv[1])
    os.makedirs(OUT, exist_ok=True)
    for name, box in BOXES.items():
        sprite = process(sheet.crop(box))
        sprite.save(os.path.join(OUT, name + ".png"))
        print("enemy %-14s %dx%d" % (name, sprite.size[0], sprite.size[1]))
