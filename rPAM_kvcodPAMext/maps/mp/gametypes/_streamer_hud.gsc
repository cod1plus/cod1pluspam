/*	_streamer_hud.gsc

  	rPAMext Version: v27 (for kvcodPAM v217)      
  
  	Changes into kvcodPAM  
  	- marked changes v215
    	- added zPAM 336 code
	- v218 kikiii added/removed simple killfeed in streamer mode
*/

//include maps\mp\gametypes\global\_global;

init()
{
	logprint("_streamer_hud::init\n");
	
	if (!level.streamerSystem)
		return;

	if(game["firstInit"])
	{
//3		precacheString2("STRING_STREAMERSYSTEM_PRESS_ATTACT_TO_ENABLE", &"Press ^3[{+attack}]^7 to open streamer menu");
//3		precacheString2("STRING_STREAMERSYSTEM_PRESS_ESC_WARNING", &"Press ^3[ESC]^7 to close streamer menu\n(binds are not working when streamer menu is opened)");
//f		maps\mp\gametypes\global\_global::precacheString2("STRING_STREAMERSYSTEM_PRESS_ATTACT_TO_ENABLE", &"Press ^3[{+attack}]^7 to open streamer menu");
		maps\mp\gametypes\global\_global::precacheString2("STRING_STREAMERSYSTEM_PRESS_ATTACK_TO_ENABLE", &"Press ^3[{+attack}]^7 to open streamer menu");
		maps\mp\gametypes\global\_global::precacheString2("STRING_STREAMERSYSTEM_PRESS_ESC_WARNING", &"Press ^3[ESC]^7 to close streamer menu\n(binds are not working when streamer menu is opened)");
	}

	if (!isDefined(game["streamerSystem_scoreProgress"]))
		game["streamerSystem_scoreProgress"] = [];
//k217_killfeed
//	if (!isDefined(game["streamer_killfeed"]))
//		game["streamer_killfeed"] = "";
//	
//	game["streamer_killfeed"] = "";
//k217_end
	game["streamerSystem_playerProgress"] = [];

	level.streamerSystem_boxesLeft_players = [];
	level.streamerSystem_boxesRight_players = [];

//3	addEventListener("onConnected",  	::onConnected);
	maps\mp\gametypes\global\_global::addEventListener("onConnected",  	::onConnected);
}

onConnected()
{
	logprint("_streamer_hud::onConnected start\n");
	if (!isDefined(self.pers["streamerSystem_keysVisible"]))
		self.pers["streamerSystem_keysVisible"] = false;
	logprint("_streamer_hud::onConnected end\n");
}

keys_toggle()
{
	// Already hided
	if (!self.pers["streamerSystem_keysVisible"])
		self keys_show();
	else
		self keys_hide();
}

keys_show()
{
	self.pers["streamerSystem_keysVisible"] = true;
//3	self setClientCvar2("ui_spectatorsystem_keys", "1");
	self maps\mp\gametypes\global\_global::setClientCvar2("ui_spectatorsystem_keys", "1");
	self notify("streamerSystem_keysVisible", 1);

	self thread settingsChangedForPlayer(""); // will show all
}

keys_hide()
{
	self.pers["streamerSystem_keysVisible"] = false;
//3	self setClientCvar2("ui_spectatorsystem_keys", "0");
	self maps\mp\gametypes\global\_global::setClientCvar2("ui_spectatorsystem_keys", "0");
	self notify("streamerSystem_keysVisible", 0);

	self thread settingsChangedForPlayer(""); // will hide all
}




HUD_KeysWelcome_show()
{
//3	self setClientCvar2("ui_spectatorsystem_keysWelcome", "1");
	self maps\mp\gametypes\global\_global::setClientCvar2("ui_spectatorsystem_keysWelcome", "1");
}

HUD_KeysWelcome_hide()
{
//3	self setClientCvar2("ui_spectatorsystem_keysWelcome", "0");
	self maps\mp\gametypes\global\_global::setClientCvar2("ui_spectatorsystem_keysWelcome", "0");
}




HUD_ActivateStreamerSystem_show()
{
	if (!isDefined(self.streamerSystem_HUD_enableBG))
	{
//3		self.streamerSystem_HUD_enableBG = addHUDClient(self, -100, 40, undefined, (1,1,1), "left", "top", "center", "middle");
		self.streamerSystem_HUD_enableBG = maps\mp\gametypes\global\_global::addHUDClient(self, 220, 280, undefined, (1,1,1), "left", "top", "center", "middle");
//3	    self.streamerSystem_HUD_enableBG setShader("black", 200, 20);
	    self.streamerSystem_HUD_enableBG setShader("black", 200, 20);
		self.streamerSystem_HUD_enableBG.archived = false;
		self.streamerSystem_HUD_enableBG.sort = -1000; // idk why sometimes the BG is in front of text...
//3 	self.streamerSystem_HUD_enableBG.alpha = 0.5;
	    self.streamerSystem_HUD_enableBG.alpha = 0.5;
	}
	if (!isDefined(self.streamerSystem_HUD_enable))
	{
//3 	self.streamerSystem_HUD_enable = addHUDClient(self, 0, 40+6, 0.8, (1,1,1), "center", "top", "center", "middle");
	    self.streamerSystem_HUD_enable = maps\mp\gametypes\global\_global::addHUDClient(self, 320, 280+6, 0.8, (1,1,1), "center", "top", "center", "middle");
		self.streamerSystem_HUD_enable.archived = false;
//f		self.streamerSystem_HUD_enable setText(game["STRING_STREAMERSYSTEM_PRESS_ATTACT_TO_ENABLE"]);
		self.streamerSystem_HUD_enable setText(game["STRING_STREAMERSYSTEM_PRESS_ATTACK_TO_ENABLE"]);
	}

	self HUD_CloseMenuWarning_destroy();
}

