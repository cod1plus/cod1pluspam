# Changelog (cod1plus revisions)

Upstream history: `rPAM_kvcodPAMext/_rPAM_kvcodPAMext_changelog.md`.

## REV19 / v29_REV20net (unreleased)

- Rebuilt from this repository (base: the deployed REV18 / v28_REV19net).
- The 370 stale numbered copies (`sd.gsc28`, `_pam.gsc404`, `weapon_british.menu25`, ...)
  and `_create_txt_filenames_cmd.bat` are no longer shipped in the extension pk3
  (396 -> 26 files; the engine never loaded them).
- Streamer mode, caster overlay (CS:GO style):
  - one server-side gate, `_streamer::isStreamerModeEnabled(player)`, for the whole overlay
    and every `streamersystem_*` menu response (a hand-typed `mr` command is ignored);
  - anti-ghosting (`scr_streamer_lock`, default 1): who played the live match cannot become
    streamer on that map, the streamer cannot join a team while the match is live;
    optional `scr_streamer_allow` list (names or GUIDs, comma separated);
  - 5v5 top bar replacing the side bars: fixed slots for the whole map (no reordering, dead
    = grey, alive again next round), exact HP + 10-step bar, weapon, grenades, followed
    player framed, team names / score / round state in the middle;
  - radar top-left (`_streamer_radar.gsc`, key M, `scr_streamer_radar`): exact positions,
    facing, dead crosses, bombsites and planted bomb; window from
    `getStreamerMapConfig(mapname)` / `scr_streamer_radar_<map>` or fitted automatically;
  - XRAY rewritten (it never displayed: the projection read the angles of a hudelem):
    one silhouette per enemy, fixed hudelem pool, key V for 4:3 / 16:9 screens,
    `scr_streamer_xray`; the view pitch is not available to scripts (level view assumed).
  - `tools/gen_streamer_icons.py` generates the radar icons (`gfx/streamer/*.tga`).
  - radar background = a top-down drawing of each map made from its BSP
    (`tools/gen_radar_overviews.py` -> `gfx/streamer/overview/*.jpg`, 30 images / 38 maps,
    468 KB, and `_streamer_radar_maps.gsc` with the exact window of each drawing).
  - the streamer menu file has 6 menus (was 8): the UI loads 64 at most and silently drops
    the rest (the "ingame" menu was lost with the 1.6X client); top bar cvars are spread over
    ticks (reliable command overflow when joining the streamer team).

## REV18 / v28_REV19net (deployed)

- `cod1plus_fps.gsc`: `[STATS_EVENT]` gets a 14th per-player field, the client slot, so the
  server module resolves identity from the login uuid instead of the in-game name.
- Headshots and grenade damage in the round stats.

## REV16

- First kvcodPAM-based build with the FPSChallenge stats emitter (`cod1plus_fps.gsc`,
  called from `sd.gsc` at the end of each round).
