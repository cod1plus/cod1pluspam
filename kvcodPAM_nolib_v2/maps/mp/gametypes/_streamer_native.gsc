/*
	_streamer_native.gsc - data feed for the 1.6X client's native streamer overlay

	The 1.6X client (mss32.dll, streamer_hud.cpp) draws the caster overlay itself with real
	fonts and images, and an XRAY projected with the streamer's true camera (pitch, zoom, FOV:
	things a script cannot see). It announces itself with the menu response
	"streamersystem_native" (cmd mr <sv_serverid> -1 streamersystem_native). From then on, for
	that streamer only, the PAM stops drawing its radar and XRAY hudelems and sends instead:

	ui_streamersystem_radarwin  once per round:
		"<image or -> <centre x> <centre y> <width> <height> <up yaw> <A x> <A y> <B x> <B y>"
		(the radar window of the map drawing, same as getStreamerMapConfig; "-" = no site)
	ui_streamersystem_feed      10 times a second, only when it changed:
		"T<seconds>|R<radar on>|X<xray on>|C<camera slot or -1>|B<x,y,z or ->|E<clock>|<slot 0>|...|<slot 9>"
		clock = "-" or <kind><tenths of a second left>, kind r = round, s = strat time, b = bomb
		slot = "-" (empty) or "<alive 1/0>,<x>,<y>,<z>,<yaw>,<stance s/c/p>,<visible 1/0>,<weapon>,<round kills>"
		Header fields start with a capital letter, slots with a digit or "-": the client reads
		them by that, so a field can be added without breaking an older client.
		CS2-style broadcast fields (2026-11-22):
		N<round>.<rounds in the match>   P<1 while a killcam replays>
		  P1.<slot of the player replayed>.<server time shown first>.<length>.<played so far>
		  (tenths of a second; LAN look 2026-11-22: the replay's timeline)
		Z1 = the map is over (the client shows its winning screen, the menu stays open)
		K entries end with .<server time of the kill, tenths> (the replay's kill marks)
		slot: one more field at the end: <rounds he was the player of>
		slot (REV31, 2026-11-23): two more: <hits he made>,<1 if the last one was on the head>
		  (the client's hitmarker: the followed player's count going up)
		S<n> (REV33): sides switched n times since the match began; the H entries are written in the
		  sides of the first half (a = the team that began as allies), the client recolours them
		  with the parity of n: every round takes the colour its winner wears NOW (enzo 2026-11-23:
		  after the switch the history mixed the colours of both teams)
		Q<kind>.<team>.<seconds left>.<ready>.<players>.<timeouts left allies>.<axis> (REV32): a
		  ready-up is on - kind t timeout, h half-time, r ready-up; team a/x/- who called the
		  timeout; seconds left before it resumes by itself (-1 none); -1 timeouts = not allowed
	ui_streamersystem_event   scr_streamer_text1..4, "|" between them (the event strip)
	ui_streamersystem_series  the maps already played: "<map>.<score left>.<score right>;..."
		K<id>.<attacker slot>.<victim slot>.<weapon without _mp>.<headshot>/...  every kill of the round
		W<a|x|d>.<e|b|d|t>.<mvp slot>.<kills>.<headshots>.<damage>  once the round is over
		H<half round>:<winner><reason>.<winner><reason>...  the rounds of the match so far
		slot (more fields): ...,<round kills>,<kills>,<deaths>,<adr>,<assists>,<headshots>,<plants>,<defuses>,
		      <grenades>,<second primary>,<pistol>,<clip>,<reserve>   (every weapon name without _mp)
		N, K, W and H go in their own cvar, ui_streamersystem_events (changed only when they change)
		(winner a allies / x axis / d draw; reason e elimination / b bomb / d defused / t time)
		Slots are the top bar's (0-4 left team, 5-9 right team). A dead player keeps the place
		where he died. "visible" = in the camera's line of sight (head or pelvis), refreshed
		every 0.3 s. weapon = the weapon in hand (its file name, "-" if none): the client reads
		its kill icon out of the weapon file. T changes every second so the client can tell a
		live feed from a stale one.

	The top bar keeps its cvars (ui_streamersystem_team*_player*_*): the client reads them
	and hides the PAM's top bar menus. A client without native overlay never sends the
	response and keeps the PAM overlay.
*/