HUD_ActivateStreamerSystem_hide()
{
	if (isDefined(self.streamerSystem_HUD_enableBG))
	{
//3		self.streamerSystem_HUD_enableBG destroy2();
		self.streamerSystem_HUD_enableBG destroy();
		self.streamerSystem_HUD_enableBG = undefined;
	}
	if (isDefined(self.streamerSystem_HUD_enable))
	{
//3		self.streamerSystem_HUD_enable destroy2();
	    self.streamerSystem_HUD_enable destroy();
		self.streamerSystem_HUD_enable = undefined;
	}
}




HUD_CloseMenuWarning_show()
{
	self endon("disconnect");

	self notify("streamerSystem_HUD_closeMenuWarningBG");
	self endon("streamerSystem_HUD_closeMenuWarningBG");

	if (!isDefined(self.streamerSystem_HUD_closeMenuWarningBG))
	{
//3		self.streamerSystem_HUD_closeMenuWarningBG = addHUDClient(self, -150, 40, undefined, (1,1,1), "left", "top", "center", "middle");
		self.streamerSystem_HUD_closeMenuWarningBG = maps\mp\gametypes\global\_global::addHUDClient(self, 170, 280, undefined, (1,1,1), "left", "top", "center", "middle");
//3		self.streamerSystem_HUD_closeMenuWarningBG setShader("black", 300, 23);
	    self.streamerSystem_HUD_closeMenuWarningBG setShader("black", 300, 23);
		self.streamerSystem_HUD_closeMenuWarningBG.archived = false;
		self.streamerSystem_HUD_closeMenuWarningBG.sort = -1000;
	}
	if (!isDefined(self.streamerSystem_HUD_closeMenuWarning))
	{
//3		self.streamerSystem_HUD_closeMenuWarning = addHUDClient(self, 0, 40+2, 0.8, (1,1,1), "center", "top", "center", "middle");
	    self.streamerSystem_HUD_closeMenuWarning = maps\mp\gametypes\global\_global::addHUDClient(self, 320, 280+2, 0.8, (1,1,1), "center", "top", "center", "middle");
		self.streamerSystem_HUD_closeMenuWarning.archived = false;
		self.streamerSystem_HUD_closeMenuWarning setText(game["STRING_STREAMERSYSTEM_PRESS_ESC_WARNING"]);
	}

	self.streamerSystem_HUD_closeMenuWarning.alpha = 1;

	for (i = 0; i < 3; i++)
	{
		self.streamerSystem_HUD_closeMenuWarningBG.alpha = 0.75;

		wait level.fps_multiplier * 0.1;
		if (!isDefined(self.streamerSystem_HUD_closeMenuWarningBG) || !isDefined(self.streamerSystem_HUD_closeMenuWarning)) return;

		self.streamerSystem_HUD_closeMenuWarningBG.alpha = 0.5;

		wait level.fps_multiplier * 0.1;
		if (!isDefined(self.streamerSystem_HUD_closeMenuWarningBG) || !isDefined(self.streamerSystem_HUD_closeMenuWarning)) return;
	}

	self.streamerSystem_HUD_closeMenuWarningBG.alpha = 0.75;
	self.streamerSystem_HUD_closeMenuWarning.alpha = 1;

	wait level.fps_multiplier * 0.5;
	if (!isDefined(self.streamerSystem_HUD_closeMenuWarningBG) || !isDefined(self.streamerSystem_HUD_closeMenuWarning)) return;

	self.streamerSystem_HUD_closeMenuWarningBG FadeOverTime(.5);
	self.streamerSystem_HUD_closeMenuWarning FadeOverTime(.5);
	self.streamerSystem_HUD_closeMenuWarningBG.alpha = 0;
	self.streamerSystem_HUD_closeMenuWarning.alpha = 0;

	wait level.fps_multiplier * .5;

	self HUD_CloseMenuWarning_destroy();
}

HUD_CloseMenuWarning_destroy()
{
	if (isDefined(self.streamerSystem_HUD_closeMenuWarningBG))
	{
//3		self.streamerSystem_HUD_closeMenuWarningBG destroy2();
		self.streamerSystem_HUD_closeMenuWarningBG destroy();
		self.streamerSystem_HUD_closeMenuWarningBG = undefined;
	}
	if (isDefined(self.streamerSystem_HUD_closeMenuWarning))
	{
//3		self.streamerSystem_HUD_closeMenuWarning destroy2();
	    self.streamerSystem_HUD_closeMenuWarning destroy();
		self.streamerSystem_HUD_closeMenuWarning = undefined;
	}

}


hide_all()
{
	self hide_player_boxes();
	self hide_matchinfo();
	self hide_player_progress();
	self hide_messages();
	self hide_top_header();
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_radar", "0");

//3	self setClientCvarIfChanged("ui_streamersystem_settings", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_settings", "");
}

