

init()
{
	logprint("_streamer_auto::init\n");
	
	if(game["firstInit"])
	{
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING", 					&"Auto-spectating");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_OFF", 					&"Auto-spectating off");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_MANUAL", 			&"Manual change");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_VISIBLE_ENEMY", 			&"Enemy in sight");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_VISIBLE_BY_ENEMY", 		&"Spotted by enemy");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_VISIBLE_ENEMY_IN_FUTURE", 	&"Enemy in sight (P)");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_VISIBLE_BY_ENEMY_IN_FUTURE", 	&"Spotted by enemy (P)");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_BOMB_PLANTED", 			&"Bomb planted");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_BOMB_SCORE", 			&"Follow losing team");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_LAST_PLAYER", 			&"Last player in team");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_1V1_SCORE", 			&"1v1 losing team");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_NO_ACTION_NEARBY", 		&"Next to each other");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_NO_ACTION_MOVING", 		&"Follow moving player");
		maps\mp\gametypes\global\_global::precacheString2("STRING_AUTO_SPECTATING_REASON_RADIO_DEFEND", 			&"Radio defending team");

		//game["STRING_AUTO_SPECT_IS_ENABLED"] = 		"Auto-spectating ^2On";
		//game["STRING_AUTO_SPECT_IS_DISABLED"] = 	"Auto-spectating ^1Off";
	}

	level.streamerSystem_auto_turnedOn = true;
	level.streamerSystem_auto_lockedUntill = 0;
	level.streamerSystem_auto_statusText = "STRING_AUTO_SPECTATING";
	level.streamerSystem_auto_runThreads = false;


	if (!level.streamerSystem)
	{
		return;
	}

	maps\mp\gametypes\global\_global::addEventListener("onConnected",  	::onConnected);
	maps\mp\gametypes\global\_global::addEventListener("onConnectedAll",    	::onConnectedAll);
}

onConnected()
{
	logprint("_streamer_auto::onConnected start\n");
	self.streamerSystem_inCinematic = false;
	logprint("_streamer_auto::onConnected end\n");
}

onConnectedAll()
{
	logprint("_streamer_auto::onConnectedAll start\n");
	thread playersCanSeeEachOthers();
	thread playersCloseToEachOther();
	thread autoFollowedPlayer();
	logprint("_streamer_auto::onConnectedAll end\n");
}



autoSpectatorEnable()
{
	level.streamerSystem_auto_turnedOn = true;

	level.streamerSystem_auto_statusText = "STRING_AUTO_SPECTATING";

	//level printToAutoSpectators(game["STRING_AUTO_SPECT_IS_ENABLED"]);

	level thread maps\mp\gametypes\_streamer_hud::settingsChanged("auto");
}


autoSpectatorDisable()
{
	//level printToAutoSpectators(game["STRING_AUTO_SPECT_IS_DISABLED"]);

	level.streamerSystem_auto_turnedOn = false;

	level.streamerSystem_auto_statusText = "STRING_AUTO_SPECTATING_OFF";

	level thread maps\mp\gametypes\_streamer_hud::settingsChanged("auto");
}

autoSpectatorToggle()
{
	if (!level.streamerSystem_auto_turnedOn)
		autoSpectatorEnable();
	else
		autoSpectatorDisable();
}



