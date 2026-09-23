#!/usr/bin/env python3
"""Top-down radar backgrounds for the streamer overlay, drawn from each map's BSP (CoD1 v59).

    python tools/gen_radar_overviews.py <pk3 or folder> [...] [--maps mp_harbor,...] [--size 256]
                                         [--preview out_dir] [--gsc out.gsc]

Writes kvcodPAM_nolib_v2/gfx/streamer/overview/<map>.jpg and (--gsc) the table of the radar
window of each image for getStreamerMapConfig: the image IS that window, pixel for pixel.

What is drawn: the world surfaces (model 0) seen from above, without sky / tool surfaces and
without anything higher than the playable height (spawns and bombsites + 150 units), so roofs
are cut away and interiors show. Floors are shaded by height with a light hillshade, walls are
dark lines, water is blue. Static xmodels (crates, vehicles...) are not in the BSP geometry.

Framing: the part of the map players can actually reach, as a rectangle of the map's shape
(the game draws the 256x256 image back at that shape, up to 176x128 on screen). From every spawn point and bombsite
the floor is flood-filled, stopped by walls and by player-clip brushes (the invisible walls,
contents bit 0x10000) wherever they stand at body height above the local floor (steps and door
lintels do not stop it), and by water. The image is framed on that area; what stays outside it
inside the frame is drawn darker.
"""
import argparse
import io
import os
import re
import struct
import sys
import zipfile

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "kvcodPAM_nolib_v2", "gfx", "streamer", "overview")

L_MATERIALS, L_BRUSHSIDES, L_BRUSHES, L_TRISOUPS, L_DRAWVERTS, L_DRAWINDEXES = 0, 3, 4, 6, 7, 8
L_MODELS, L_ENTITIES = 27, 29
CONTENTS_PLAYERCLIP = 0x10000
BODY_LOW, BODY_HIGH = 18.0, 56.0      # above the floor: lower = a step, higher = a lintel
MAX_STEP = 44.0                       # height change between two neighbouring floor pixels


def load_bsp(data):
    assert data[:4] == b"IBSP" and struct.unpack_from("<i", data, 4)[0] == 59, "not a CoD1 v59 bsp"
    lumps = []
    for i in range(31):
        ln, off = struct.unpack_from("<ii", data, 8 + 8 * i)
        lumps.append(data[off:off + ln])
    m = lumps[L_MATERIALS]
    mats = [(m[i:i + 64].split(b"\0")[0].decode("latin1").lower(),) + struct.unpack_from("<II", m, i + 64)
            for i in range(0, len(m), 72)]
    ts = lumps[L_TRISOUPS]
    soups = [struct.unpack_from("<2HiHHi", ts, i) for i in range(0, len(ts), 16)]  # mat, lm, firstVert, nVerts, nIdx, firstIdx
    dv = np.frombuffer(lumps[L_DRAWVERTS], dtype="<f4").reshape(-1, 11)
    verts = dv[:, [0, 1, 2, 7, 8, 9]].astype(np.float64)       # xyz + stored normal
    idx = np.frombuffer(lumps[L_DRAWINDEXES], dtype="<u2").astype(np.int64)
    mo = lumps[L_MODELS]
    models = [struct.unpack_from("<6f6i", mo, i) for i in range(0, len(mo), 48)]
    text = lumps[L_ENTITIES].split(b"\0")[0].decode("latin1")
    ents = []
    for block in re.findall(r"\{(.*?)\}", text, re.S):
        ents.append(dict(re.findall(r'"([^"]*)"\s*"([^"]*)"', block)))

    # player-clip brushes of the world: their 6 first sides are the AABB (min/max as floats)
    br = lumps[L_BRUSHES]
    brushes = [struct.unpack_from("<HH", br, i) for i in range(0, len(br), 4)]
    side_start = np.concatenate([[0], np.cumsum([b[0] for b in brushes])]).astype(np.int64)
    sides = lumps[L_BRUSHSIDES]
    first_brush, n_brush = models[0][10], models[0][11]
    clips = []
    for b in range(first_brush, first_brush + n_brush):
        nsides, mat = brushes[b]
        if nsides < 6 or not (mats[mat][2] & CONTENTS_PLAYERCLIP):
            continue
        s0 = side_start[b]
        box = [struct.unpack_from("<f", sides, (s0 + k) * 8)[0] for k in range(6)]  # minx maxx miny maxy minz maxz
        clips.append(box + [nsides])
    return {"mats": mats, "soups": soups, "verts": verts, "idx": idx, "models": models,
            "ents": ents, "clips": np.array(clips) if clips else np.zeros((0, 7))}