isNative(player)
{
	return isDefined(player.pers["streamerSystem_native"]) && player.pers["streamerSystem_native"];
}

/*
	Round bookkeeping of the CS2-style broadcast (called from _streamer::init, every round):
	the kill feed (last 5 kills, ids kept across rounds in game[] so the client never mixes
	two kills), and per player the kills / headshots / damage of the round (the MVP).
*/
init()
{
	if (!isDefined(game["streamerNative_killId"]))
		game["streamerNative_killId"] = 0;
	// the match's rounds so far ("xe.ab..."), cleared when a new match starts
	if (!isDefined(game["streamerNative_history"]) || !isDefined(game["roundsplayed"]) || game["roundsplayed"] == 0)
		game["streamerNative_history"] = "";
	level.streamerNative_kills = [];
	level.streamerNative_rk = [];
	level.streamerNative_rhs = [];
	level.streamerNative_rdmg = [];
	level.streamerNative_hits = [];
	level.streamerNative_hitHead = [];
	level.streamerNative_result = undefined;

	// a new match: the round MVP counts start again
	if (!isDefined(game["roundsplayed"]) || game["roundsplayed"] == 0)
	{
		players = getentarray("player", "classname");
		for (i = 0; i < players.size; i++)
			players[i].pers["streamerNative_mvps"] = 0;
	}

	maps\mp\gametypes\global\_global::addEventListener("onPlayerKilled",  ::onPlayerKilled);
	maps\mp\gametypes\global\_global::addEventListener("onPlayerDamaged", ::onPlayerDamaged);

	if (level.gametype == "sd")
		level thread watchRoundEnd();
}

// the result of each real round goes into the match history, streamer or not
watchRoundEnd()
{
	for (;;)
	{
		wait level.fps_multiplier * 0.1;
		if (!isDefined(level.roundended) || !level.roundended || !isDefined(level.roundwinner))
			continue;
		if ((isDefined(level.in_readyup) && level.in_readyup) || (isDefined(level.in_bash) && level.in_bash))
			return;
		if (!isDefined(level.streamerNative_result))
			computeResult();
		r = level.streamerNative_result;                      // "<w>.<r>"
		w = getsubstr2(r, 0, 1);
		// in the sides of the first half (S field)
		if (isDefined(game["streamerNative_swaps"]) && game["streamerNative_swaps"] % 2 == 1)
		{
			if (w == "a")
				w = "x";
			else if (w == "x")
				w = "a";
		}
		entry = w + getsubstr2(r, 2, 3);                      // "<w><r>"
		if (game["streamerNative_history"] != "")
			game["streamerNative_history"] += ".";
		game["streamerNative_history"] += entry;
		return;
	}
}

getsubstr2(s, from, to)
{
	return maps\mp\gametypes\global\_global::getsubstr(s, from, to);
}

// "H<half round>:<w><r>.<w><r>..." (sd)
feedHistory()
{
	if (level.gametype != "sd" || !isDefined(game["streamerNative_history"]))
		return "H-";
	half = 0;
	if (isDefined(level.halfround) && level.halfround > 0)
		half = level.halfround;
	swaps = 0;
	if (isDefined(game["streamerNative_swaps"]))
		swaps = game["streamerNative_swaps"];
	return "S" + swaps + "|H" + half + ":" + game["streamerNative_history"];
}