hide_player_boxes()
{
	for (i = 4; i >= 0; i--)
	{
//3		self setClientCvarIfChanged("ui_streamersystem_team1_player"+i+"_health", "");
//3		self setClientCvarIfChanged("ui_streamersystem_team2_player"+i+"_health", "");
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_team1_player"+i+"_health", "");
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_team2_player"+i+"_health", "");

		//self setClientCvarIfChanged("ui_streamersystem_team1_player"+i+"_name", "");		// these cvars are hided anyway via _health cvar
		//self setClientCvarIfChanged("ui_streamersystem_team2_player"+i+"_name", "");		// save sending these cvars

		//self setClientCvarIfChanged("ui_streamersystem_team1_player"+i+"_score", "");
		//self setClientCvarIfChanged("ui_streamersystem_team2_player"+i+"_score", "");

		//self setClientCvarIfChanged("ui_streamersystem_team1_player"+i+"_weapon", "");
		//self setClientCvarIfChanged("ui_streamersystem_team2_player"+i+"_weapon", "");

		//self setClientCvarIfChanged("ui_streamersystem_team1_player"+i+"_round_kills", "");
		//self setClientCvarIfChanged("ui_streamersystem_team2_player"+i+"_round_kills", "");

//3		self setClientCvarIfChanged("ui_streamersystem_team1_player"+i+"_icons", "");
//3		self setClientCvarIfChanged("ui_streamersystem_team2_player"+i+"_icons", "");
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_team1_player"+i+"_icons", "");
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_team2_player"+i+"_icons", "");

		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_team1_player"+i+"_hp", "");
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_team2_player"+i+"_hp", "");
	}
}

hide_top_header()
{
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_top_name1", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_top_name2", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_top_score1", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_top_score2", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_top_info", "");
}

hide_matchinfo()
{
//3	self setClientCvarIfChanged("ui_streamersystem_matchInfo", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_matchInfo", "");
}

hide_player_progress()
{
//3		self setClientCvarIfChanged("ui_streamersystem_playerProgress", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_playerProgress", "");
}

hide_messages()
{
//3	self setClientCvarIfChanged("ui_streamersystem_message_line1", "");
//3	self setClientCvarIfChanged("ui_streamersystem_message_line2", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_message_line1", "");
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_message_line2", "");
}


ScoreProgress_AddWinner(winner)
{
	if (!level.streamerSystem) return;

	teamLeft = "allies";
	teamRight = "axis";

	// If match info is enabled, ensure teams are in correct sides
	if (game["scr_matchinfo"] == 1 || game["scr_matchinfo"] == 2)
	{
		if (game["match_team1_side"] == "axis")
		{
			teamLeft = "axis";
			teamRight = "allies";
		}
	}

	team = 0; // draw
	if (winner == "allies" && teamLeft == "allies") team = 1; // team left
	if (winner == "allies" && teamRight == "allies") team = 2; // team right
	if (winner == "axis" && teamLeft == "axis") team = 1; // team left
	if (winner == "axis" && teamRight == "axis") team = 2; // team right

	game["streamerSystem_scoreProgress"][game["streamerSystem_scoreProgress"].size] = team;
}

ScoreProgress_AddHalftime()
{
	if (!level.streamerSystem) return;
	game["streamerSystem_scoreProgress"][game["streamerSystem_scoreProgress"].size] = 3; // halftime
}

ScoreProgress_AddOvertime()
{
	if (!level.streamerSystem) return;
	game["streamerSystem_scoreProgress"][game["streamerSystem_scoreProgress"].size] = 4; // overtime
}

ScoreProgress_AddTimeout(callerTeam)
{
	if (!level.streamerSystem) return;

	teamLeft = "allies";
	teamRight = "axis";

	// If match info is enabled, ensure teams are in correct sides
	if (game["scr_matchinfo"] == 1 || game["scr_matchinfo"] == 2)
	{
		if (game["match_team1_side"] == "axis")
		{
			teamLeft = "axis";
			teamRight = "allies";
		}
	}

	team = 0; // unknown
	if (callerTeam == "allies" && teamLeft == "allies") team = 5; // team left
	if (callerTeam == "allies" && teamRight == "allies") team = 6; // team right
	if (callerTeam == "axis" && teamLeft == "axis") team = 5; // team left
	if (callerTeam == "axis" && teamRight == "axis") team = 6; // team right

	game["streamerSystem_scoreProgress"][game["streamerSystem_scoreProgress"].size] = team; // timeout
}





PlayerProgress_Add(allies_alive, axis_alive, winner)
{
	if (!level.streamerSystem) return;

	struct = spawnstruct();
	struct.allies_alive = allies_alive;
	struct.axis_alive = axis_alive;
	struct.winner = winner;	// "", "allies", "axis"

	game["streamerSystem_playerProgress"][game["streamerSystem_playerProgress"].size] = struct;
}


// self can be a player or level
settingsChanged(what)
{
	players = getPlayersByTeam("streamer");
	for (i = 0; i < players.size; i++)
	{
		players[i] thread settingsChangedForPlayer(what);
	}
}