def skip_material(name):
    return ("common/" in name or "sky" in name or "caulk" in name or "nodraw" in name
            or "clip" in name or "trigger" in name or "portal" in name or "hint" in name)


def world_triangles(bsp):
    mats, soups, verts, idx, models = bsp["mats"], bsp["soups"], bsp["verts"], bsp["idx"], bsp["models"]
    first, count = models[0][6], models[0][7]
    tris = []
    for s in soups[first:first + count]:
        mat, lm, fv, nv, ni, fi = s
        if skip_material(mats[mat][0]):
            continue
        ii = idx[fi:fi + ni].reshape(-1, 3) + fv
        tv = verts[ii]
        water = 1.0 if ("water" in mats[mat][0] or "liquid" in mats[mat][0]) else 0.0
        flag = np.full((tv.shape[0], 3, 1), water)
        tris.append(np.concatenate([tv, flag], 2))
    return np.concatenate(tris) if tris else np.zeros((0, 3, 7))   # [tri][vertex][x y z nx ny nz water]


def play_points(ents):
    pts = []
    for e in ents:
        cn = e.get("classname", "")
        if cn.startswith("mp_") and ("spawn" in cn) or e.get("targetname", "") in ("bombzone_A", "bombzone_B"):
            if "origin" in e:
                pts.append([float(v) for v in e["origin"].split()])
    return np.array(pts) if pts else np.zeros((0, 3))


class Grid:
    """A window of the world (lo..hi), square pixels of px units, x right, y down (world +Y up)."""
    def __init__(self, lo, hi, px):
        self.px = px
        self.nx = max(8, int(np.ceil((hi[0] - lo[0]) / px)))
        self.ny = max(8, int(np.ceil((hi[1] - lo[1]) / px)))
        cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
        self.x0 = cx - self.nx * px / 2
        self.y0 = cy - self.ny * px / 2
        self.span_x, self.span_y = self.nx * px, self.ny * px

    def to_px(self, x, y):
        return (x - self.x0) / self.px, (self.y0 + self.span_y - y) / self.px

    def clip_rect(self, sx, sy):
        ix0, ix1 = int(max(0, np.floor(min(sx)))), int(min(self.nx - 1, np.ceil(max(sx))))
        iy0, iy1 = int(max(0, np.floor(min(sy)))), int(min(self.ny - 1, np.ceil(max(sy))))
        return ix0, ix1, iy0, iy1