HUD_loop()
{
	self endon("disconnect");

	if(!isdefined(self.streamerSystem_HUD_autoSpectator_BG))
	{
		self.streamerSystem_HUD_autoSpectator_BG = maps\mp\gametypes\global\_global::newClientHudElem2(self);
		self.streamerSystem_HUD_autoSpectator_BG.archived = false;
		//self.streamerSystem_HUD_autoSpectator_BG.x = -40;
		self.streamerSystem_HUD_autoSpectator_BG.x = 280;
		self.streamerSystem_HUD_autoSpectator_BG.y = 40;
		//self.streamerSystem_HUD_autoSpectator_BG.horzAlign = "center";
		//self.streamerSystem_HUD_autoSpectator_BG.vertAlign = "top";
		self.streamerSystem_HUD_autoSpectator_BG.alpha = 0;
		self.streamerSystem_HUD_autoSpectator_BG.color = (0, 0, 0);
		self.streamerSystem_HUD_autoSpectator_BG setShader("white", 80, 10);
	}

	// Auto-spectating
	if(!isdefined(self.streamerSystem_HUD_autoSpectator))
	{
		self.streamerSystem_HUD_autoSpectator = maps\mp\gametypes\global\_global::newClientHudElem2(self);
		//self.streamerSystem_HUD_autoSpectator.horzAlign = "center";
		//self.streamerSystem_HUD_autoSpectator.vertAlign = "top";
		self.streamerSystem_HUD_autoSpectator.alignX = "center";
		self.streamerSystem_HUD_autoSpectator.alignY = "top";
		//self.streamerSystem_HUD_autoSpectator.x = 0;
		self.streamerSystem_HUD_autoSpectator.x = 320;
		self.streamerSystem_HUD_autoSpectator.y = 42;
		self.streamerSystem_HUD_autoSpectator.archived = false;
		self.streamerSystem_HUD_autoSpectator.font = "default";
		self.streamerSystem_HUD_autoSpectator.alpha = 0;
		self.streamerSystem_HUD_autoSpectator.sort = 2;
		self.streamerSystem_HUD_autoSpectator.fontscale = 0.6;
	}

	hud_text_last = "";

	for (;;)
	{
		if (self.pers["team"] != "streamer")
			break;

		if (!self.streamerSystem_turnedOn || self.streamerSystem_freeSpectating)
		{
			// Hide
			if (self.streamerSystem_HUD_autoSpectator_BG.alpha != 0) 	self.streamerSystem_HUD_autoSpectator_BG.alpha = 0;
			if (self.streamerSystem_HUD_autoSpectator.alpha != 0) 	self.streamerSystem_HUD_autoSpectator.alpha = 0;
		}
		else if (level.streamerSystem_auto_turnedOn)
		{
			// Show
			if (self.streamerSystem_HUD_autoSpectator_BG.alpha != 0.5) 	self.streamerSystem_HUD_autoSpectator_BG.alpha = 0.5;
			if (self.streamerSystem_HUD_autoSpectator.alpha != 1) 	self.streamerSystem_HUD_autoSpectator.alpha = 1;

			canSwitch = ((gettime() - level.streamerSystem_auto_lockedUntill) > 0)  &&  ((gettime() - level.streamerSystem_lastChange) > 6000);

			color = (0, 0, 0); // black
			if (canSwitch) color = (0.03, 0.18, 0.1); // green

			if (self.streamerSystem_HUD_autoSpectator_BG.color != color) 	self.streamerSystem_HUD_autoSpectator_BG.color = color;
		}
		else
		{
			// No bg
			if (self.streamerSystem_HUD_autoSpectator_BG.alpha != 0) 	self.streamerSystem_HUD_autoSpectator_BG.alpha = 0;
			if (self.streamerSystem_HUD_autoSpectator.alpha != 1) 	self.streamerSystem_HUD_autoSpectator.alpha = 1;
		}

		// Update text with follow reason
		if (level.streamerSystem_auto_statusText != "" && level.streamerSystem_auto_statusText != hud_text_last)
		{
			self.streamerSystem_HUD_autoSpectator setText(game[level.streamerSystem_auto_statusText]);
		}
		hud_text_last = level.streamerSystem_auto_statusText;

		wait level.fps_multiplier * 0.1;
	}


	// Destroy
	if(isdefined(self.streamerSystem_HUD_autoSpectator_BG))
	{
		self.streamerSystem_HUD_autoSpectator_BG destroy();
		self.streamerSystem_HUD_autoSpectator_BG = undefined;
	}
	if(isdefined(self.streamerSystem_HUD_autoSpectator))
	{
		self.streamerSystem_HUD_autoSpectator destroy();
		self.streamerSystem_HUD_autoSpectator = undefined;
	}
}





