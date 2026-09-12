# cod1plus PAM

The competitive mod run by the [COD1.6X](https://github.com/cod1plus/client) servers
(`fs_game __rPAMv115b5`): **kvcodPAM** (by kikiii & Maggot, ezya-cod2) with the **rPAM
kvcodPAMext** extension (by reissue_), plus the cod1plus additions that feed FPSChallenge.
Sources are kept exactly as shipped; this repo only adds a reproducible build.

```
kvcodPAM_nolib_v2/    -> zzzzz_kvcodPAM_nolib_v2_REV<N>.pk3        the mod
rPAM_kvcodPAMext/     -> zzzzz_rPAM_kvcodPAMext_v<M>_REV<K>.pk3    the extension (loads after, overrides)
VERSION               revision numbers baked into the pk3 names
build.py              packs both trees into dist/
```

## Build

```sh
python3 build.py                              # -> dist/*.pk3 (deterministic)
python3 build.py --verify /path/to/__rPAMv115b5   # also diff against the pk3s a server runs
```

## Install on a server

1. Copy the two pk3s from `dist/` into the server's `__rPAMv115b5/` folder and delete the
   previous revisions (the engine loads pk3s in alphabetical order; two revisions of the
   same file would both load).
2. Put the same pk3s on the fast-download host: with `sv_pure 1` every client must fetch them.
3. Start the server with `+set fs_game __rPAMv115b5` (see the
   [server module](https://github.com/cod1plus/cod1plushookserver) for the full launch line).

**Bump `VERSION` for every content change.** A client that already holds a pk3 of the same
name never re-downloads it, so a changed pk3 under an old name fails the pure check.

## What cod1plus changed

- `maps/mp/gametypes/cod1plus_fps/cod1plus_fps.gsc` (`kvcodPAM_nolib_v2`): at the end of
  every S&D round, writes one `[STATS_EVENT]` line (round, scores, per-player stats, client
  slot) to the game log. `cod1plus.so` tails that log and forwards the match to FPSChallenge.
- `maps/mp/gametypes/sd.gsc` in both trees: the one-line call to `logStats()`.

Everything else is upstream; `rPAM_kvcodPAMext/_rPAM_kvcodPAMext_changelog.md` is the
upstream history. The stale numbered copies the upstream pk3s carried (`sd.gsc28`,
`_pam.gsc404`, `weapon_british.menu25`, ...) are not part of the tree: the engine never
loaded them.

## Credits

kvcodPAM: kikiii & Maggot (ezya-cod2). rPAM kvcodPAMext: reissue_. Based on the PAM /
vcodPAM lineage of Call of Duty competitive mods. No licence file ships with the upstream
mods; this repository redistributes them unchanged apart from the additions listed above.