def raster(tris, clips, g, zcut):
    """Pass 1 floors: height / shade / water. Pass 2 walls: drawn lines + body-height blockers.
    Pass 3 player clips: body-height blockers."""
    shape = (g.ny, g.nx)
    height = np.full(shape, -1e9)
    shade = np.zeros(shape)
    water = np.zeros(shape, bool)
    walls = np.zeros(shape, bool)
    block = np.zeros(shape, bool)

    nrm = tris[:, :, 3:6].mean(1)
    nl = np.linalg.norm(nrm, axis=1)
    ok = nl > 1e-6
    nrm[ok] /= nl[ok, None]
    zmin_all = tris[:, :, 2].min(1)
    floor_ids = np.where(ok & (nrm[:, 2] >= 0.35) & (zmin_all <= zcut))[0]
    wall_ids = np.where(ok & (np.abs(nrm[:, 2]) < 0.35) & (zmin_all <= zcut))[0]
    light_dir = np.array([-0.45, 0.45, 0.77])

    for i in floor_ids:
        t = tris[i, :, :3]
        sx, sy = g.to_px(t[:, 0], t[:, 1])
        ix0, ix1, iy0, iy1 = g.clip_rect(sx, sy)
        if ix1 < ix0 or iy1 < iy0:
            continue
        gx, gy = np.meshgrid(np.arange(ix0, ix1 + 1) + 0.5, np.arange(iy0, iy1 + 1) + 0.5)
        (xa, ya), (xb, yb), (xc, yc) = zip(sx, sy)
        den = (yb - yc) * (xa - xc) + (xc - xb) * (ya - yc)
        if abs(den) < 1e-12:
            continue
        w0 = ((yb - yc) * (gx - xc) + (xc - xb) * (gy - yc)) / den
        w1 = ((yc - ya) * (gx - xc) + (xa - xc) * (gy - yc)) / den
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        if not inside.any():
            continue
        z = w0 * t[0, 2] + w1 * t[1, 2] + w2 * t[2, 2]
        sub = height[iy0:iy1 + 1, ix0:ix1 + 1]
        upd = inside & (z <= zcut) & (z > sub)
        sub[upd] = z[upd]
        shade[iy0:iy1 + 1, ix0:ix1 + 1][upd] = float(np.dot(nrm[i], light_dir))
        water[iy0:iy1 + 1, ix0:ix1 + 1][upd] = tris[i, 0, 6] > 0.5

    for i in wall_ids:
        t = tris[i, :, :3]
        sx, sy = g.to_px(t[:, 0], t[:, 1])
        ix0, ix1, iy0, iy1 = g.clip_rect(sx, sy)
        if ix1 < ix0 or iy1 < iy0:
            continue
        gx, gy = np.meshgrid(np.arange(ix0, ix1 + 1) + 0.5, np.arange(iy0, iy1 + 1) + 0.5)
        best = np.full(gx.shape, 1e9)
        for k in range(3):
            pa = np.array([sx[k], sy[k]])
            pb = np.array([sx[(k + 1) % 3], sy[(k + 1) % 3]])
            d = pb - pa
            l2 = d @ d
            if l2 < 1e-9:
                continue
            tt = np.clip(((gx - pa[0]) * d[0] + (gy - pa[1]) * d[1]) / l2, 0, 1)
            best = np.minimum(best, np.hypot(gx - pa[0] - tt * d[0], gy - pa[1] - tt * d[1]))
        foot = best < 0.7
        zlo, zhi = t[:, 2].min(), t[:, 2].max()
        if zhi >= zcut - 400:
            walls[iy0:iy1 + 1, ix0:ix1 + 1] |= foot
        h = height[iy0:iy1 + 1, ix0:ix1 + 1]
        block[iy0:iy1 + 1, ix0:ix1 + 1] |= foot & (zlo < h + BODY_HIGH) & (zhi > h + BODY_LOW)

    for b in clips:
        minx, maxx, miny, maxy, minz, maxz, nsides = b
        if nsides > 6 and min(maxx - minx, maxy - miny) >= 96:
            continue      # a slanted clip brush: its AABB would block far more than the brush
        sx, sy = g.to_px(np.array([minx, maxx]), np.array([miny, maxy]))
        ix0, ix1, iy0, iy1 = g.clip_rect(sx, sy)
        if ix1 < ix0 or iy1 < iy0:
            continue
        h = height[iy0:iy1 + 1, ix0:ix1 + 1]
        block[iy0:iy1 + 1, ix0:ix1 + 1] |= (minz < h + BODY_HIGH) & (maxz > h + BODY_LOW)

    return height, shade, water, walls, block


def reachable(height, water, block, seeds):
    """Flood fill of the walkable floor from the seed pixels (4-neighbours, steps <= MAX_STEP)."""
    passable = (height > -1e8) & ~water & ~block
    reach = np.zeros_like(passable)
    for (x, y) in seeds:
        reach[y, x] = passable[y, x]
    while True:
        grown = reach.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            src = np.roll(reach, (dy, dx), (0, 1))
            hs = np.roll(height, (dy, dx), (0, 1))
            grown |= src & passable & (np.abs(height - hs) <= MAX_STEP)
        # np.roll wraps around: forget what came through the image border
        grown[0, :] &= reach[0, :] | passable[0, :]
        if (grown == reach).all():
            return reach
        reach = grown