onPlayerKilled(eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, timeOffset, deathAnimDuration)
{
	game["streamerNative_killId"]++;
	k = spawnstruct();
	k.id = game["streamerNative_killId"];
	k.victim = self;
	k.attacker = undefined;
	if (isDefined(eAttacker) && isPlayer(eAttacker) && eAttacker != self)
		k.attacker = eAttacker;
	// the auto camera follows the killer when the followed player dies (_streamer::spectating_loop)
	self.streamerAuto_killer = k.attacker;
	self.streamerAuto_killedAt = getTime();
	// weapon file name without its "_mp" (the client puts it back): the feed stays short
	k.weapon = "-";
	if (isDefined(sWeapon) && sWeapon != "" && sWeapon != "none")
	{
		k.weapon = sWeapon;
		if (k.weapon.size > 3 && maps\mp\gametypes\global\_global::getsubstr(k.weapon, k.weapon.size - 3, k.weapon.size) == "_mp")
			k.weapon = maps\mp\gametypes\global\_global::getsubstr(k.weapon, 0, k.weapon.size - 3);
	}
	if (isDefined(sMeansOfDeath) && sMeansOfDeath == "MOD_MELEE")
		k.weapon = "melee";
	k.hs = (isDefined(sHitLoc) && sHitLoc == "head") || (isDefined(sMeansOfDeath) && sMeansOfDeath == "MOD_HEAD_SHOT");
	k.t = (int)(getTime() / 100);

	// the whole round is shown (16 at most: a cvar holds 1 KB)
	kills = [];
	from = 0;
	if (level.streamerNative_kills.size >= 16)
		from = level.streamerNative_kills.size - 15;
	for (i = from; i < level.streamerNative_kills.size; i++)
		kills[kills.size] = level.streamerNative_kills[i];
	kills[kills.size] = k;
	level.streamerNative_kills = kills;

	if (isDefined(k.attacker))
	{
		n = k.attacker getEntityNumber();
		if (!isDefined(level.streamerNative_rk[n])) level.streamerNative_rk[n] = 0;
		if (!isDefined(level.streamerNative_rhs[n])) level.streamerNative_rhs[n] = 0;
		level.streamerNative_rk[n]++;
		if (k.hs)
			level.streamerNative_rhs[n]++;
	}
}

onPlayerDamaged(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset)
{
	if (!isDefined(eAttacker) || !isPlayer(eAttacker) || eAttacker == self || !isDefined(iDamage))
		return;
	if (isDefined(eAttacker.pers["team"]) && isDefined(self.pers["team"]) && eAttacker.pers["team"] == self.pers["team"])
		return;
	d = iDamage;
	if (d > 100)
		d = 100;
	n = eAttacker getEntityNumber();
	if (!isDefined(level.streamerNative_rdmg[n]))
		level.streamerNative_rdmg[n] = 0;
	level.streamerNative_rdmg[n] += d;

	// the auto camera: who is in a fight right now (_streamer_auto::scorePlayer)
	eAttacker.streamerAuto_hitAt = getTime();
	self.streamerAuto_hurtAt = getTime();

	// the streamer's hitmarker: every hit he makes, and whether the last one was on the head
	if (!isDefined(level.streamerNative_hits[n]))
		level.streamerNative_hits[n] = 0;
	level.streamerNative_hits[n]++;
	level.streamerNative_hitHead[n] = (isDefined(sHitLoc) && sHitLoc == "head") || (isDefined(sMeansOfDeath) && sMeansOfDeath == "MOD_HEAD_SHOT");
}

// menu response "streamersystem_native" (onMenuResponse, behind isStreamerModeEnabled)
enable()
{
	if (!isNative(self))
		logprint("_streamer_native:: " + self.name + " draws the streamer overlay natively\n");
	self.pers["streamerSystem_native"] = true;

	// the client draws a clean broadcast: none of the PAM's texts over it
	self.pers["streamerSystem_keysConfirmed"] = true;
	self maps\mp\gametypes\_streamer_hud::HUD_KeysWelcome_hide();
	self maps\mp\gametypes\global\_global::setClientCvar2("ui_spectatorsystem_keys", "0");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_settings", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_message_bg", "0");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_message_line1", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_message_line2", "");
}

