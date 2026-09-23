#!/usr/bin/env python3
"""Top-down radar backgrounds for the streamer overlay, drawn from each map's BSP (CoD1 v59).

    python tools/gen_radar_overviews.py <pk3 or folder> [...] [--maps mp_harbor,...] [--size 256]
                                         [--preview out_dir]

Writes kvcodPAM_nolib_v2/gfx/streamer/overview/<map>.jpg and prints the radar window of each
(centre x/y, span) for getStreamerMapConfig: the image IS that window, pixel for pixel.

What is drawn: the world surfaces (model 0) seen from above, without sky / tool surfaces,
and without anything higher than the playable height (spawns and bombsites + 150 units), so
roofs are cut away and interiors show. Floors are shaded by height (low = dark, high = light)
with a light hillshade; walls are dark lines. Static xmodels (crates, vehicles...) are not in
the BSP geometry, so they are not drawn.
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

L_MATERIALS, L_TRISOUPS, L_DRAWVERTS, L_DRAWINDEXES, L_MODELS, L_ENTITIES = 0, 6, 7, 8, 27, 29


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
    return mats, soups, verts, idx, models, ents


def skip_material(name):
    return ("common/" in name or "sky" in name or "caulk" in name or "nodraw" in name
            or "clip" in name or "trigger" in name or "portal" in name or "hint" in name)


def world_triangles(bsp):
    mats, soups, verts, idx, models, ents = bsp
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


def raster(tris, x0, y0, span, n, zcut):
    """Top-down z-buffer of the up-facing triangles below zcut + a wall mask."""
    height = np.full((n, n), -1e9)
    shade = np.zeros((n, n))
    walls = np.zeros((n, n), bool)
    water = np.zeros((n, n), bool)
    px = span / n
    for tv in tris:
        t = tv[:, :3]
        nrm = tv[:, 3:6].mean(0)                    # the BSP's own normals: winding-proof
        is_water = tv[0, 6] > 0.5
        ln = np.linalg.norm(nrm)
        if ln < 1e-6:
            continue
        nrm /= ln
        zmin = t[:, 2].min()
        if zmin > zcut:
            continue
        # screen coords: x right, y down (world +Y up)
        sx = (t[:, 0] - x0) / px
        sy = (y0 + span - t[:, 1]) / px
        ix0, ix1 = int(max(0, np.floor(sx.min()))), int(min(n - 1, np.ceil(sx.max())))
        iy0, iy1 = int(max(0, np.floor(sy.min()))), int(min(n - 1, np.ceil(sy.max())))
        if ix1 < ix0 or iy1 < iy0:
            continue
        if abs(nrm[2]) < 0.35:                      # wall: mark its footprint
            if t[:, 2].max() < zcut - 400:
                continue
            gx, gy = np.meshgrid(np.arange(ix0, ix1 + 1) + 0.5, np.arange(iy0, iy1 + 1) + 0.5)
            # distance of pixel centres to the wall's footprint segment
            p = np.stack([sx, sy], 1)
            best = np.full(gx.shape, 1e9)
            for k in range(3):
                pa, pb = p[k], p[(k + 1) % 3]
                d = pb - pa
                l2 = d @ d
                if l2 < 1e-9:
                    continue
                tt = np.clip(((gx - pa[0]) * d[0] + (gy - pa[1]) * d[1]) / l2, 0, 1)
                best = np.minimum(best, np.hypot(gx - pa[0] - tt * d[0], gy - pa[1] - tt * d[1]))
            walls[iy0:iy1 + 1, ix0:ix1 + 1] |= best < 0.7
            continue
        if nrm[2] < 0.35:                            # facing down (ceilings)
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
        ok = inside & (z <= zcut)
        sub = height[iy0:iy1 + 1, ix0:ix1 + 1]
        upd = ok & (z > sub)
        sub[upd] = z[upd]
        sh = shade[iy0:iy1 + 1, ix0:ix1 + 1]
        light = np.dot(nrm, np.array([-0.45, 0.45, 0.77]))
        sh[upd] = light
        wa = water[iy0:iy1 + 1, ix0:ix1 + 1]
        wa[upd] = is_water
    return height, shade, walls, water


def render(bsp, size, name):
    mats, soups, verts, idx, models, ents = bsp
    tris = world_triangles(bsp)
    pts = play_points(ents)
    if len(pts) == 0:
        raise SystemExit("%s: no spawn points" % name)
    zcut = pts[:, 2].max() + 150
    zlow = pts[:, 2].min() - 300

    # window: the play area = spawns + bombsites, with a margin (the world around it, sea,
    # countryside, skybox terrain, is not part of the radar)
    lo, hi = pts[:, :2].min(0), pts[:, :2].max(0)
    pad = max(700.0, 0.22 * float((hi - lo).max()))
    lo, hi = lo - pad, hi + pad
    centre = (lo + hi) / 2
    span = float((hi - lo).max())
    x0, y0 = centre[0] - span / 2, centre[1] - span / 2

    n = size * 2                                     # supersampled, downscaled at the end
    height, shade, walls, water = raster(tris, x0, y0, span, n, zcut)

    has = height > -1e8
    land = has & ~water
    hmin, hmax = np.percentile(height[land], 2), np.percentile(height[land], 98)
    hn = np.clip((height - hmin) / max(1.0, hmax - hmin), 0, 1)
    base = 0.30 + 0.45 * hn + 0.20 * np.clip(shade, 0, 1)
    img = np.zeros((n, n, 3))
    tint = np.array([0.80, 0.86, 0.92])             # cool grey-blue
    img[has] = (base[has, None] * tint)
    wet = has & water
    img[wet] = np.array([0.10, 0.22, 0.36]) + 0.10 * shade[wet, None]
    img[walls] = [0.06, 0.07, 0.09]
    img[~has & ~walls] = [0.03, 0.035, 0.045]
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB")
    im = im.resize((size, size), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 60, 2))
    return im, (float(centre[0]), float(centre[1]), span)


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
            im, (cx, cy, span) = render(bsp, a.size, name)
        except (SystemExit, Exception) as e:
            print("%-24s skipped: %s" % (name, e))
            continue
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=88)
        data = buf.getvalue()
        image = seen.setdefault(data, name)          # map variants (_a/_b/_r...) share one file
        if image == name:
            open(os.path.join(out_dir, name + ".jpg"), "wb").write(data)
        table.append((name, image, cx, cy, span, os.path.basename(p)))
        print("%-24s %-40s centre (%.0f, %.0f) span %.0f  %s" % (
            name, os.path.basename(p), cx, cy, span,
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
        "	switch (mapname)",
        "	{",
    ]
    for name, image, cx, cy, span, src in sorted(table):
        lines.append('		case "%s": return overview("%s", %.0f, %.0f, %.0f);	// %s' % (name, image, cx, cy, span, src))
    lines += [
        "	}",
        "	return undefined;",
        "}",
        "",
        "overview(name, x, y, span)",
        "{",
        "	c = spawnstruct();",
        '	c.image = "gfx/streamer/overview/" + name + ".jpg";',
        "	c.x = x;",
        "	c.y = y;",
        "	c.span = span;",
        "	c.up = 90;",
        "	return c;",
        "}",
        "",
    ]
    open(path, "w", newline="\r\n").write("\n".join(lines))
    print("wrote", path, len(table), "maps")


if __name__ == "__main__":
    main()
