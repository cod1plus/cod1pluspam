#!/usr/bin/env python3
"""publish.py - refresh pk3/ and pam.manifest from the folder a server runs, ready to commit.

    python3 tools/publish.py /path/to/__rPAMv115b5 [--version N]

- copies every *.pk3 of that folder into pk3/ (new or changed only), deletes from pk3/ the
  ones the server no longer has and lists them as `remove` lines so clients drop them too;
- regenerates pam.manifest with the raw.githubusercontent.com URLs of this repo;
- prints the git commands that publish it. Nothing is committed by this script.
The manifest version defaults to the previous one + 1.
"""
import filecmp
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
PK3 = os.path.join(ROOT, "pk3")
MANIFEST = os.path.join(ROOT, "pam.manifest")
URL = "https://raw.githubusercontent.com/cod1plus/cod1pluspam/main/pk3/"


def previous_version():
    try:
        for line in open(MANIFEST, encoding="ascii"):
            m = re.match(r"version\s+(\d+)", line)
            if m:
                return int(m.group(1))
    except OSError:
        pass
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    src = sys.argv[1]
    version = previous_version() + 1
    if "--version" in sys.argv:
        version = int(sys.argv[sys.argv.index("--version") + 1])
    os.makedirs(PK3, exist_ok=True)
    wanted = sorted(n for n in os.listdir(src) if n.lower().endswith(".pk3") and os.path.isfile(os.path.join(src, n)))
    if not wanted:
        print("no .pk3 in %s" % src, file=sys.stderr)
        return 1
    added, updated, removed = [], [], []
    for n in wanted:
        s, d = os.path.join(src, n), os.path.join(PK3, n)
        if not os.path.exists(d):
            shutil.copyfile(s, d); added.append(n)
        elif not filecmp.cmp(s, d, shallow=False):
            shutil.copyfile(s, d); updated.append(n)
    for n in sorted(os.listdir(PK3)):
        if n.lower().endswith(".pk3") and n not in wanted:
            os.remove(os.path.join(PK3, n)); removed.append(n)
    cmd = [sys.executable, os.path.join(HERE, "make_manifest.py"), PK3, "--url", URL, "--version", str(version), "-o", MANIFEST]
    if removed:
        cmd += ["--remove"] + removed
    subprocess.check_call(cmd)
    print("added %d, updated %d, removed %d (version %d)" % (len(added), len(updated), len(removed), version))
    for n in added: print("  + " + n)
    for n in updated: print("  ~ " + n)
    for n in removed: print("  - " + n)
    print("\nnow:\n  git add -A pk3 pam.manifest && git commit -m \"pam.manifest v%d\" && git push" % version)
    return 0


if __name__ == "__main__":
    sys.exit(main())