printToAutoSpectators(text)
{
	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		player = players[i];
		if (player.pers["team"] == "streamer" && player.streamerSystem_turnedOn && level.streamerSystem_auto_turnedOn)
		{
			player iprintln(text);
			break;
		}
	}
}



playersCanSeeEachOthers()
{
	logprint("_streamer_auto::playersCanSeeEachOthers start\n");
	for (;;)
	{
		//logprint("_streamer_auto::playersCanSeeEachOthers infinite loop start\n");
		// Not enabled, wait
		if (!level.streamerSystem_auto_runThreads)
		{
			wait level.fps_multiplier * 3;
			continue;
		}

		players = getentarray("player", "classname");
		for(i = 0; i < players.size; i++)
		{
			player = players[i];
			player.autospectator_visibleEnemy = undefined;
			player.autospectator_seenByEnemy = undefined;

			player.streamerSystem_visibleEnemyInFuture = undefined;
			player.streamerSystem_seenByEnemyInFuture = undefined;
		}

		for(i = 0; i < players.size; i++)
		{
			player = players[i];

			if (!isDefined(player)) continue; // because of wait player may be disconnected

			if ((player.pers["team"] == "allies" || player.pers["team"] == "axis") && (player.sessionstate == "playing"))
			{
				eye = player maps\mp\gametypes\global\player::getEyeOrigin();
				//angles = player getPlayerAngles();
				angles = player.angles;

				// If player is moving, predict future position
				predictedPosition = undefined;
				if (player.movingVector != (0, 0, 0))
				{
					multiplier = length(player.movingVector);
					if (multiplier > 12)
						multiplier = 12;
					vector = VectorNormalize(player.movingVector);

					multiplier = multiplier * 8;

					futureEye = eye + (vector[0] * multiplier, vector[1] * multiplier, vector[2] * multiplier);

					// Create forward point - it might be future position of player
					forwardTrace = Bullettrace(eye, futureEye, false, player); // BulletTrace( <start>, <end>, <hit characters>, <ignore entity> )
					predictedPosition = forwardTrace["position"];
				}

				// Debug point
				/*
				if (level.debug_spectator)
				{
					if (!isDefined(player.streamerSystem_eyeWaypoint))
					{
						player.streamerSystem_eyeWaypoint = spawn("script_origin",(0,0,0));
						player.streamerSystem_eyeWaypoint thread maps\mp\gametypes\global\developer::showWaypoint();
					}
					if (isDefined(predictedPosition))
						player.streamerSystem_eyeWaypoint.origin = predictedPosition;
					else
					{
						player.streamerSystem_eyeWaypoint delete();
						player.streamerSystem_eyeWaypoint = undefined;
					}
				}
				*/


				// Loop enemies of this player
				for(j = 0; j < players.size; j++)
				{
					enemy = players[j];

					if (!isDefined(enemy)) continue; // because of wait player may be disconnected

					if (enemy != player && (enemy.pers["team"] == "allies" || enemy.pers["team"] == "axis") && enemy.pers["team"] != player.pers["team"] && (enemy.sessionstate == "playing"))
					{
						angles2 = vectorToAngles(enemy getOrigin() - player getOrigin());
						angle_diff = angles[1] - angles2[1];

						if (angle_diff > 180) angle_diff -= 360;
						if (angle_diff < -180) angle_diff += 360;

						//player iprintln("i have player " + enemy.name + " in angle" + angle_diff);

						if (angle_diff > -35 && angle_diff < 35)
						{
							trace = Bullettrace(eye, enemy.headTag getOrigin(), true, player);
							headVisible = isDefined(trace["entity"]) && trace["entity"] == enemy;

							if (headVisible)
							{
								//player iprintln("i have players " + enemy.name + " head on screen");
								player.autospectator_visibleEnemy = enemy;
								enemy.autospectator_seenByEnemy = player;
								continue;
							}

							// Check predicted position
							else if (isDefined(predictedPosition))
							{
								// Check if future position is visible
								trace = Bullettrace(predictedPosition, enemy.headTag getOrigin(), true, player);
								headVisible = isDefined(trace["entity"]) && trace["entity"] == enemy;

								if (headVisible)
								{
									//player iprintln("i will see player " + enemy.name + " in future");
									player.streamerSystem_visibleEnemyInFuture = enemy;
									enemy.streamerSystem_seenByEnemyInFuture = player;
								}
							}
						}


					}
				}

				//wait level.frame;
			}
		}

		wait level.fps_multiplier * .1;
	}

}



