logStats()
{
    s = "[STATS_EVENT]";
    s += "r=" + game["roundsplayed"] + ",";
    s += "as=" + game["allies_score"] + ",";
    s += "xs=" + game["axis_score"] + ",";
    s += "rw=" + level.roundwinner + ",";
    ht = "0";
    if (isDefined(game["is_halftime"]) && game["is_halftime"]) ht = "1";
    s += "ht=" + ht + ",";
    bp = "0";
    if (isDefined(level.bombplanted) && level.bombplanted) bp = "1";
    s += "bp=" + bp + ",";
    s += "ps=";
    first = true;
    for (i = 0; i < game["playerstats"].size; i++) {
        ps = game["playerstats"][i];
        if (!isDefined(ps) || !isDefined(ps["deleted"]) || ps["deleted"]) continue;
        if (!first) s += "|";
        first = false;
        s += ps["name"] + ":" + ps["team"] + ":" + ps["kills"] + ":" + ps["deaths"] + ":" + ps["assists"] + ":" +
        ps["damage"] + ":" + ps["grenades"] + ":" + ps["plants"] + ":" + ps["defuses"] + ":" + ps["score"];
        hs = 0;
        if (isDefined(ps["headshots"])) hs = ps["headshots"];
        s += ":" + hs + ":" + ps["grenade_damage"] + ":" + ps["adr"];
        // cod1plus 2026-08-23: field 14 = client slot (entityId) so the .so can
        // resolve identity from the login-uuid table, name-independent. -1 when
        // the row's player already disconnected (his slot may be reused - never
        // trust it). The .so parser is n>=10 backward-compatible.
        slot = -1;
        if (isDefined(ps["isConnected"]) && ps["isConnected"] && isDefined(ps["entityId"]))
            slot = ps["entityId"];
        s += ":" + slot;
    }
    logPrint(s + "\n");
}