settingsChangedForPlayer(what) // "", auto, xray, damage
{
	self endon("disconnect");

	self notify("streamer_settingsChangedForPlayer");
	self endon("streamer_settingsChangedForPlayer");

	settingsStatus = "";
	if (self.pers["streamerSystem_keysVisible"] || what == "auto")
	{
		if (level.streamerSystem_auto_turnedOn)		settingsStatus += "Auto-spectator: ^2ON    ^7";
		else						settingsStatus += "Auto-spectator: ^1OFF   ^7";
	}
	if (self.pers["streamerSystem_keysVisible"] || what == "xray")
	{
		if (self.pers["streamerSystem_XRAY"])		settingsStatus += "XRAY: ^2ON    ^7";
		else						settingsStatus += "XRAY: ^1OFF   ^7";
	}
	if (self.pers["streamerSystem_keysVisible"] || what == "damage")
	{
		if (self.pers["streamerSystem_damageInfo"])	settingsStatus += "Hits: ^2ON    ^7";
		else						settingsStatus += "Hits: ^1OFF   ^7";
	}
	if ((self.pers["streamerSystem_keysVisible"] || what == "radar") && isDefined(self.pers["streamerSystem_radar"]))
	{
		if (self.pers["streamerSystem_radar"])		settingsStatus += "Radar: ^2ON    ^7";
		else						settingsStatus += "Radar: ^1OFF   ^7";
	}
	if (self.pers["streamerSystem_keysVisible"] || what == "aspect")
		settingsStatus += "XRAY view: ^3" + maps\mp\gametypes\_streamer_xray::aspectName() + "^7";

//3	self setClientCvarIfChanged("ui_streamersystem_settings", settingsStatus);
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_settings", settingsStatus);

	if (self.pers["streamerSystem_keysVisible"] == false && (what == "auto" || what == "xray" || what == "damage" || what == "radar" || what == "aspect"))
	{
		wait level.fps_multiplier * 1;

//3	self setClientCvarIfChanged("ui_streamersystem_settings", "");
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_settings", "");
	}
}



/*
	Top bar cvars go through a per-tick budget: joining the streamer team used to send ~90
	setClientCvar in one server frame (9 per box x 10 boxes + header) and the client dropped
	with "CL_GetServerCommand: A reliable command was cycled out". An unchanged value costs
	nothing; a change over budget is simply sent on a following tick (the cache is only
	updated when the value is really sent). Budget refilled by HUD_PlayerBoxes_Loop.

	Round start: a map_restart leaves every client a moment without acknowledging anything
	(the server only talks to a restarting client once a second, then the client's own restart
	hitch: 0.3-0.6 s on mp_liberation). Every reliable command sent meanwhile waits in the
	64-command buffer of that client; at 65 the server drops it ("Server command overflow").
	The PAM already sends ~25 commands at a spawn, the top bar's round-start refresh was ~50 more
	in 0.3 s: the streamer was kicked at the end of every round. So the loops below wait
	streamerGrace() after their start (= the streamer's spawn of the new round) and the top bar
	sends at most 3 changed cvars a tick (30 a second; a full refresh takes ~2 s).
*/
streamerCvar(cvar, value)
{
	v = value + "";
	last = self.pers["cvar_" + cvar];	// cache of setClientCvarIfChanged (names here are lower case)
	if (isDefined(last) && last == v)
		return;
	if (isDefined(self.streamerSystem_cvarBudget))
	{
		if (self.streamerSystem_cvarBudget <= 0)
			return;
		self.streamerSystem_cvarBudget--;
	}
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged(cvar, v);
}

// Wait until the client is out of its map_restart (see above)
streamerGrace()
{
	wait level.fps_multiplier * 1.5;
}

