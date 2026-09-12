#!/usr/bin/env python3
"""Pack the two mod trees into the pk3s the server loads (dist/), reproducibly.

    python3 build.py                     -> dist/zzzzz_kvcodPAM_nolib_v2_REV<N>.pk3
                                            dist/zzzzz_rPAM_kvcodPAMext_v<M>_REV<K>.pk3
    python3 build.py --verify <dir>      -> also compare every file against the pk3s found
                                            in <dir> (a server's fs_game folder), file by file

Names and revisions come from VERSION. Bump a revision for EVERY content change: sv_pure
clients that already hold a pk3 of the same name will not re-download it.
Deterministic: sorted entries, fixed timestamp, no directory entries, so the same tree
always gives the same bytes.
"""
import argparse
import os
import re
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
DIST = os.path.join(HERE, "dist")
FIXED_TIME = (2020, 1, 1, 0, 0, 0)


def read_version():
    v = {}
    for line in open(os.path.join(HERE, "VERSION"), encoding="ascii"):
        line = line.split("#", 1)[0].strip()
        if "=" in line:
            k, val = line.split("=", 1)
            v[k.strip()] = val.strip()
    return v


def targets(v):
    return [
        ("kvcodPAM_nolib_v2", "zzzzz_kvcodPAM_nolib_v2", f"zzzzz_kvcodPAM_nolib_v2_REV{v['KVCOD_REV']}.pk3"),
        ("rPAM_kvcodPAMext", "zzzzz_rPAM_kvcodPAMext", f"zzzzz_rPAM_kvcodPAMext_v{v['EXT_VER']}_REV{v['EXT_REV']}.pk3"),
    ]


def tree_files(root):
    out = []
    for dp, dirs, files in os.walk(root):
        dirs.sort()
        for f in sorted(files):
            full = os.path.join(dp, f)
            out.append((os.path.relpath(full, root).replace(os.sep, "/"), full))
    return out


def pack(src_dir, out_path):
    files = tree_files(src_dir)
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as z:
        for rel, full in files:
            info = zipfile.ZipInfo(rel, date_time=FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            with open(full, "rb") as fh:
                z.writestr(info, fh.read())
    return len(files)


# A live pk3 may still carry stale copies of scripts saved under a numbered extension
# (sd.gsc28, _pam.gsc404, weapon_british.menu25, ...). The engine only loads the real
# extensions, so those are not part of the source tree and are expected to be missing.
DEAD = re.compile(r"\.(gsc|h|menu|txt)\S+$|\.bat$")


def verify(built, live_dir, stem):
    cands = [f for f in os.listdir(live_dir) if f.startswith(stem) and f.endswith(".pk3")]
    if not cands:
        print(f"  verify: no {stem}*.pk3 in {live_dir}")
        return True
    live_path = os.path.join(live_dir, sorted(cands)[-1])
    live = zipfile.ZipFile(live_path)
    ours = zipfile.ZipFile(built)
    live_names = [n for n in live.namelist() if not n.endswith("/")]
    our_names = set(n for n in ours.namelist() if not n.endswith("/"))
    same = diff = dead = 0
    problems = []
    for n in live_names:
        if n in our_names:
            if live.read(n) == ours.read(n):
                same += 1
            else:
                diff += 1
                problems.append("differs: " + n)
        elif DEAD.search(n):
            dead += 1
        else:
            problems.append("missing: " + n)
    extra = sorted(our_names - set(live_names))
    problems += ["extra: " + n for n in extra]
    print(f"  verify vs {os.path.basename(live_path)}: {same} identical, {diff} differing, "
          f"{dead} stale copies not shipped, {len(extra)} extra")
    for p in problems:
        print("   !! " + p)
    return not problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", metavar="DIR", help="server fs_game folder holding the deployed pk3s")
    a = ap.parse_args()
    v = read_version()
    os.makedirs(DIST, exist_ok=True)
    ok = True
    for src, stem, name in targets(v):
        out = os.path.join(DIST, name)
        n = pack(os.path.join(HERE, src), out)
        print(f"{name}: {n} files, {os.path.getsize(out) // 1024} KB")
        if a.verify:
            ok &= verify(out, a.verify, stem)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
