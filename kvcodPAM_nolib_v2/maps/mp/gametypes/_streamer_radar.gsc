/*
	_streamer_radar.gsc - radar of the streamer overlay (top-left, CS:GO caster style)

	Only a player accepted by maps\mp\gametypes\_streamer::isStreamerModeEnabled() gets it.
	Positions are read on the server, so the radar is exact (no line of sight involved).

	Drawing: a fixed pool of NON-archived client hudelems (a spectator never sees his own
	archived hudelems while he follows a player), created once when the radar is shown:
		1 background + 10 player dots + bombsite A + bombsite B + planted bomb = 14
	of the 31 non-archived hudelems a CoD1 client can display. Dot i is top-bar slot i
	(1-5 left team, 6-0 right team, same order as the boxes), dots glide with moveOverTime.
	The border is drawn by the streamer menu (cvar ui_streamersystem_radar): menus are drawn
	above hudelems, so the dark background has to be a hudelem or it would cover the dots.

	CoD1 ships no overview image for any map, so the PAM brings its own: a top-down drawing of
	each map generated from its BSP (tools/gen_radar_overviews.py -> gfx/streamer/overview/ and
	_streamer_radar_maps.gsc, which holds the exact world window of each drawing). A map without
	a drawing gets a dark square and a window fitted on the spawn points + bombsites that grows
	with the positions players actually reach (learned over the rounds, applied at the next
	round: the radar never rescales mid-round).
*/

init()
{
	logprint("_streamer_radar::init\n");

	if (!level.streamerSystem)
		return;

	if (game["firstInit"])
	{
		for (i = 0; i < 8; i++)
			precacheShader("gfx/streamer/radar_dir" + i + ".tga");
		precacheShader("gfx/streamer/radar_dead.tga");
		precacheShader("black");

		// Background of this map, drawn from its BSP (tools/gen_radar_overviews.py): one
		// shader per map. Remembered in game[] so a later round never uses an image that
		// was not precached (setShader would fail).
		game["streamerRadar_image"] = undefined;
		c = getStreamerMapConfig(getCvar("mapname"));
		if (isDefined(c) && isDefined(c.image))
		{
			precacheShader(c.image);
			game["streamerRadar_image"] = c.image;
		}
		if (level.gametype == "sd")
		{
			// already precached by sd.gsc, repeated so this file does not depend on it
			precacheShader("gfx/hud/hud@objectiveA.tga");
			precacheShader("gfx/hud/hud@objectiveB.tga");
			precacheShader("gfx/hud/hud@bombplanted.tga");
		}
	}

	// Screen rectangle of the radar (640x480 virtual screen, same as the streamer menu)
	level.streamerRadar_x = 4;
	level.streamerRadar_y = 48;
	level.streamerRadar_size = 128;

	maps\mp\gametypes\global\_global::addEventListener("onConnected", ::onConnected);
}

onConnected()
{
	if (!isDefined(self.pers["streamerSystem_radar"]))
		self.pers["streamerSystem_radar"] = true;
}

// M key in the streamer menu
toggle()
{
	self.pers["streamerSystem_radar"] = !self.pers["streamerSystem_radar"];
	self thread maps\mp\gametypes\_streamer_hud::settingsChangedForPlayer("radar");
}