HUD_PlayerBoxes_Loop()
{
	self endon("disconnect");

	// Started on every streamer spawn: keep a single instance
	self notify("streamerSystem_boxes_loop");
	self endon("streamerSystem_boxes_loop");

	wait level.frame;
	self streamerGrace();
	//wait 1;



	round_kills_printed = false;
	for(;;)
	{
		wait level.fps_multiplier * 0.1;

		self.streamerSystem_cvarBudget = 3;	// changed top bar cvars sent per tick, see streamerCvar

		if (!maps\mp\gametypes\_streamer::isStreamerModeEnabled(self))
		{
			// Player left spectators, hide hud elements
			self thread hide_all();
			return;
		}

		// Anti-ghosting: remember that this player watched the live match
		self maps\mp\gametypes\_streamer::markWatched();

		// If match info is enabled, ensure teams are in correct sides
		teamLeft = "allies";
		teamRight = "axis";
		if (game["scr_matchinfo"] == 1 || game["scr_matchinfo"] == 2)
		{
			if (game["match_team1_side"] == "axis" || game["match_team2_side"] == "allies")
			{
				teamLeft = "axis";
				teamRight = "allies";
			}
		}

		// A FPSChallenge match (cod1plus.so match_teams.c: cod1x_team1_side = where team 1 plays
		// now, from the players' logins): team 1 always on the left - its colour changes at the
		// half-time, not its place, as on a CS2 broadcast
		team1Side = getCvar("cod1x_team1_side");
		if (team1Side == "allies" || team1Side == "axis")
		{
			teamLeft = team1Side;
			teamRight = "axis";
			if (team1Side == "axis")
				teamRight = "allies";
		}

		// Top bar slots: a player keeps his box (and radar dot) for the whole map, dead or alive
		level.streamerSystem_boxesLeft_players = updateSlots("left", teamLeft);
		level.streamerSystem_boxesRight_players = updateSlots("right", teamRight);

		self update_top_header(teamLeft, teamRight);

		allies_color = "^4"; // blue
		axis_color = "^1"; // red
		if (self.pers["streamerSystem_colorMode"] == 2)
		{
			allies_color = "^5"; // allies8
			axis_color = "^6"; // axis9
		}

		//allies_color = "^8"; // allies color
		//axis_color = "^9"; // axis color


		// Up to 9 lines can be filled with data
		matchInfo = "";
		matchInfoLines = 0;


		// Custom text from cvars
		streamerSystem_file_lines = [];
		for (i = 1; i <= 4; i++)
		{
			s = getCvar("scr_streamer_text" + i);
			if (s != "")
			{
				streamerSystem_file_lines[streamerSystem_file_lines.size] = s;
			}
		}
/*
		streamerSystem_file_lines[0] = "NEWERA vs ARMIA";
		streamerSystem_file_lines[1] = "0:0  Ready-Up  Toujane  (Burgundy 13:10)";
		streamerSystem_file_lines[2] = "ENTROPIQ vs d O G z";
		streamerSystem_file_lines[3] = "3:3  Round 7/24  Dawnville";
*/
/*
		streamerSystem_file_lines[0] = "game[scr_matchinfo] = " + game["scr_matchinfo"];
		streamerSystem_file_lines[1] = "game[match_team1_side] = " + game["match_team1_side"] + "  (game[match_team1_name] = "+game["match_team1_name"]+")";
		streamerSystem_file_lines[2] = "game[match_team2_side] = " + game["match_team2_side"] + "  (game[match_team2_name] = "+game["match_team2_name"]+")";;
		streamerSystem_file_lines[3] = "teamLeft = " + teamLeft;
		streamerSystem_file_lines[4] = "teamRight = " + teamRight;
*/


		if (streamerSystem_file_lines.size > 0)
		{
			for (i = 0; i < streamerSystem_file_lines.size; i++)
			{
				matchInfo += streamerSystem_file_lines[i] + "\n";
				matchInfoLines++;
			}
			matchInfo += "\n";
			matchInfoLines++;
		}

		// Map history
		mapsCount = 0;
		for (j = 3; j >= 1; j--)
		{
			map = maps\mp\gametypes\_matchinfo::GetMapName(getCvar("sv_map" + j + "_name")); // set sv_map1_name
			if (map != "")
			{
				mapsCount++;
				score1 = getCvarInt("sv_map" + j + "_score1"); // set sv_map1_score1
				score2 = getCvarInt("sv_map" + j + "_score2");

				str = "Map " + mapsCount + ":  " + map + " ";

				if (score1 > score2) {
					if (teamLeft == "allies") str += allies_color; // blue
					if (teamLeft == "axis") str += axis_color; // red
				}
				if (score2 > score1) {
					if (teamRight == "allies") str += allies_color; // blue
					if (teamRight == "axis") str += axis_color; // red
				}
				str += score1 + ":" + score2;

				matchInfo += str + "^7\n";
				matchInfoLines++;
			}
		}


		if (game["match_totaltime_text"] != "")
		{
			matchInfo += "Match time:   " + game["match_totaltime_text"] + "\n";
			matchInfoLines++;
		}

		// Score progress
		if (game["streamerSystem_scoreProgress"].size > 0)
		{
			str = "";
			for (i = 0; i < game["streamerSystem_scoreProgress"].size; i++)
			{
				code = game["streamerSystem_scoreProgress"][i];
				if (code == 0) // Draw
					str += "^7-";
				else if (code == 1) // team left winner
				{
					if (teamLeft == "allies") str += "" + allies_color + "#"; // blue
					if (teamLeft == "axis") str += "" + axis_color + "#"; // red
				}
				else if (code == 2) // team right winner
				{
					if (teamRight == "allies") str += "" + allies_color + "#"; // blue
					if (teamRight == "axis") str += "" + axis_color + "#"; // red
				}
				else if (code == 3) // halftime
				{
					str += "^7|";
				}
				else if (code == 4) // overtime
				{
					str += "^7 [O] ";
				}
				else if (code == 5) // timeout team left
				{
					if (teamLeft == "allies") str += "^7[" + allies_color + "T^7]"; // blue
					if (teamLeft == "axis") str += "^7[" + axis_color + "T^7]"; // red
				}
				else if (code == 6) // timeout team right
				{
					if (teamRight == "allies") str += "^7[" + allies_color + "T^7]"; // blue
					if (teamRight == "axis") str += "^7[" + axis_color + "T^7]"; // red
				}

			}

			matchInfo += "Score progress:\n";
			matchInfoLines++;
			matchInfo += str + "\n";
			matchInfoLines++;
		}

		// Fill with new lines at top
		for (i = matchInfoLines; i < 11; i++)
		{
			matchInfo = "\n" + matchInfo;
		}

//3		self setClientCvarIfChanged("ui_streamersystem_matchInfo", matchInfo);
		// the 1.6X broadcast has its own match tracker: the PAM text stays off for a native streamer
		if (maps\mp\gametypes\_streamer_native::isNative(self))
			matchInfo = "";
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_matchInfo", matchInfo);


		// Hide player progress and boxes in readyup and intermission
		if (game["state"] == "intermission") // readyup in case timeout is called
		{
			self thread hide_player_boxes();
			self thread hide_player_progress();
			self thread hide_messages();
			continue;
		}


		// Hide while in killcam, but not in the final killcam
		if (isDefined(self.killcam) && !(level.gametype == "sd" && level.roundended))
		{
			self thread hide_player_boxes();
			self thread hide_messages();
			continue;
		}

		// Fill bars (slots may have holes: a player who left frees his box, nobody moves)
		for(r = 0; r < 5; r++)
		{
			if (isDefined(level.streamerSystem_boxesLeft_players[r]))
				self fill_box(r, "left", teamLeft, level.streamerSystem_boxesLeft_players[r]);
			else
				self unfill_box(r, "left");

			if (isDefined(level.streamerSystem_boxesRight_players[r]))
				self fill_box(r, "right", teamRight, level.streamerSystem_boxesRight_players[r]);
			else
				self unfill_box(r, "right");
		}



		// Hide player progress and boxes in readyup and intermission
		if (level.in_readyup) // readyup in case timeout is called
		{
			self thread hide_player_progress();
			self thread hide_messages();
			continue;
		}
//k217_killfeed
		// print current killfeed variable value to streamer
		// the 1.6X broadcast has its own kill feed
		if (maps\mp\gametypes\_streamer_native::isNative(self))
			self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamer_killfeed", "");
		else
			self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamer_killfeed", game["streamer_killfeed"]);

//was deactivated
/*
		// Player progress
		playerProgress = "";
		for (i = 0; i < game["streamerSystem_playerProgress"].size; i++)
		{
			data = game["streamerSystem_playerProgress"][i];

			// If match info is enabled, ensure teams are in correct sides
			alive_text = data.allies_alive + "v" + data.axis_alive;
			if (teamLeft == "axis")
				alive_text = data.axis_alive + "v" + data.allies_alive;

			color = "^7";
			if (data.winner == "allies") 	color = allies_color;
			else if (data.winner == "axis") color = axis_color;

			playerProgress += color + alive_text + "  ";
//log		logprint("_streamer_hud:: playerProgress=" + "\n");
		}
//3		self setClientCvarIfChanged("ui_streamersystem_playerProgress", playerProgress);
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_playerProgress", playerProgress);
*/


//bgoff new
		bgOnOff = "0";
		message1 = "";
		message2 = "";
		if (level.gametype == "sd" && !level.roundended)
		{
			players = getentarray("player", "classname");
			for(i = 0; i < players.size; i++)
			{
				if (players[i].bombinteraction)
				{
					bgOnOff = "1";
//3					message1 = removeColorsFromString(players[i].name);
					message1 = maps\mp\gametypes\global\_global::removeColorsFromString(players[i].name);
					if (level.bombplanted)
						message2 = "^1is defusing the bomb"; // red
					else
						message2 = "^3is planting the bomb"; // yellow
					break;
				} 
				else 
				{
					bgOnOff = "0";
				}
			}
		}
//3		self setClientCvarIfChanged("ui_streamersystem_message_line1", message1);
//3		self setClientCvarIfChanged("ui_streamersystem_message_line2", message2);
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_message_bg", bgOnOff);
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_message_line1", message1);
		self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_message_line2", message2);




		// Printing player at the end of the round with the most kills
		if (level.gametype == "sd" &&
			level.roundended &&
			isDefined(level.roundwinner) && (level.roundwinner == "allies" || level.roundwinner == "axis") &&
			round_kills_printed == false)
		{
			players = getPlayersByTeam(level.roundwinner);

			playerMaxKills = undefined;
			for (i = 0; i < players.size; i++)
			{
				if (isDefined(players[i].pers["round_kills"]) && players[i].pers["round_kills"] >= 1)
				{
					if (!isDefined(playerMaxKills) || players[i].pers["round_kills"] > playerMaxKills.pers["round_kills"])
						playerMaxKills = players[i];
				}
			}

			if (isDefined(playerMaxKills) && playerMaxKills.pers["round_kills"] >= 4)
			{
				self iprintlnbold(playerMaxKills.name + "^7 with ^2" + playerMaxKills.pers["round_kills"] + "^7 kills in this round!");
			}

			round_kills_printed = true;
		}
	}
}


