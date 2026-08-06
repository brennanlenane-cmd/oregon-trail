# Book-plate cutout pipeline for The Long Trail's paper-theater stage.
# Crops each subject out of its source engraving, forces it to ink
# (grayscale + autocontrast), and feathers an oval fade-to-white so the
# stage's multiply blend prints it straight into the paper with no frame.
# Also sweeps the art folder for color images and emits ink/ variants.
#
# Run:  python tools/make_cutouts.py   (from the project root)

import os
from PIL import Image, ImageDraw, ImageFilter, ImageOps

ART = os.path.join(os.path.dirname(__file__), "..", "assets", "art")
CUTOUTS = os.path.join(ART, "cutouts")
INK = os.path.join(ART, "ink")

# name -> (source, fractional crop box (l, t, r, b), mirror)
# Mirror so every enemy faces LEFT toward the wagon; the wagon faces right.
SUBJECTS = {
    "wolf": ("wolf-coyote.jpg", (0.02, 0.02, 0.60, 0.99), True),
    "rattlesnake": ("rattlesnake.jpg", (0.02, 0.18, 0.85, 0.98), True),
    "mountain-lion": ("mountain-lion.jpg", (0.04, 0.10, 0.58, 0.62), True),
    "grizzly": ("grizzly.png", (0.04, 0.06, 0.97, 0.97), False),
    "highwayman": ("highwayman.jpg", (0.42, 0.02, 1.00, 0.99), False),
    "road-agent": ("highwayman.jpg", (0.00, 0.36, 0.46, 1.00), True),
    "wagon": ("wagon-train.jpg", (0.20, 0.08, 0.64, 0.86), True),
}


def make_cutout(name, source, box, mirror):
    img = Image.open(os.path.join(ART, source)).convert("L")
    w, h = img.size
    img = img.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))
    if mirror:
        img = ImageOps.mirror(img)
    img = ImageOps.autocontrast(img, cutoff=2)
    # Oval feather: white beyond the ellipse, soft ramp at the rim.
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    inset_x, inset_y = int(img.size[0] * 0.03), int(img.size[1] * 0.03)
    draw.ellipse((inset_x, inset_y, img.size[0] - inset_x, img.size[1] - inset_y), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(max(img.size) * 0.045))
    plate = Image.composite(img, Image.new("L", img.size, 255), mask)
    out = os.path.join(CUTOUTS, name + ".png")
    plate.convert("RGB").save(out)
    print("cutout %-14s %dx%d  <- %s" % (name, plate.size[0], plate.size[1], source))


def make_plates():
    # Scene illustrations (landmarks, events) get a RECTANGULAR feather:
    # grayscale, contrast, edges fading softly to white so the multiply
    # blend melts them into parchment with no hard rectangle.
    plates = os.path.join(ART, "plates")
    os.makedirs(plates, exist_ok=True)
    made = 0
    for entry in sorted(os.listdir(ART)):
        if not entry.lower().endswith((".jpg", ".png")):
            continue
        img = ImageOps.autocontrast(Image.open(os.path.join(ART, entry)).convert("L"), cutoff=2)
        mask = Image.new("L", img.size, 0)
        inset_x, inset_y = int(img.size[0] * 0.055), int(img.size[1] * 0.055)
        ImageDraw.Draw(mask).rectangle((inset_x, inset_y, img.size[0] - inset_x, img.size[1] - inset_y), fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(max(img.size) * 0.03))
        plate = Image.composite(img, Image.new("L", img.size, 255), mask)
        plate.convert("RGB").save(os.path.join(plates, os.path.splitext(entry)[0] + ".png"))
        made += 1
    print("plates: %d scene illustrations feathered" % made)


# Carte-de-visite portraits: the family, cut from the Darley engraving
# (and Bewick's dog), framed in feathered ovals with an ink ring — the
# 19th-century family album look. member -> (source, crop box l/t/r/b)
PORTRAITS = {
    "pa": ("wagon-train.jpg", (0.555, 0.35, 0.72, 0.60)),
    "ma": ("wagon-train.jpg", (0.34, 0.225, 0.47, 0.43)),
    "sarah": ("wagon-train.jpg", (0.455, 0.285, 0.585, 0.475)),
    "ox": ("wagon-train.jpg", (0.295, 0.46, 0.45, 0.69)),
    "dog": ("dog-bewick.jpg", (0.05, 0.08, 0.95, 0.90)),
}


def make_portraits():
    out_dir = os.path.join(ART, "portraits")
    os.makedirs(out_dir, exist_ok=True)
    for member, (source, box) in PORTRAITS.items():
        img = Image.open(os.path.join(ART, source)).convert("L")
        w, h = img.size
        img = img.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))
        # Fit to 3:4 portrait around the crop's center, then normalize size.
        cw, ch = img.size
        target_ratio = 3.0 / 4.0
        if cw / ch > target_ratio:
            new_w = int(ch * target_ratio)
            img = img.crop(((cw - new_w) // 2, 0, (cw + new_w) // 2, ch))
        else:
            new_h = int(cw / target_ratio)
            img = img.crop((0, (ch - new_h) // 2, cw, (ch + new_h) // 2))
        img = ImageOps.autocontrast(img.resize((300, 400), Image.LANCZOS), cutoff=2)
        # Oval feather to white, then an ink ring like a locket frame.
        mask = Image.new("L", img.size, 0)
        ImageDraw.Draw(mask).ellipse((10, 10, 290, 390), fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(9))
        plate = Image.composite(img, Image.new("L", img.size, 255), mask).convert("RGB")
        ring = ImageDraw.Draw(plate)
        ring.ellipse((6, 6, 293, 393), outline=(34, 28, 20), width=5)
        ring.ellipse((14, 14, 285, 385), outline=(120, 96, 58), width=2)
        # Transparent corners: on dark chrome the medallion floats as a clean
        # oval; on parchment the multiply blend ignores the alpha anyway.
        alpha = Image.new("L", img.size, 0)
        ImageDraw.Draw(alpha).ellipse((4, 4, 295, 395), fill=255)
        alpha = alpha.filter(ImageFilter.GaussianBlur(3))
        plate = plate.convert("RGBA")
        plate.putalpha(alpha)
        plate.save(os.path.join(out_dir, member + ".png"))
        print("portrait %-6s <- %s" % (member, source))


def make_ink_variants():
    made = []
    for entry in sorted(os.listdir(ART)):
        if not entry.lower().endswith((".jpg", ".png")):
            continue
        img = Image.open(os.path.join(ART, entry)).convert("RGB")
        saturation = ImageOps.autocontrast(img).convert("HSV").split()[1]
        mean = sum(saturation.histogram()[i] * i for i in range(256)) / (img.size[0] * img.size[1])
        if mean <= 28:
            continue  # already reads as ink
        ink = ImageOps.autocontrast(img.convert("L"), cutoff=1)
        stem = os.path.splitext(entry)[0]
        ink.convert("RGB").save(os.path.join(INK, stem + ".png"))
        made.append("%s (sat %d)" % (entry, mean))
    print("ink variants:", ", ".join(made) if made else "none needed")


if __name__ == "__main__":
    os.makedirs(CUTOUTS, exist_ok=True)
    os.makedirs(INK, exist_ok=True)
    for name, (source, box, mirror) in SUBJECTS.items():
        make_cutout(name, source, box, mirror)
    make_ink_variants()
    make_plates()
    make_portraits()