// slot (0-9) of a player in the top bar, -1 if he has none
slotOf(player, sides)
{
	if (!isDefined(player) || !isDefined(sides))
		return -1;
	for (s = 0; s < 2; s++)
	{
		if (!isDefined(sides[s]))
			continue;
		for (i = 0; i < 5; i++)
			if (isDefined(sides[s][i]) && sides[s][i] == player)
				return s * 5 + i;
	}
	return -1;
}

slotStr(slot)
{
	if (slot < 0)
		return "-";
	return "" + slot;
}

// "K<id>.<attacker slot>.<victim slot>.<weapon without _mp>.<headshot 0/1>/..." oldest first, the whole round
feedKills(sides)
{
	if (!isDefined(level.streamerNative_kills) || level.streamerNative_kills.size == 0)
		return "K-";
	str = "K";
	for (i = 0; i < level.streamerNative_kills.size; i++)
	{
		k = level.streamerNative_kills[i];
		if (i > 0)
			str += "/";
		hs = "0";
		if (k.hs)
			hs = "1";
		str += k.id + "." + slotStr(slotOf(k.attacker, sides)) + "." + slotStr(slotOf(k.victim, sides)) + "." + k.weapon + "." + hs + "." + k.t;
	}
	return str;
}

// "W<a|x|d>.<reason e|b|d|t>.<mvp slot>.<kills>.<headshots>.<damage>" once the round is over (sd)
// The result is worked out once (level.streamerNative_result = "<w>.<r>" + the MVP player and
// numbers); the MVP's slot is looked up at every send (sides may be undefined: no slot).
feedResult(sides)
{
	if (level.gametype != "sd" || !isDefined(level.roundended) || !level.roundended || !isDefined(level.roundwinner))
		return "W-";
	if (!isDefined(level.streamerNative_result))
		computeResult();
	mvp = "-.0.0.0";
	if (isDefined(level.streamerNative_mvp) && isPlayer(level.streamerNative_mvp))
		mvp = slotStr(slotOf(level.streamerNative_mvp, sides)) + "." + level.streamerNative_mvpNums;
	return "W" + level.streamerNative_result + "." + mvp;
}

computeResult()
{
	{
		w = "d";
		if (level.roundwinner == "allies") w = "a";
		else if (level.roundwinner == "axis") w = "x";
		loser = undefined;
		if (w == "a") loser = "axis";
		else if (w == "x") loser = "allies";

		reason = "t";
		if (isDefined(level.bombexploded) && level.bombexploded)
			reason = "b";
		else if (isDefined(level.bombplanted) && level.bombplanted)
			reason = "d";
		else if (isDefined(loser) && isDefined(level.exist) && isDefined(level.exist[loser]) && level.exist[loser] == 0)
			reason = "e";

		// player of the round: most kills, then most damage
		best = undefined;
		bk = -1;
		bd = -1;
		players = getentarray("player", "classname");
		for (i = 0; i < players.size; i++)
		{
			n = players[i] getEntityNumber();
			rk = 0;
			rd = 0;
			if (isDefined(level.streamerNative_rk[n])) rk = level.streamerNative_rk[n];
			if (isDefined(level.streamerNative_rdmg[n])) rd = level.streamerNative_rdmg[n];
			if (rk > bk || (rk == bk && rd > bd))
			{
				best = players[i];
				bk = rk;
				bd = rd;
			}
		}
		level.streamerNative_mvp = undefined;
		if (isDefined(best) && (bk > 0 || bd > 0))
		{
			n = best getEntityNumber();
			hs = 0;
			if (isDefined(level.streamerNative_rhs[n])) hs = level.streamerNative_rhs[n];
			level.streamerNative_mvp = best;
			level.streamerNative_mvpNums = bk + "." + hs + "." + bd;
			if (!isDefined(best.pers["streamerNative_mvps"]))
				best.pers["streamerNative_mvps"] = 0;
			best.pers["streamerNative_mvps"]++;
		}
		level.streamerNative_result = w + "." + reason;
	}
}