/*
	Per-map radar window. Return undefined to use the automatic fit (default for every map).
	Fields (world units / degrees):
		c.x, c.y   world point at the centre of the radar
		c.span     world distance covered by the radar width
		c.up       world yaw that points to the top of the radar (90 = +Y, the default)
	A server can also set it without editing the PAM, in the same order:
		set scr_streamer_radar_mp_harbor "cx cy size up"
*/
getStreamerMapConfig(mapname)
{
	c = undefined;

	s = getCvar("scr_streamer_radar_" + mapname);
	if (s != "")
	{
		parts = maps\mp\gametypes\global\_global::splitString(s, " ");
		if (parts.size >= 3)
		{
			c = spawnstruct();
			c.x = stringToFloat(parts[0]);
			c.y = stringToFloat(parts[1]);
			c.span = stringToFloat(parts[2]);
			c.up = 90;
			if (parts.size >= 4)
				c.up = stringToFloat(parts[3]);
			if (c.span < 100)
				c = undefined;
		}
	}

	// Built-in: every map the server ships has a top-down image and its exact window,
	// generated from the BSP (_streamer_radar_maps.gsc, tools/gen_radar_overviews.py).
	// The cvar above wins, without image: its window would not match the drawing.
	if (!isDefined(c))
		c = maps\mp\gametypes\_streamer_radar_maps::getOverview(maps\mp\gametypes\global\_global::toLower(mapname));

	return c;
}

// GSC has no string to number cast: go through a scratch cvar
stringToFloat(s)
{
	setCvar("tmp_streamer_radar", s);
	return getCvarFloat("tmp_streamer_radar");
}


// World window of the radar for this round
radarWindow()
{
	win = spawnstruct();
	win.up = 90;

	c = getStreamerMapConfig(level.mapname);
	if (isDefined(c))
	{
		win.x = c.x;
		win.y = c.y;
		win.span = c.span;
		win.up = c.up;
		if (isDefined(c.image) && isDefined(game["streamerRadar_image"]) && game["streamerRadar_image"] == c.image)
			win.image = c.image;
	}
	else
	{
		mins = undefined;
		maxs = undefined;

		classnames = [];
		classnames[classnames.size] = "mp_searchanddestroy_spawn_allied";
		classnames[classnames.size] = "mp_searchanddestroy_spawn_axis";
		classnames[classnames.size] = "mp_teamdeathmatch_spawn";
		classnames[classnames.size] = "mp_deathmatch_spawn";
		classnames[classnames.size] = "mp_retrieval_spawn_allied";
		classnames[classnames.size] = "mp_retrieval_spawn_axis";

		points = [];
		for (k = 0; k < classnames.size; k++)
		{
			ents = getentarray(classnames[k], "classname");
			for (i = 0; i < ents.size; i++)
				points[points.size] = ents[i].origin;
		}
		zone = getent("bombzone_A", "targetname"); if (isDefined(zone)) points[points.size] = zone.origin;
		zone = getent("bombzone_B", "targetname"); if (isDefined(zone)) points[points.size] = zone.origin;
		if (isDefined(game["streamerRadar_min"])) points[points.size] = game["streamerRadar_min"];
		if (isDefined(game["streamerRadar_max"])) points[points.size] = game["streamerRadar_max"];

		for (i = 0; i < points.size; i++)
		{
			p = points[i];
			if (!isDefined(mins)) { mins = p; maxs = p; continue; }
			mins = (min(mins[0], p[0]), min(mins[1], p[1]), 0);
			maxs = (max(maxs[0], p[0]), max(maxs[1], p[1]), 0);
		}

		if (!isDefined(mins))
		{
			mins = (-2000, -2000, 0);
			maxs = (2000, 2000, 0);
		}

		win.x = (mins[0] + maxs[0]) / 2;
		win.y = (mins[1] + maxs[1]) / 2;
		win.span = max(maxs[0] - mins[0], maxs[1] - mins[1]) * 1.15 + 600;
		if (win.span < 1500)
			win.span = 1500;
	}

	win.upX = cos(win.up);
	win.upY = sin(win.up);
	win.scale = win.span / level.streamerRadar_size;	// world units per screen unit
	return win;
}

min(a, b) { if (a < b) return a; return b; }
max(a, b) { if (a > b) return a; return b; }

