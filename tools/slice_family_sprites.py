# Slice the Summer-generated 16-bit family sheet into per-member sprites
# with transparent backgrounds, for the marching column on the trail map.
# Usage: python tools/slice_family_sprites.py <sheet.png>

import os
import sys
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "family")

# Hand-tuned boxes for the 1024x1024 sheet (figures sit in the y 300-680 band).
BOXES = {
    "pa": (14, 310, 200, 665),
    "ma": (228, 340, 400, 665),
    "sarah": (420, 350, 565, 665),
    "dog": (570, 460, 825, 660),
    "ox": (828, 380, 1024, 670),
}


def strip_background(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    pixels = img.load()
    width, height = img.size
    # The sheet background is flat cream; anything close to it goes clear.
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if r > 222 and g > 216 and b > 196 and abs(r - b) < 45:
                pixels[x, y] = (0, 0, 0, 0)
    return img


if __name__ == "__main__":
    sheet = Image.open(sys.argv[1])
    os.makedirs(OUT, exist_ok=True)
    for name, box in BOXES.items():
        sprite = strip_background(sheet.crop(box))
        sprite.save(os.path.join(OUT, name + ".png"))
        print("sprite %-6s %dx%d" % (name, sprite.size[0], sprite.size[1]))