playersCloseToEachOther()
{
	logprint("_streamer_auto::playersCloseToEachOther start\n");
	for (;;)
	{
		//logprint("_streamer_auto::playersCloseToEachOther infinite loop start\n");
		// Not enabled, wait
		if (!level.streamerSystem_auto_runThreads)
		{
			wait level.fps_multiplier * 3;
			continue;
		}

		dist_min = -1;
		dist_player1 = undefined;
		dist_player2 = undefined;

		players = getentarray("player", "classname");
		for(i = 0; i < players.size; i++)
		{
			player = players[i];

			player.autoSpectating_veryCloseToEnemy = undefined;

			if ((player.pers["team"] == "allies" || player.pers["team"] == "axis") && (player.sessionstate == "playing"))
			{
				for(j = 0; j < players.size; j++)
				{
					enemy = players[j];

					if (enemy != player && (enemy.pers["team"] == "allies" || enemy.pers["team"] == "axis") && enemy.pers["team"] != player.pers["team"] && (enemy.sessionstate == "playing"))
					{
						dist = distance(player getOrigin(), enemy getOrigin());

						if (dist < dist_min || dist_min == -1)
						{
							dist_min = dist;
							dist_player1 = player;
							dist_player2 = enemy;
						}
					}
				}
			}
		}

		if (dist_min != -1 && dist_min < 800)
		{
			dist_player1.autoSpectating_veryCloseToEnemy = dist_player2;
			dist_player2.autoSpectating_veryCloseToEnemy = dist_player1;
		}

		wait level.fps_multiplier * .5;
	}

}


lockFor(time)
{
	level.streamerSystem_auto_lockedUntill = gettime() + time; // wait some time untill next change

	if (level.streamerSystem_auto_turnedOn)
		level.streamerSystem_auto_statusText = "STRING_AUTO_SPECTATING_REASON_MANUAL";
}