// "N<round>.<rounds in the match>" (sd)
feedRound()
{
	if (level.gametype != "sd" || !isDefined(game["round"]))
		return "N-";
	total = 0;
	if (isDefined(level.matchround) && level.matchround > 0)
		total = level.matchround;
	return "N" + game["round"] + "." + total;
}

// kills,deaths,adr,assists,headshots,plants,defuses of a player, refreshed every half second
feedStats(player)
{
	adr = 0;
	stats = player maps\mp\gametypes\_player_stat::getStats();
	if (isDefined(stats) && isDefined(stats["damage"]))
	{
		rounds = 1;
		if (isDefined(game["round"]) && game["round"] > 1)
			rounds = game["round"];
		adr = (int)(stats["damage"] / (rounds * 1.0));
	}
	k = 0;
	d = 0;
	if (isDefined(player.score)) k = player.score;
	if (isDefined(player.deaths)) d = player.deaths;
	a = 0; hs = 0; pl = 0; df = 0;
	if (isDefined(stats))
	{
		if (isDefined(stats["assists"])) a = stats["assists"];
		if (isDefined(stats["headshots"])) hs = stats["headshots"];
		if (isDefined(stats["plants"])) pl = stats["plants"];
		if (isDefined(stats["defuses"])) df = stats["defuses"];
	}
	return k + "," + d + "," + adr + "," + a + "," + hs + "," + pl + "," + df;
}

// clip,reserve of the weapon in hand (only the followed player's is sent)
feedAmmo(player, weapon)
{
	slots = [];
	slots[0] = "primary";
	slots[1] = "primaryb";
	slots[2] = "pistol";
	for (i = 0; i < slots.size; i++)
	{
		w = player getWeaponSlotWeapon(slots[i]);
		if (isDefined(w) && w == weapon)
			return (player getWeaponSlotClipAmmo(slots[i])) + "," + (player getWeaponSlotAmmo(slots[i]));
	}
	return "-1,-1";
}

Native_Clear()
{
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_feed", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_events", "");
}