// World position -> (screen x, screen y, 1 if clamped on the border else 0)
worldToRadar(win, pos)
{
	dx = pos[0] - win.x;
	dy = pos[1] - win.y;

	// right = up rotated 90 degrees clockwise
	u = dx * win.upX + dy * win.upY;
	r = dx * win.upY - dy * win.upX;

	half = level.streamerRadar_size / 2;
	limit = half - 5;
	sx = r / win.scale;
	sy = -1 * u / win.scale;

	clamped = 0;
	low = 0 - limit;	// no unary minus on a variable in CoD1 script
	if (sx > limit) { sx = limit; clamped = 1; }
	if (sx < low)   { sx = low;   clamped = 1; }
	if (sy > limit) { sy = limit; clamped = 1; }
	if (sy < low)   { sy = low;   clamped = 1; }

	return (level.streamerRadar_x + half + sx, level.streamerRadar_y + half + sy, clamped);
}

// 0 = nose up, then clockwise by 45 degrees
directionIndex(win, yaw)
{
	cw = win.up - yaw;
	while (cw < 0) cw += 360;
	while (cw >= 360) cw -= 360;
	i = (int)((cw + 22.5) / 45);
	if (i >= 8) i = 0;
	return i;
}


Radar_Create()
{
	x = level.streamerRadar_x;
	y = level.streamerRadar_y;
	s = level.streamerRadar_size;

	self.streamerRadar_bg = maps\mp\gametypes\global\_global::newClientHudElem2(self);
	self.streamerRadar_bg.archived = false;
	self.streamerRadar_bg.x = x;
	self.streamerRadar_bg.y = y;
	self.streamerRadar_bg.alignX = "left";
	self.streamerRadar_bg.alignY = "top";
	self.streamerRadar_bg.sort = -2;
	if (isDefined(self.streamerRadar_win.image))
	{
		self.streamerRadar_bgAlpha = 0.9;		// the map drawing
		self.streamerRadar_bg setShader(self.streamerRadar_win.image, s, s);
	}
	else
	{
		self.streamerRadar_bgAlpha = 0.55;	// no drawing for this map: dark square
		self.streamerRadar_bg setShader("black", s, s);
	}
	self.streamerRadar_bg.alpha = self.streamerRadar_bgAlpha;

	self.streamerRadar_dots = [];
	for (i = 0; i < 10; i++)
	{
		dot = maps\mp\gametypes\global\_global::newClientHudElem2(self);
		dot.archived = false;
		dot.alignX = "center";
		dot.alignY = "middle";
		dot.x = x + s / 2;
		dot.y = y + s / 2;
		dot.sort = 2;
		dot.alpha = 0;
		dot.shaderNow = "";
		dot.pxNow = 0;
		self.streamerRadar_dots[i] = dot;
	}

	self.streamerRadar_sites = [];
	if (level.gametype == "sd")
	{
		names = [];
		names[0] = "A";
		names[1] = "B";
		for (i = 0; i < 2; i++)
		{
			zone = getent("bombzone_" + names[i], "targetname");
			if (!isDefined(zone))
				continue;
			p = worldToRadar(self.streamerRadar_win, zone.origin);
			site = maps\mp\gametypes\global\_global::newClientHudElem2(self);
			site.archived = false;
			site.alignX = "center";
			site.alignY = "middle";
			site.x = p[0];
			site.y = p[1];
			site.sort = 1;
			site.alpha = 0.9;
			site setShader("gfx/hud/hud@objective" + names[i] + ".tga", 12, 12);
			self.streamerRadar_sites[self.streamerRadar_sites.size] = site;
		}

		self.streamerRadar_bomb = maps\mp\gametypes\global\_global::newClientHudElem2(self);
		self.streamerRadar_bomb.archived = false;
		self.streamerRadar_bomb.alignX = "center";
		self.streamerRadar_bomb.alignY = "middle";
		self.streamerRadar_bomb.sort = 3;
		self.streamerRadar_bomb.alpha = 0;
		self.streamerRadar_bomb.color = (1, 0.25, 0.2);
		self.streamerRadar_bomb setShader("gfx/hud/hud@bombplanted.tga", 11, 11);
	}
}