followPlayerByNum(num)
{
	if (num < 1 || num > 10) return;

	player = undefined;
	// slots can have holes, index them directly
	if (num >= 1 && num <= 5)
		player = level.streamerSystem_boxesLeft_players[num - 1];

	if (num >= 6 && num <= 10)
		player = level.streamerSystem_boxesRight_players[num - 6];

	if (isDefined(player))
	{
		if (player.sessionstate == "playing")
		{
			level maps\mp\gametypes\_streamer::followPlayer(player);
			level maps\mp\gametypes\_streamer_auto::lockFor(30000); // Lock selected player for 30 secods
			//self iprintln("Follow player " + num/* + ": " + player.name*/);
		}
		else
			self iprintln("^3Player " + num + " is not alive");
	}
	else
		self iprintln("^3Player " + num + " does not exists");
}


/*
	Sticky slots of one side of the top bar. game[] survives the round restarts, so a player
	keeps his slot (box, number key, radar dot) for the whole map: dead players stay in place
	(greyed by the menu) and are alive again next round, nobody is reordered. A player who
	leaves the team frees his slot, a newcomer takes the first free one. Stored as client
	numbers, never as entities (entities do not survive the round restart).
	Returns slot -> player, undefined for an empty slot.
*/
updateSlots(side, team)
{
	key = "streamerSystem_slots_" + side;
	if (!isDefined(game[key]))
	{
		empty = [];
		for (i = 0; i < 5; i++)
			empty[i] = -1;
		game[key] = empty;
	}
	slots = game[key];

	players = getPlayersByTeam(team);
	result = [];

	// players still in this team keep their slot
	for (i = 0; i < 5; i++)
	{
		if (slots[i] == -1)
			continue;
		for (p = 0; p < players.size; p++)
		{
			if (players[p] getEntityNumber() == slots[i])
			{
				result[i] = players[p];
				break;
			}
		}
		if (!isDefined(result[i]))
			slots[i] = -1;
	}

	// newcomers take the first free slot (a 6th player has no box)
	for (p = 0; p < players.size; p++)
	{
		num = players[p] getEntityNumber();
		placed = false;
		for (i = 0; i < 5; i++)
			if (slots[i] == num)
				placed = true;
		if (placed)
			continue;
		for (i = 0; i < 5; i++)
		{
			if (slots[i] == -1)
			{
				slots[i] = num;
				result[i] = players[p];
				break;
			}
		}
	}

	game[key] = slots;
	return result;
}