def seed_pixels(pts, height, g):
    seeds = []
    for x, y, z in pts:
        cx, cy = g.to_px(x, y)
        cx, cy = int(cx), int(cy)
        best = None
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                px, py = cx + dx, cy + dy
                if 0 <= px < g.nx and 0 <= py < g.ny and z - 100 <= height[py, px] <= z + 24:
                    d = dx * dx + dy * dy
                    if best is None or d < best[0]:
                        best = (d, px, py)
        if best:
            seeds.append((best[1], best[2]))
    return seeds


def dilate(mask, r):
    out = mask.copy()
    for _ in range(r):
        m = out.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m |= np.roll(out, (dy, dx), (0, 1))
        out = m
    return out


RADAR_W, RADAR_H = 176.0, 128.0          # largest radar box on the streamer's screen


def render(bsp, size, name):
    """Returns the image (size x size, stretched back to the window's shape by the game)
    and the window (centre x, centre y, width, height) in world units."""
    tris = world_triangles(bsp)
    pts = play_points(bsp["ents"])
    if len(pts) == 0:
        raise SystemExit("%s: no spawn points" % name)
    zcut = pts[:, 2].max() + 150
    work = size * 2                                  # supersampling of the long side

    # 1. loose frame around the spawns and bombsites, where the reachable area is measured
    s_lo, s_hi = pts[:, :2].min(0), pts[:, :2].max(0)
    pad = max(1200.0, 0.35 * float((s_hi - s_lo).max()))
    lo, hi = s_lo - pad, s_hi + pad
    g = Grid(lo, hi, float((hi - lo).max()) / work)
    height, shade, water, walls, block = raster(tris, bsp["clips"], g, zcut)
    reach = reachable(height, water, block, seed_pixels(pts, height, g))

    # 2. tight frame: the reachable area (and every spawn / bombsite), small margin.
    #    Never wider than the spawn-based frame: a map whose fences are xmodels (not in the
    #    BSP) lets the fill leak into the countryside; thin leaks are trimmed by percentiles.
    s_pad = max(700.0, 0.22 * float((s_hi - s_lo).max()))
    lo, hi = s_lo - s_pad, s_hi + s_pad
    ys, xs = np.nonzero(reach)
    if len(xs) > 50:
        rx0 = g.x0 + np.percentile(xs, 1) * g.px
        rx1 = g.x0 + (np.percentile(xs, 99) + 1) * g.px
        ry1 = g.y0 + g.span_y - np.percentile(ys, 1) * g.px
        ry0 = g.y0 + g.span_y - (np.percentile(ys, 99) + 1) * g.px
        lo = np.maximum(lo, [rx0, ry0])
        hi = np.minimum(hi, [rx1, ry1])
    lo = np.minimum(lo, s_lo - 250)
    hi = np.maximum(hi, s_hi + 250)
    size_xy = hi - lo
    margin = 0.03 * float(size_xy.max())
    lo, hi = lo - margin, hi + margin
    # keep the shape within 3:1 either way (a very thin radar is unreadable)
    size_xy = hi - lo
    c = (lo + hi) / 2
    size_xy = np.maximum(size_xy, size_xy[::-1] / 3.0)
    lo, hi = c - size_xy / 2, c + size_xy / 2

    g = Grid(lo, hi, float(size_xy.max()) / work)
    height, shade, water, walls, block = raster(tris, bsp["clips"], g, zcut)
    reach = reachable(height, water, block, seed_pixels(pts, height, g))
    play = dilate(reach, 3)

    has = height > -1e8
    land = has & ~water
    ref = land & play if (land & play).sum() > 100 else land
    hmin, hmax = np.percentile(height[ref], 2), np.percentile(height[ref], 98)
    hn = np.clip((height - hmin) / max(1.0, hmax - hmin), 0, 1)
    base = 0.30 + 0.45 * hn + 0.20 * np.clip(shade, 0, 1)
    img = np.zeros((g.ny, g.nx, 3))
    tint = np.array([0.80, 0.86, 0.92])             # cool grey-blue
    img[has] = (base[has, None] * tint)
    wet = has & water
    img[wet] = np.array([0.10, 0.22, 0.36]) + 0.10 * shade[wet, None]
    img[walls] = [0.06, 0.07, 0.09]
    img[~has & ~walls] = [0.03, 0.035, 0.045]
    if play.sum() > 100:
        img[~play] *= 0.35                           # out of reach: darker
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB")
    # always size x size: the game draws it back at the window's shape (setShader w, h)
    im = im.resize((size, size), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 60, 2))
    # the radar's frame is part of the image (a menu cannot follow each map's shape)
    px = np.asarray(im).copy()
    px[:2, :], px[-2:, :], px[:, :2], px[:, -2:] = 150, 150, 150, 150
    im = Image.fromarray(px)
    return im, (float(g.x0 + g.span_x / 2), float(g.y0 + g.span_y / 2), g.span_x, g.span_y)


