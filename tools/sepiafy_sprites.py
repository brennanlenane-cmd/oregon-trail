# Pull the 16-bit sprites into the map's own ink: desaturate toward sepia and
# quantize hard, so the family read as painted game pieces on the parchment
# instead of full-RGB video game sprites dropped onto it. Also cuts pixel
# "busts" (head crops) for the top-bar medallions so map and HUD share one
# character identity.
# Usage: python tools/sepiafy_sprites.py

import os
from PIL import Image

FAMILY = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "family")
BUSTS = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "busts")

# Head crops per member (source sprite coordinates).
BUST_BOXES = {
    "pa": (30, 6, 170, 146),
    "ma": (30, 10, 160, 140),
    "sarah": (5, 4, 145, 144),
    "dog": (0, 10, 130, 140),
    "ox": (0, 20, 130, 150),
}

SEPIA_STRENGTH = 0.0  # full color restored - sprites live in painted scenes now  # 0 = untouched, 1 = full monochrome sepia


def sepiafy(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    pixels = img.load()
    width, height = img.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            gray = 0.3 * r + 0.59 * g + 0.11 * b
            sr, sg, sb = gray * 1.04, gray * 0.92, gray * 0.72
            pixels[x, y] = (
                int(r * (1 - SEPIA_STRENGTH) + sr * SEPIA_STRENGTH),
                int(g * (1 - SEPIA_STRENGTH) + sg * SEPIA_STRENGTH),
                int(b * (1 - SEPIA_STRENGTH) + sb * SEPIA_STRENGTH),
                a,
            )
    # Quantize to a tight palette, preserving the alpha channel.
    alpha = img.getchannel("A")
    quantized = img.convert("RGB").quantize(colors=8).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


if __name__ == "__main__":
    import sys
    os.makedirs(BUSTS, exist_ok=True)
    targets = sys.argv[1:] if len(sys.argv) > 1 else ["pa", "ma", "sarah", "dog", "ox", "wagon"]
    for name in targets:
        path = os.path.join(FAMILY, name + ".png")
        if not os.path.exists(path):
            continue
        sprite = sepiafy(Image.open(path))
        sprite.save(path)
        print("sepiafied %s" % name)
        if name in BUST_BOXES:
            bust = sprite.crop(BUST_BOXES[name])
            bust.save(os.path.join(BUSTS, name + ".png"))
            print("bust %s %dx%d" % (name, bust.size[0], bust.size[1]))
