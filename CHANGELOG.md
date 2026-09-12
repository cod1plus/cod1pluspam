# Changelog (cod1plus revisions)

Upstream history: `rPAM_kvcodPAMext/_rPAM_kvcodPAMext_changelog.md`.

## REV19 / v29_REV20net (unreleased)

- Same content as the deployed REV18 / v28_REV19net, rebuilt from this repository.
- The 370 stale numbered copies (`sd.gsc28`, `_pam.gsc404`, `weapon_british.menu25`, ...)
  and `_create_txt_filenames_cmd.bat` are no longer shipped in the extension pk3
  (396 -> 26 files; the engine never loaded them).

## REV18 / v28_REV19net (deployed)

- `cod1plus_fps.gsc`: `[STATS_EVENT]` gets a 14th per-player field, the client slot, so the
  server module resolves identity from the login uuid instead of the in-game name.
- Headshots and grenade damage in the round stats.

## REV16

- First kvcodPAM-based build with the FPSChallenge stats emitter (`cod1plus_fps.gsc`,
  called from `sd.gsc` at the end of each round).