def find_bsps(sources):
    found = {}
    for src in sources:
        paths = [src] if src.lower().endswith(".pk3") else \
            [os.path.join(src, f) for f in sorted(os.listdir(src)) if f.lower().endswith(".pk3")]
        for p in paths:
            z = zipfile.ZipFile(p)
            for n in z.namelist():
                m = re.match(r"maps/mp/([^/]+)\.bsp$", n, re.I)
                if m:
                    found[m.group(1).lower()] = (p, n)      # later pk3 wins, like the engine
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sources", nargs="+")
    ap.add_argument("--maps", default="")
    ap.add_argument("--size", type=int, default=256)
    ap.add_argument("--preview", default="")
    ap.add_argument("--gsc", default="", help="write the generated map table (GSC) here")
    a = ap.parse_args()
    bsps = find_bsps(a.sources)
    wanted = [m.strip().lower() for m in a.maps.split(",") if m.strip()] or sorted(bsps)
    out_dir = a.preview or OUT
    os.makedirs(out_dir, exist_ok=True)
    table = []
    seen = {}                                        # image bytes -> first map that has them
    for name in wanted:
        if name not in bsps:
            print("%-24s not found" % name)
            continue
        p, n = bsps[name]
        try:
            bsp = load_bsp(zipfile.ZipFile(p).read(n))
            im, (cx, cy, span, span_y) = render(bsp, a.size, name)
        except (SystemExit, Exception) as e:
            print("%-24s skipped: %s" % (name, e))
            continue
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=88)
        data = buf.getvalue()
        image = seen.setdefault(data, name)          # map variants (_a/_b/_r...) share one file
        if image == name:
            open(os.path.join(out_dir, name + ".jpg"), "wb").write(data)
        table.append((name, image, cx, cy, span, span_y, os.path.basename(p)))
        print("%-24s %-40s centre (%.0f, %.0f) size %.0f x %.0f  %s" % (
            name, os.path.basename(p), cx, cy, span, span_y,
            "%d bytes" % len(data) if image == name else "= " + image + ".jpg"))
    if a.gsc:
        write_gsc(a.gsc, table)


def write_gsc(path, table):
    """The radar window of every generated image: the in-game radar must use exactly this
    window, or the dots do not land on the drawing."""
    lines = [
        "// GENERATED by tools/gen_radar_overviews.py - do not edit by hand, re-run the tool.",
        "// Radar background of each map (top-down view of its BSP) and the exact world window",
        "// that image covers. Used by _streamer_radar.gsc::getStreamerMapConfig.",
        "",
        "getOverview(mapname)",
        "{",
        "\tswitch (mapname)",
        "\t{",
    ]
    for name, image, cx, cy, span, span_y, src in sorted(table):
        lines.append('\t\tcase "%s": return overview("%s", %.0f, %.0f, %.0f, %.0f);\t// %s' % (name, image, cx, cy, span, span_y, src))
    lines += [
        "\t}",
        "\treturn undefined;",
        "}",
        "",
        "overview(name, x, y, span, spanY)",
        "{",
        "\tc = spawnstruct();",
        '\tc.image = "gfx/streamer/overview/" + name + ".jpg";',
        "\tc.x = x;",
        "\tc.y = y;",
        "\tc.span = span;\t\t// world width of the image",
        "\tc.spanY = spanY;\t// world height of the image",
        "\tc.up = 90;",
        "\treturn c;",
        "}",
        "",
    ]
    open(path, "w", newline="\r\n").write("\n".join(lines))
    print("wrote", path, len(table), "maps")


if __name__ == "__main__":
    main()
