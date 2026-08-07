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


# The white ox is nearly paper-colored — he keeps a tight threshold so his
# hide survives; everyone else gets the loose one that kills the darker band.
TIGHT = {"ox"}


def strip_background(img: Image.Image, name: str) -> Image.Image:
    img = img.convert("RGBA")
    pixels = img.load()
    width, height = img.size
    floor_r, floor_g, floor_b = (224, 218, 198) if name in TIGHT else (213, 206, 184)
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if r > floor_r and g > floor_g and b > floor_b and abs(r - b) < 52:
                pixels[x, y] = (0, 0, 0, 0)
    return img


if __name__ == "__main__":
    sheet = Image.open(sys.argv[1])
    os.makedirs(OUT, exist_ok=True)
    for name, box in BOXES.items():
        sprite = strip_background(sheet.crop(box), name)
        sprite.save(os.path.join(OUT, name + ".png"))
        print("sprite %-6s %dx%d" % (name, sprite.size[0], sprite.size[1]))