// Team names, scores and round state in the middle of the top bar
update_top_header(teamLeft, teamRight)
{
	info = "";
	if (isDefined(level.in_readyup) && level.in_readyup)
		info = "READY-UP";
	else if (isDefined(level.in_bash) && level.in_bash)
		info = "BASH";
	else if (game["state"] == "intermission")
		info = "FINAL";
	else if (level.gametype == "sd" && isDefined(level.bombplanted) && level.bombplanted)
		info = "^1BOMB PLANTED";
	else if (isDefined(level.in_strattime) && level.in_strattime)
		info = "STRAT TIME";
	else if (isDefined(game["round"]))
		info = "ROUND " + game["round"];

	self streamerCvar("ui_streamersystem_top_name1", top_team_name(teamLeft));
	self streamerCvar("ui_streamersystem_top_name2", top_team_name(teamRight));
	self streamerCvar("ui_streamersystem_top_tag1", top_team_tag(teamLeft));
	self streamerCvar("ui_streamersystem_top_tag2", top_team_tag(teamRight));
	self streamerCvar("ui_streamersystem_top_score1", getTeamScore(teamLeft));
	self streamerCvar("ui_streamersystem_top_score2", getTeamScore(teamRight));
	self streamerCvar("ui_streamersystem_top_info", info);
}

top_team_name(team)
{
	// a FPSChallenge match: the real team name on that side (cod1plus.so match_teams.c)
	name = getCvar("cod1x_team_" + team);
	if (name != "")
		return maps\mp\gametypes\global\_global::getsubstr(name, 0, 28);
	if (isDefined(game["scr_matchinfo"]) && game["scr_matchinfo"] > 0)
	{
		for (t = 1; t <= 2; t++)
		{
			side = game["match_team" + t + "_side"];
			name = game["match_team" + t + "_name"];
			if (isDefined(side) && side == team && isDefined(name) && name != "")
				return maps\mp\gametypes\global\_global::getsubstr(name, 0, 28);
		}
	}
	if (team == "allies")
		return "ALLIES";
	return "AXIS";
}

// the tag of the team on that side (a FPSChallenge match), "" else: the 1.6X overlay's team tile
top_team_tag(team)
{
	return maps\mp\gametypes\global\_global::getsubstr(getCvar("cod1x_tag_" + team), 0, 6);
}

getPlayersByTeam(teamname)
{
	playersFiltered = [];
	index = 0;
	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		player = players[i];

		if (!isDefined(teamname) || player.pers["team"] == teamname)
		{
			playersFiltered[index] = player;
			index++;
		}
	}

	// Sort and return
	return playersFiltered;
}