/*
	self is the streamer. Started on every streamer spawn, a single instance runs.
*/
Native_Loop()
{
	self endon("disconnect");
	self notify("streamerSystem_native_loop");
	self endon("streamerSystem_native_loop");

	lastPos = [];
	sight = [];
	stats = [];
	gear = [];
	windowSent = false;
	tick = 0;

	// round start: the client is restarting and acknowledges nothing for a moment, keep its
	// reliable command buffer for the spawn (see _streamer_hud::streamerGrace)
	wait level.fps_multiplier * 1.5;

	for (;;)
	{
		wait level.fps_multiplier * 0.1;
		tick++;

		if (!maps\mp\gametypes\_streamer::isStreamerModeEnabled(self))
		{
			self Native_Clear();
			return;
		}
		if (!isNative(self))
			continue;

		if (!windowSent)
		{
			self sendWindow();
			windowSent = true;
		}

		// the map is over (from the last round's end to the next map): the winning screen
		mapOver = game["state"] == "intermission" || (isDefined(level.streamerNative_mapOver) && level.streamerNative_mapOver);

		// the event strip and the series, when they change (cheap: compared before sending)
		if (tick % 20 == 1)
		{
			self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_event", eventLine());
			self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_series", seriesLine());
		}
		// a killcam replays the past: the client shows "REPLAY" instead of the live radar
		replay = "P0";
		if (isDefined(self.killcam))
			replay = "P1";

		sides = [];
		sides[0] = level.streamerSystem_boxesLeft_players;
		sides[1] = level.streamerSystem_boxesRight_players;

		// what the replay shows: whose eyes, which part of the past, how far it is
		if (replay == "P1" && isDefined(self.killcamInfo))
			replay = "P1." + slotStr(slotOfNum(self.killcamInfo.attacker, sides)) + "." + self.killcamInfo.from + "." + self.killcamInfo.length + "." + (int)((getTime() - self.killcamInfo.began) / 100);

		// camera: the followed player, or the streamer himself when flying
		camera = self;
		cameraSlot = -1;
		followed = undefined;
		if (!self.streamerSystem_freeSpectating && self.streamerSystem_turnedOn && isDefined(level.streamerSystem_player) && isPlayer(level.streamerSystem_player))
			followed = level.streamerSystem_player;

		xray = false;
		if (self.streamerSystem_freeSpectating)
			xray = self.streamerSystem_XRAY_inFreeSpectating;
		else if (isDefined(followed) && followed.sessionstate == "playing")
		{
			xray = self.pers["streamerSystem_XRAY"];
			camera = followed;
		}
		if (!level.scr_streamer_xray)
			xray = false;

		refreshSight = xray && (tick % 3 == 0);
		eye = undefined;
		if (refreshSight)
		{
			if (camera == self)
				eye = self.origin + (0, 0, 8);
			else
				eye = camera maps\mp\gametypes\global\player::getEyeOrigin();
		}

		slots = "";
		for (s = 0; s < 2; s++)
		{
			for (i = 0; i < 5; i++)
			{
				idx = s * 5 + i;
				player = undefined;
				if (isDefined(sides[s]))
					player = sides[s][i];

				if (!isDefined(player) || !isPlayer(player))
				{
					lastPos[idx] = undefined;
					sight[idx] = undefined;
					slots += "|-";
					continue;
				}
				if (isDefined(followed) && player == followed)
					cameraSlot = idx;

				if (player.sessionstate == "playing")
				{
					pos = player.origin;
					lastPos[idx] = pos;
					stance = player maps\mp\gametypes\global\player::getStance();
					st = "s";
					if (stance == "crouch") st = "c";
					else if (stance == "prone") st = "p";

					if (refreshSight)
					{
						sight[idx] = false;
						if (player != camera)
						{
							trace = bullettrace(eye, player.headTag.origin, true, camera);
							if (isDefined(trace["entity"]) && trace["entity"] == player)
								sight[idx] = true;
							else
							{
								trace = bullettrace(eye, player.pelvisTag.origin, true, camera);
								sight[idx] = isDefined(trace["entity"]) && trace["entity"] == player;
							}
						}
					}
					v = "0";
					if (isDefined(sight[idx]) && sight[idx])
						v = "1";
					weapon = player getcurrentweapon();
					if (!isDefined(weapon) || weapon == "" || weapon == "none")
						weapon = "-";
					if (tick % 5 == 0 || !isDefined(stats[idx]) || !isDefined(gear[idx]))
					{
						stats[idx] = feedStats(player);
						gear[idx] = feedGear(player);
					}
					ammo = "-1,-1";
					if (isDefined(followed) && player == followed && weapon != "-")
						ammo = feedAmmo(player, weapon);
					slots += "|1," + (int)pos[0] + "," + (int)pos[1] + "," + (int)pos[2] + "," + (int)player.angles[1] + "," + st + "," + v + "," + noMp(weapon) + "," + feedRoundKills(player) + "," + stats[idx] + "," + gear[idx] + "," + ammo + "," + mvpsOf(player) + "," + hitsOf(player);
				}
				else if (isDefined(lastPos[idx]))
				{
					pos = lastPos[idx];
					if (tick % 5 == 0 || !isDefined(stats[idx]))
						stats[idx] = feedStats(player);
					slots += "|0," + (int)pos[0] + "," + (int)pos[1] + "," + (int)pos[2] + ",0,s,0,-," + feedRoundKills(player) + "," + stats[idx] + ",0,-,-,-1,-1," + mvpsOf(player) + "," + hitsOf(player);
				}
				else if (mapOver)
					slots += "|0,0,0,0,0,s,0,-," + feedRoundKills(player) + "," + feedStats(player) + ",0,-,-,-1,-1," + mvpsOf(player) + "," + hitsOf(player);
				else
					slots += "|-";
			}
		}

		bomb = "B-";
		if (isDefined(level.bombplanted) && level.bombplanted && isDefined(level.bombmodel))
			bomb = "B" + (int)level.bombmodel.origin[0] + "," + (int)level.bombmodel.origin[1] + "," + (int)level.bombmodel.origin[2];

		r = "0";
		if (self.pers["streamerSystem_radar"] && level.scr_streamer_radar)
			r = "1";
		x = "0";
		if (xray)
			x = "1";

		z = "";
		if (mapOver)
			z = "|Z1";
		feed = "T" + (int)(getTime() / 1000) + "|R" + r + "|X" + x + "|C" + cameraSlot + "|" + bomb + "|" + feedClock() + "|" + replay + z + feedPause() + slots;
		events = feedRound() + "|" + feedKills(sides) + "|" + feedResult(sides) + "|" + feedHistory();
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_feed", feed);
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_events", events);
		if (tick % 30 == 0 && getCvar("scr_streamer_native_debug") == "1")
			logprint("_streamer_native:: feed (" + feed.size + " + " + events.size + " chars) " + feed + " || " + events + "\n");
	}
}

