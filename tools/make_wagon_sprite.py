# Process the Summer-generated covered wagon into the map's position marker:
# crop, strip the pale background, and mirror to face LEFT (the direction of
# travel on our east-to-west map).
# Usage: python tools/make_wagon_sprite.py <wagon.png>

import os
import sys
from PIL import Image, ImageOps

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "family")

if __name__ == "__main__":
    img = Image.open(sys.argv[1]).convert("RGBA")
    w, h = img.size
    img = img.crop((int(w * 0.10), int(h * 0.30), int(w * 0.92), int(h * 0.66)))
    pixels = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = pixels[x, y]
            if r > 210 and g > 215 and b > 220:
                pixels[x, y] = (0, 0, 0, 0)
    img = ImageOps.mirror(img)
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, "wagon.png"))
    print("wagon sprite %dx%d (facing left)" % img.size)