fill_box(index, barSide, teamname, player)
{
//kikiii added this whole block
//v215 added score & deaths
	score = 0;
	deaths = 0;
	playerHealth = 0;
	weapon1 = "none";
	weapon2 = "none";
	stats = undefined;
	grenades = 0;
	smokes = 0;
	playerIsReady = false;
	playerName = undefined;
	roundKills = 0;

	if (isDefined(player)) 
	{
//v215 added score & deaths
		score = player.score;
		deaths = player.deaths;
		playerHealth = player.health;
		if (player.sessionstate != "playing")
			playerHealth = 0;	// dead this round: whatever health the spectator state keeps
		weapon1 = player getweaponslotweapon("primary");
    	weapon2 = player getweaponslotweapon("primaryb");
		weapon1 = maps\mp\gametypes\_weapons::getWeaponName2(weapon1);
		weapon2 = maps\mp\gametypes\_weapons::getWeaponName2(weapon2);
		stats = player maps\mp\gametypes\_menu_scoreboard::getPlayerStats();
		grenades = player maps\mp\gametypes\_weapons::getFragGrenadeCount();
		smokes = player maps\mp\gametypes\_weapons::getSmokeGrenadeCount();
		playerIsReady = player.isReady;
		playerName = player.name;

//v215 changed roundKills = player.pers["round_kills"];
		if (isDefined(player.pers["round_kills"]))
		{
			roundKills = player.pers["round_kills"];
		}
	}
//--
	teamNum = "1";
	if (barSide == "right")
		teamNum = "2";

	health = "";
	if (playerHealth <= 0)
		health = "0";


	// Because health is showed via menu elements, the health bar is splited only into a few sizes
	// So according to helth we select most corresponding size
	if (playerHealth <= 0)
		health =  "0";
//w	else
//w		health = "" + playerHealth;
	else if (playerHealth < 20)
		health =  "10";

	else if (playerHealth < 70)
		health =  "50";

	else if (playerHealth < 99)
		health =  "80";

	else
		health =  "100";

	// Health also contains apended info about color
	if (playerHealth > 0)
	{
	      	if (teamname == "allies")
			health = health + "_allies";
		else
			health = health + "_axis";
	}


	if (self.streamerSystem_turnedOn && isDefined(level.streamerSystem_player) && player == level.streamerSystem_player)
	{
		health = health + "_"; // underscore means this player is followed and rectangle around player box is showed
	}



	// anytime in future readyups show player statistics instead of weapon
	inStatsMode = level.in_readyup && game["readyup_first_run"] == false && level.gametype == "sd" && game["roundsplayed"] >= 1;



	// Weapon names are already set in the isDefined(player) block above
	// No need to fetch them again here
	
	weapon_text = "";
	if (inStatsMode)
	{
		if (isDefined(stats))
		{
			weapon_text = "A " + stats["assists"] + "  P " + stats["plants"] + "  D " + stats["defuses"];	// fits a top bar box
		}
	}
	else if (playerHealth > 0)
	{
		if (weapon2 == "none" || weapon2 == "Pistol")
			weapon_text = weapon1;
		else
			weapon_text = weapon1 + " / " + weapon2;
	}




	/* Icons
	Combinations:
		"" 		- no icons
		"grenade" 	- show grenade icon
		"grenade2" 	- show multi-grenade icons
		"smoke" 	- show smoke icon
		"grenade_smoke" - show grenade and smoke icons
		"grenade2_smoke" - show multi-grenade and smoke icons
	*/
	icons = "";
	if (playerHealth > 0 && inStatsMode == false)
	{
//3		grenades = player maps\mp\gametypes\_weapons::getFragGrenadeCount();
//3		smokes = player maps\mp\gametypes\_weapons::getSmokeGrenadeCount();
//3
		if (grenades >= 2)
			icons += "grenade2";
		else if (grenades == 1)
			icons += "grenade";

//3		if (smokes > 0)
//3		{
//3			if (icons != "")
//3				icons += "_";
//3			icons += "smoke";
//3		}
	}

	// Kills in round
	kills_added = "";
//3	if (isDefined(player.pers["round_kills"]) && player.pers["round_kills"] != 0 && inStatsMode == false)
	if (roundKills != 0 && inStatsMode == false)
	{
//3		if (player.pers["round_kills"] > 0) 	kills_added = "^2+" + player.pers["round_kills"] + "^7";
//3		else					kills_added = "^1" + player.pers["round_kills"] + "^7";
		if (roundKills > 0) 	kills_added = "^2+" + roundKills + "^7";
		else					kills_added = "^1" + roundKills + "^7";
	}

	// Player name (the box draws its number key itself, the name is cut to fit the box)
	name = "";

	// Player existing and playerIsReady
	if (level.in_readyup && isDefined(player))
	{
		if (playerIsReady) 	name += "^2o^7 ";
		else		 	name += "^1o^7 ";
	}
//3	name += removeColorsFromString(player.name);
	if (isDefined(playerName))
	{
		shortName = maps\mp\gametypes\global\_global::removeColorsFromString(playerName);
		if (shortName.size > 10)
			shortName = maps\mp\gametypes\global\_global::getsubstr(shortName, 0, 9) + ".";
		name += shortName;
	}
	else
    	name += "No Player - Undefined Player";

	// Exact HP: text + a 10-step bar ("" hides the bar)
	hp = "";
	hptext = "";
	if (playerHealth > 0)
	{
		hp = "" + (int)((playerHealth + 9) / 10);
		if (playerHealth > 100) hp = "10";
		hptext = "" + playerHealth;
		if (playerHealth < 30) hptext = "^1" + hptext;
	}
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_hp",		hp);
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_hptext",	hptext);
//k	name += maps\mp\gametypes\global\_global::removeColorsFromString(playerName);
//3	self setClientCvarIfChanged("ui_streamersystem_team"+teamNum+"_player"+index+"_health",		health);
//3	self setClientCvarIfChanged("ui_streamersystem_team"+teamNum+"_player"+index+"_name",		name);
//3	self setClientCvarIfChanged("ui_streamersystem_team"+teamNum+"_player"+index+"_score",		player.score + " / " + player.deaths);
//3	self setClientCvarIfChanged("ui_streamersystem_team"+teamNum+"_player"+index+"_weapon",		weapon_text);
//3	self setClientCvarIfChanged("ui_streamersystem_team"+teamNum+"_player"+index+"_round_kills",	kills_added);
//3	self setClientCvarIfChanged("ui_streamersystem_team"+teamNum+"_player"+index+"_icons",		icons);

	//logPrint("fillbox " + name + "\n");
	//self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_team"+teamNum+"_player"+index+"_num",		(index+1));
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_health",		health);
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_name",		name);
//3	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_team"+teamNum+"_player"+index+"_score",		player.score + " / " + player.deaths);
	// _score and _round_kills are not drawn by the top bar: not sent any more (reliable command budget)
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_weapon",		weapon_text);
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_icons",		icons);
//k	wait .10;
//F	wait level.fps_multiplier * 0.1;
}


unfill_box(index, barSide)
{
	teamNum = "1";
	if (barSide == "right")
		teamNum = "2";

	// Text does not need to be updated, because is hided automatically if healht is empty
//3	//setClientCvarIfChanged("ui_streamersystem_team"+teamNum+"_player"+index+"_text", "");

//3	self setClientCvarIfChanged("ui_streamersystem_team"+teamNum+"_player"+index+"_health", "");
//3	self setClientCvarIfChanged("ui_streamersystem_team"+teamNum+"_player"+index+"_icons", "");
//end 3
//kikiii added this block
	// vcod doesnt work?
	//logPrint("unfillbox emptyName " + "\n");
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_name", "");
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_weapon", "");
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_health", "");
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_icons", "");
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_hp", "");
	self streamerCvar("ui_streamersystem_team"+teamNum+"_player"+index+"_hptext", "");

//k	wait .10;
//F	wait level.fps_multiplier * 0.1;
}