autoFollowedPlayer()
{
	logprint("_streamer_auto::autoFollowedPlayer start\n");
	level.streamerSystem_auto_lockedUntill = gettime() + 18000; // wait some time untill next change (also consider strat time)

	followed_team_last = "";
	for(;;)
	{
		//logprint("_streamer_auto::autoFollowedPlayer infinite loop start\n");
		wait level.fps_multiplier * 0.1;

		players = getentarray("player", "classname");

		autospectator_exists = false;
		players_exists = false;
		for(i = 0; i < players.size; i++)
		{
			player = players[i];
			if (player.pers["team"] == "streamer" && player.streamerSystem_turnedOn && level.streamerSystem_auto_turnedOn)
				autospectator_exists = true;

			if ((player.pers["team"] == "allies" || player.pers["team"] == "axis") && player.sessionstate == "playing")
				players_exists = true;

		}
		level.streamerSystem_auto_runThreads = (autospectator_exists && players_exists);

		// No players, do nothing
		if (level.streamerSystem_auto_runThreads == false)
			continue;

		// In timeout
		//if (level.in_readyup)
		//	continue;

		id = level.streamerSystem_playerID;
		spectated_player = level.streamerSystem_player;

		// If no one is followed, wait
		if (id == -1 || !isDefined(spectated_player) || !isPlayer(spectated_player))
			continue;

		// Autospectator is locked to some player, dont switch
		if (!level.streamerSystem_auto_turnedOn)
		{
			wait level.fps_multiplier * 1;
			level.streamerSystem_auto_lockedUntill = gettime() + 3000; // wait some time untill next change
			level.streamerSystem_auto_statusText = "STRING_AUTO_SPECTATING_OFF";
			continue;
		}

		// Can switch after 4 seconds from the last switch (zPAM: 6)
		if ((gettime() - level.streamerSystem_lastChange) < 4000)
		{
			continue;
		}

		// Dont switch when round ended
		if (level.gametype == "sd" && level.roundended)
			continue;



		// Can switch after 6 second from last switch and untill timer expired
		canSwitch = (gettime() - level.streamerSystem_auto_lockedUntill) > 0;
		if (!canSwitch)
		{
			// Player has visible enemy on their screen or enemy is seeing this player or their screen
			// Extent time for this player
			if (isDefined(spectated_player.autospectator_visibleEnemy) || isDefined(spectated_player.autospectator_seenByEnemy))
			{
				if (level.debug_spectator) printToAutoSpectators("Extending time for this player (visisble enemy)");
				level.streamerSystem_auto_lockedUntill = gettime() + 8000;
				level.streamerSystem_auto_statusText = "STRING_AUTO_SPECTATING_REASON_VISIBLE_ENEMY";
				wait level.fps_multiplier * 1;
			}

			// Player has in future visible enemy on their screen or enemy is seeing this player or their screen
			// Extent time for this player
			if (isDefined(spectated_player.streamerSystem_visibleEnemyInFuture) || isDefined(spectated_player.streamerSystem_seenByEnemyInFuture))
			{
				if (level.debug_spectator) printToAutoSpectators("Extending time for this player (visisble enemy in future)");
				level.streamerSystem_auto_lockedUntill = gettime() + 4000;
				level.streamerSystem_auto_statusText = "STRING_AUTO_SPECTATING_REASON_VISIBLE_ENEMY_IN_FUTURE";
				wait level.fps_multiplier * 1;
			}

			// Dont continue untill we can switch
			continue;
		}
		else
			level.streamerSystem_auto_statusText = "STRING_AUTO_SPECTATING";

		// The director (2026-11-23, "camera plus maligne"): every living player gets a score for
		// how much is happening to him right now; the camera moves only to a clearly better one.
		// (Replaces zPAM's rules: 1vX / 1v1 / bomb / first player of the SAME team with an enemy
		// in sight - it never crossed to the other team, and took the first match, not the best.)
		if (spectated_player.sessionstate != "playing")
			continue;	// his death: _streamer::spectating_loop shows it, then his killer
		best = directorBest(spectated_player);
		if (!isDefined(best) || best == spectated_player)
			continue;
		if (best.streamerAuto_score < spectated_player.streamerAuto_score + 45)
			continue;

		level maps\mp\gametypes\_streamer::followPlayer(best);
		if (level.debug_spectator) printToAutoSpectators("director: " + best.name + " (" + best.streamerAuto_score + ")");
		level.streamerSystem_auto_lockedUntill = gettime() + 3500;	// at least 3.5 s on him
		level.streamerSystem_auto_statusText = best.streamerAuto_why;
	}
}