// "abc_mp" -> "abc"
noMp(w)
{
	if (isDefined(w) && w.size > 3 && maps\mp\gametypes\global\_global::getsubstr(w, w.size - 3, w.size) == "_mp")
		return maps\mp\gametypes\global\_global::getsubstr(w, 0, w.size - 3);
	return w;
}

// <grenades left>,<second primary or ->,<pistol or -> (weapon names without _mp)
feedGear(player)
{
	n = player maps\mp\gametypes\_weapons::getFragGrenadeCount();
	if (!isDefined(n)) n = 0;
	sec = player getWeaponSlotWeapon("primaryb");
	if (!isDefined(sec) || sec == "" || sec == "none") sec = "-";
	pis = player getWeaponSlotWeapon("pistol");
	if (!isDefined(pis) || pis == "" || pis == "none") pis = "-";
	return n + "," + noMp(sec) + "," + noMp(pis);
}

// rounds a player was the player of (this match)
// a ready-up (timeout, half-time, warm-up): "|Q<kind>.<team>.<left>.<ready>.<players>.<to a>.<to x>", "" else
feedPause()
{
	if (!isDefined(level.in_readyup) || !level.in_readyup || game["state"] == "intermission")
		return "";
	kind = "r";
	team = "-";
	if (isDefined(level.in_timeout) && level.in_timeout)
	{
		kind = "t";
		if (game["timeout_called_team"] == "allies")
			team = "a";
		else if (game["timeout_called_team"] == "axis")
			team = "x";
	}
	else if ((isDefined(game["is_halftime"]) && game["is_halftime"]) || (isDefined(game["overtime_active"]) && game["overtime_active"]))
		kind = "h";
	left = -1;
	if (isDefined(level.readyup_resumeAt))
	{
		left = (int)((level.readyup_resumeAt - getTime()) / 1000);
		if (left < 0)
			left = 0;
	}
	ready = 0;
	total = 0;
	players = getentarray("player", "classname");
	for (i = 0; i < players.size; i++)
	{
		if (players[i].pers["team"] != "allies" && players[i].pers["team"] != "axis")
			continue;
		total++;
		if (isDefined(players[i].isReady) && players[i].isReady)
			ready++;
	}
	toA = -1;
	toX = -1;
	if (isDefined(level.scr_timeouts) && level.scr_timeouts > 0)
	{
		toA = level.scr_timeouts - game["allies_called_timeouts"];
		toX = level.scr_timeouts - game["axis_called_timeouts"];
		if (toA < 0) toA = 0;
		if (toX < 0) toX = 0;
	}
	return "|Q" + kind + "." + team + "." + left + "." + ready + "." + total + "." + toA + "." + toX;
}