Radar_Stop()
{
	self notify("streamerSystem_radar_loop");
	self Radar_Destroy();
}

Radar_Destroy()
{
	if (isDefined(self.streamerRadar_bg))
		self.streamerRadar_bg destroy();
	self.streamerRadar_bg = undefined;

	if (isDefined(self.streamerRadar_dots))
		for (i = 0; i < self.streamerRadar_dots.size; i++)
			if (isDefined(self.streamerRadar_dots[i]))
				self.streamerRadar_dots[i] destroy();
	self.streamerRadar_dots = undefined;

	if (isDefined(self.streamerRadar_sites))
		for (i = 0; i < self.streamerRadar_sites.size; i++)
			if (isDefined(self.streamerRadar_sites[i]))
				self.streamerRadar_sites[i] destroy();
	self.streamerRadar_sites = undefined;

	if (isDefined(self.streamerRadar_bomb))
		self.streamerRadar_bomb destroy();
	self.streamerRadar_bomb = undefined;

	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_radar", "0");
}

Radar_SetVisible(visible)
{
	alpha = 0;
	siteAlpha = 0;
	if (visible)
	{
		alpha = self.streamerRadar_bgAlpha;
		siteAlpha = 0.9;
	}
	if (self.streamerRadar_bg.alpha != alpha)
		self.streamerRadar_bg.alpha = alpha;
	for (i = 0; i < self.streamerRadar_sites.size; i++)
		if (self.streamerRadar_sites[i].alpha != siteAlpha)
			self.streamerRadar_sites[i].alpha = siteAlpha;
	if (!visible)
	{
		for (i = 0; i < self.streamerRadar_dots.size; i++)
			self.streamerRadar_dots[i].alpha = 0;
		if (isDefined(self.streamerRadar_bomb))
			self.streamerRadar_bomb.alpha = 0;
	}

	v = "0";
	if (visible)
		v = "1";
	self maps\mp\gametypes\global\_global::setClientCvarIfChanged("ui_streamersystem_radar", v);
}


