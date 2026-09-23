#!/usr/bin/env python3
"""Generate the streamer radar icons shipped in the kvcod pk3 (gfx/streamer/*.tga).

    python3 tools/gen_streamer_icons.py

radar_dir0..7.tga : a dot with a nose pointing in 8 directions, 0 = up, then clockwise
                    by 45 degrees (the radar picks the one closest to the player's yaw).
radar_dead.tga    : a cross, drawn where a player died this round.
White on a black outline: the hudelem colour tints the white part (team colour), the
outline keeps the icon readable on any background. 32x32 RGBA, uncompressed TGA
(bottom-up rows, what the engine's TGA loader expects).
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "kvcodPAM_nolib_v2", "gfx", "streamer")
SS = 8                  # supersampling factor
SIZE = 32


def draw_dot():
    n = SIZE * SS
    c = n / 2
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r_out, r_in = 10 * SS, 8 * SS
    tip = 15.5 * SS
    # nose (outline then fill), pointing up
    nose_out = [(c - 6.5 * SS, c - 5 * SS), (c + 6.5 * SS, c - 5 * SS), (c, c - tip)]
    nose_in = [(c - 4.5 * SS, c - 5 * SS), (c + 4.5 * SS, c - 5 * SS), (c, c - tip + 3.2 * SS)]
    d.polygon(nose_out, fill=(0, 0, 0, 255))
    d.ellipse([c - r_out, c - r_out, c + r_out, c + r_out], fill=(0, 0, 0, 255))
    d.polygon(nose_in, fill=(255, 255, 255, 255))
    d.ellipse([c - r_in, c - r_in, c + r_in, c + r_in], fill=(255, 255, 255, 255))
    return im


def draw_dead():
    n = SIZE * SS
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    a, b = 7 * SS, n - 7 * SS
    for w, col in ((7 * SS, (0, 0, 0, 255)), (3 * SS, (255, 255, 255, 255))):
        d.line([(a, a), (b, b)], fill=col, width=w)
        d.line([(a, b), (b, a)], fill=col, width=w)
    return im


def save(im, name):
    im = im.resize((SIZE, SIZE), Image.LANCZOS)
    path = os.path.join(OUT, name)
    im.save(path, compression=None)
    back = Image.open(path)
    assert back.size == (SIZE, SIZE) and back.mode == "RGBA", (path, back.size, back.mode)
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    dot = draw_dot()
    for k in range(8):
        # PIL rotates counter-clockwise: -45*k turns the nose clockwise from up
        save(dot.rotate(-45 * k, resample=Image.BICUBIC), "radar_dir%d.tga" % k)
    save(draw_dead(), "radar_dead.tga")
    print("wrote 9 icons to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