// How much is happening to a player right now (self). -1 = not playing, 0 = nothing. Read by
// directorBest() and _streamer::spectating_loop (who to show when the followed player dies).
// Keeps its main reason in self.streamerAuto_why (a STRING_AUTO_SPECTATING_REASON_* key).
scorePlayer()
{
	self.streamerAuto_why = "STRING_AUTO_SPECTATING";
	if ((self.pers["team"] != "allies" && self.pers["team"] != "axis") || self.sessionstate != "playing")
		return -1;
	now = getTime();
	sc = 0;
	why = 0;
	// on the bomb (planting or defusing: his progress bar is up)
	if (isDefined(self.progressbar))
	{
		sc += 160;
		why = 160;
		self.streamerAuto_why = "STRING_AUTO_SPECTATING_REASON_BOMB_PLANTED";
	}
	if (isDefined(self.autospectator_visibleEnemy))
	{
		sc += 100;
		if (why < 100) { why = 100; self.streamerAuto_why = "STRING_AUTO_SPECTATING_REASON_VISIBLE_ENEMY"; }
	}
	else if (isDefined(self.streamerSystem_visibleEnemyInFuture))
	{
		sc += 45;
		if (why < 45) { why = 45; self.streamerAuto_why = "STRING_AUTO_SPECTATING_REASON_VISIBLE_ENEMY_IN_FUTURE"; }
	}
	if (isDefined(self.autospectator_seenByEnemy))
	{
		sc += 70;
		if (why < 70) { why = 70; self.streamerAuto_why = "STRING_AUTO_SPECTATING_REASON_VISIBLE_BY_ENEMY"; }
	}
	else if (isDefined(self.streamerSystem_seenByEnemyInFuture))
		sc += 30;
	// in a fight: hit someone / was hit in the last 2.5 s
	if (isDefined(self.streamerAuto_hitAt) && now - self.streamerAuto_hitAt < 2500)
		sc += 60;
	if (isDefined(self.streamerAuto_hurtAt) && now - self.streamerAuto_hurtAt < 2500)
		sc += 50;
	// close to an enemy (up to +80 at contact, nothing past 1200 units)
	if (isDefined(self.streamerAuto_nearest) && self.streamerAuto_nearest < 1200)
	{
		sc += (int)((1200 - self.streamerAuto_nearest) / 15);
		if (why < 40 && self.streamerAuto_nearest < 600) { why = 40; self.streamerAuto_why = "STRING_AUTO_SPECTATING_REASON_NO_ACTION_NEARBY"; }
	}
	// the last of his team against at least one: the story of the round
	if (isDefined(self.streamerAuto_lastAlive) && self.streamerAuto_lastAlive)
	{
		sc += 120;
		if (why < 120) { why = 120; self.streamerAuto_why = "STRING_AUTO_SPECTATING_REASON_LAST_PLAYER"; }
	}
	// bomb planted: the defenders going for it
	if (level.gametype == "sd" && isDefined(level.bombplanted) && level.bombplanted && isDefined(level.bombmodel) && isDefined(game["defenders"]) && self.pers["team"] == game["defenders"])
	{
		d = distance(self.origin, level.bombmodel.origin);
		if (d < 900)
			sc += (int)((900 - d) / 15);
	}
	return sc;
}

// The living player with the highest score (each player's score in .streamerAuto_score),
// undefined if nobody plays. current = the followed player: +35 keeps the camera from
// ping-ponging between two equal fights.
directorBest(current)
{
	players = getentarray("player", "classname");
	alive = [];
	alive["allies"] = 0;
	alive["axis"] = 0;
	for (i = 0; i < players.size; i++)
		if ((players[i].pers["team"] == "allies" || players[i].pers["team"] == "axis") && players[i].sessionstate == "playing")
			alive[players[i].pers["team"]]++;
	best = undefined;
	bestScore = -1;
	for (i = 0; i < players.size; i++)
	{
		p = players[i];
		p.streamerAuto_score = -1;
		if ((p.pers["team"] != "allies" && p.pers["team"] != "axis") || p.sessionstate != "playing")
			continue;
		// nearest living enemy
		p.streamerAuto_nearest = undefined;
		for (j = 0; j < players.size; j++)
		{
			e = players[j];
			if (e == p || e.sessionstate != "playing" || (e.pers["team"] != "allies" && e.pers["team"] != "axis") || e.pers["team"] == p.pers["team"])
				continue;
			d = distance(p.origin, e.origin);
			if (!isDefined(p.streamerAuto_nearest) || d < p.streamerAuto_nearest)
				p.streamerAuto_nearest = d;
		}
		enemyTeam = "axis";
		if (p.pers["team"] == "axis")
			enemyTeam = "allies";
		p.streamerAuto_lastAlive = alive[p.pers["team"]] == 1 && alive[enemyTeam] >= 1;
		sc = p scorePlayer();
		if (isDefined(current) && p == current)
			sc += 35;
		p.streamerAuto_score = sc;
		if (sc > bestScore)
		{
			bestScore = sc;
			best = p;
		}
	}
	return best;
}
