#!/usr/bin/env python3
"""Paint the orange lambda "VR" logo and the orange button off the Lambda1VR flashlight model (models/v_torch.mdl)
so the handle is plain black like the rest; the hand HUD's health/suit panel sits on it.

Usage: patch-torch-model.py [ROOT]   (default ~/Games/lambda1vr-pc; patches valve, bshift, gearbox)
Run by install-linux-steamvr.sh on every install. Writes MODEL.orig once, then replaces the model via a new file
+ rename (safe while the game runs). Idempotent: an already patched model is left alone."""
import os, struct, sys

ROOT = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Games/lambda1vr-pc")
# (x0, y0, x1, y1) around the orange part in the 512x512 texture, (dx, dy) to plain handle texture to copy from
REGIONS = [
    ((310, 255, 390, 340), (0, -100)),   # lambda VR logo on the handle
    ((130, 380, 185, 435), (-60, -280)), # the button (its own UV island; filled from the body, clear of the stripe)
]
GROW = 2                      # also cover this many pixels around the orange (anti-aliased fringe)

def is_orange(rgb):
    r, g, b = rgb
    return r > 90 and r > b + 50

def patch(data):
    numtex, texidx = struct.unpack_from("2i", data, 180)
    for i in range(numtex):
        name, _flags, w, h, idx = struct.unpack_from("64s4i", data, texidx + 80 * i)
        if not name.startswith(b"fonarik") or (w, h) != (512, 512):
            continue
        pal = data[idx + w * h: idx + w * h + 768]
        pix = bytearray(data[idx: idx + w * h])
        total = 0
        for (x0, y0, x1, y1), (sx, sy) in REGIONS:
            hit = {(x, y) for y in range(y0, y1) for x in range(x0, x1)
                   if is_orange(pal[pix[y * w + x] * 3: pix[y * w + x] * 3 + 3])}
            cover = {(x + dx, y + dy) for x, y in hit for dx in range(-GROW, GROW + 1) for dy in range(-GROW, GROW + 1)}
            for x, y in cover:
                pix[y * w + x] = pix[(y + sy) * w + x + sx]
            total += len(hit)
        return data[:idx] + bytes(pix) + data[idx + w * h:], total
    return data, 0

for game in ("valve", "bshift", "gearbox"):
    path = os.path.join(ROOT, game, "models", "v_torch.mdl")
    if not os.path.isfile(path):
        continue
    data = open(path, "rb").read()
    new, count = patch(data)
    if count == 0:
        print(f"{path}: already plain")
        continue
    if not os.path.exists(path + ".orig"):
        open(path + ".orig", "wb").write(data)
    open(path + ".new", "wb").write(new)
    os.replace(path + ".new", path)
    print(f"{path}: {count} orange pixels painted over (original: {path}.orig)")