/*
	self is the streamer. Started on every streamer spawn (so on every round), a single
	instance runs: a new start ends the previous one.
*/
Radar_Loop()
{
	self endon("disconnect");
	self notify("streamerSystem_radar_loop");
	self endon("streamerSystem_radar_loop");

	self Radar_Destroy();

	if (!isDefined(self.pers["streamerSystem_radar"]))
		self.pers["streamerSystem_radar"] = true;

	self.streamerRadar_win = radarWindow();
	lastPos = [];		// where each slot's player was last seen alive this round
	blink = false;

	for (;;)
	{
		wait level.fps_multiplier * 0.1;

		if (!maps\mp\gametypes\_streamer::isStreamerModeEnabled(self))
			break;

		wanted = self.pers["streamerSystem_radar"] && level.scr_streamer_radar;
		if (!wanted)
		{
			if (isDefined(self.streamerRadar_bg))
				self Radar_Destroy();
			continue;
		}

		if (!isDefined(self.streamerRadar_bg))
			self Radar_Create();

		// Killcam replays the past and the intermission has no round: hide, keep the pool
		if (isDefined(self.killcam) || game["state"] == "intermission")
		{
			self Radar_SetVisible(false);
			continue;
		}
		self Radar_SetVisible(true);

		win = self.streamerRadar_win;

		// Slots filled by the top bar (_streamer_hud::HUD_PlayerBoxes_Loop)
		sides = [];
		sides[0] = level.streamerSystem_boxesLeft_players;
		sides[1] = level.streamerSystem_boxesRight_players;

		live = maps\mp\gametypes\_streamer::isMatchLive();

		followed = undefined;
		if (self.streamerSystem_turnedOn && isDefined(level.streamerSystem_player))
			followed = level.streamerSystem_player;

		for (s = 0; s < 2; s++)
		{
			for (i = 0; i < 5; i++)
			{
				idx = s * 5 + i;
				dot = self.streamerRadar_dots[idx];

				player = undefined;
				if (isDefined(sides[s]))
					player = sides[s][i];

				if (!isDefined(player) || !isPlayer(player))
				{
					lastPos[idx] = undefined;
					if (dot.alpha != 0) dot.alpha = 0;
					continue;
				}

				alive = player.sessionstate == "playing";
				if (alive)
				{
					pos = player.origin;
					lastPos[idx] = pos;
					// only real match positions, and not a far outlier (noclip, spawned out of the map)
					if (live && pos[0] - win.x < win.span && win.x - pos[0] < win.span && pos[1] - win.y < win.span && win.y - pos[1] < win.span)
						learnBounds(pos);
				}
				else if (isDefined(lastPos[idx]))
					pos = lastPos[idx];
				else
				{
					if (dot.alpha != 0) dot.alpha = 0;	// dead since before this radar started
					continue;
				}

				p = worldToRadar(win, pos);

				if (alive)
				{
					shader = "gfx/streamer/radar_dir" + directionIndex(win, player.angles[1]) + ".tga";
					size = 10;
					if (isDefined(followed) && player == followed)
						size = 14;
					if (player.pers["team"] == "allies")	color = (0.40, 0.62, 1.00);
					else					color = (1.00, 0.34, 0.28);
					alpha = 1;
					if (p[2] == 1)
						alpha = 0.55;		// outside the radar window: pinned on the border
				}
				else
				{
					shader = "gfx/streamer/radar_dead.tga";
					size = 8;
					color = (0.62, 0.62, 0.62);
					alpha = 0.75;
				}

				if (dot.shaderNow != shader || dot.pxNow != size)
				{
					dot setShader(shader, size, size);
					dot.shaderNow = shader;
					dot.pxNow = size;
				}
				if (dot.color != color) dot.color = color;

				// Appearing: jump there. Moving: glide over the tick.
				if (dot.alpha == 0)
				{
					dot.x = p[0];
					dot.y = p[1];
				}
				else if (dot.x != p[0] || dot.y != p[1])
				{
					dot moveOverTime(0.1);
					dot.x = p[0];
					dot.y = p[1];
				}
				if (dot.alpha != alpha) dot.alpha = alpha;
			}
		}

		// Planted bomb: blinking icon
		if (isDefined(self.streamerRadar_bomb))
		{
			if (isDefined(level.bombplanted) && level.bombplanted && isDefined(level.bombmodel))
			{
				p = worldToRadar(win, level.bombmodel.origin);
				self.streamerRadar_bomb.x = p[0];
				self.streamerRadar_bomb.y = p[1];
				blink = !blink;
				if (blink)	self.streamerRadar_bomb.alpha = 1;
				else		self.streamerRadar_bomb.alpha = 0.35;
			}
			else if (self.streamerRadar_bomb.alpha != 0)
				self.streamerRadar_bomb.alpha = 0;
		}
	}

	self Radar_Destroy();
}

// Positions reached by players widen the automatic window from the next round on
learnBounds(pos)
{
	if (!isDefined(game["streamerRadar_min"]))
	{
		game["streamerRadar_min"] = (pos[0], pos[1], 0);
		game["streamerRadar_max"] = (pos[0], pos[1], 0);
		return;
	}
	lo = game["streamerRadar_min"];
	hi = game["streamerRadar_max"];
	if (pos[0] < lo[0] || pos[1] < lo[1])
		game["streamerRadar_min"] = (min(lo[0], pos[0]), min(lo[1], pos[1]), 0);
	if (pos[0] > hi[0] || pos[1] > hi[1])
		game["streamerRadar_max"] = (max(hi[0], pos[0]), max(hi[1], pos[1]), 0);
}