// hits a player made (this round) and whether the last one was on the head: "<n>,<0|1>"
hitsOf(player)
{
	n = player getEntityNumber();
	if (!isDefined(level.streamerNative_hits) || !isDefined(level.streamerNative_hits[n]))
		return "0,0";
	h = "0";
	if (isDefined(level.streamerNative_hitHead[n]) && level.streamerNative_hitHead[n])
		h = "1";
	return level.streamerNative_hits[n] + "," + h;
}

mvpsOf(player)
{
	if (isDefined(player.pers["streamerNative_mvps"]))
		return player.pers["streamerNative_mvps"];
	return 0;
}

// slot of the player with entity number num, -1 if none
slotOfNum(num, sides)
{
	for (s = 0; s < 2; s++)
	{
		if (!isDefined(sides[s]))
			continue;
		for (i = 0; i < 5; i++)
			if (isDefined(sides[s][i]) && isPlayer(sides[s][i]) && sides[s][i] getEntityNumber() == num)
				return s * 5 + i;
	}
	return -1;
}

// scr_streamer_text1..4 (the event, the stage...), "|" between them
eventLine()
{
	str = "";
	for (i = 1; i <= 4; i++)
	{
		t = getCvar("scr_streamer_text" + i);
		if (t == "")
			continue;
		if (str != "")
			str += "|";
		str += t;
	}
	return str;
}

// the maps of the match already played (sv_map3 is the first): "<name>.<score left>.<score right>;..."
seriesLine()
{
	str = "";
	for (j = 3; j >= 1; j--)
	{
		name = getCvar("sv_map" + j + "_name");
		if (name == "")
			continue;
		if (str != "")
			str += ";";
		str += maps\mp\gametypes\_matchinfo::GetMapName(name) + "." + getCvarInt("sv_map" + j + "_score1") + "." + getCvarInt("sv_map" + j + "_score2");
	}
	return str;
}

feedRoundKills(player)
{
	if (isDefined(player.pers["round_kills"]))
		return player.pers["round_kills"];
	return 0;
}

// The clock of the top bar: bomb, strat time or round (sd only), in tenths of a second left
feedClock()
{
	if (level.gametype != "sd" || game["state"] == "intermission")
		return "E-";
	left = undefined;
	kind = "";
	if (isDefined(level.bombplanted) && level.bombplanted && isDefined(level.bombtimerstart))
	{
		left = level.bombtimer * 1000 - (getTime() - level.bombtimerstart);
		kind = "b";
	}
	else if (isDefined(level.roundended) && level.roundended)
		return "E-";
	else if (isDefined(level.in_strattime) && level.in_strattime && isDefined(level.streamerNative_stratEnd))
	{
		left = level.streamerNative_stratEnd - getTime();
		kind = "s";
	}
	else if (isDefined(level.roundstarted) && level.roundstarted && isDefined(level.streamerNative_roundEnd))
	{
		left = level.streamerNative_roundEnd - getTime();
		kind = "r";
	}
	if (!isDefined(left))
		return "E-";
	if (left < 0)
		left = 0;
	return "E" + kind + (int)(left / 100);
}

// The radar window of this map (same as the PAM radar: the drawing and its exact frame)
sendWindow()
{
	win = maps\mp\gametypes\_streamer_radar::radarWindow();

	image = "-";
	c = maps\mp\gametypes\_streamer_radar::getStreamerMapConfig(level.mapname);
	if (isDefined(c) && isDefined(c.image))
		image = c.image;

	str = image + " " + (int)win.x + " " + (int)win.y + " " + (int)win.span + " " + (int)win.spanY + " " + (int)win.up;
	names = [];
	names[0] = "A";
	names[1] = "B";
	for (i = 0; i < 2; i++)
	{
		zone = undefined;
		if (level.gametype == "sd")
			zone = getent("bombzone_" + names[i], "targetname");
		if (isDefined(zone))
			str += " " + (int)zone.origin[0] + " " + (int)zone.origin[1];
		else
			str += " - -";
	}
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_radarwin", str);
}
