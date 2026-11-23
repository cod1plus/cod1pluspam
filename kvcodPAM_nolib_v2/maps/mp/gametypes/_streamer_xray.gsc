

init()
{
	logprint("_streamer_xray::init\n");
	
	if (!level.streamerSystem)
		return;

	if(game["firstInit"])
	{
		precacheShader("images/stance_stand_front.dds");
		precacheShader("images/stance_stand_back.dds");
		precacheShader("images/stance_stand_left.dds");
		precacheShader("images/stance_stand_right.dds");
		precacheShader("images/stance_crouch_front.dds");
		precacheShader("images/stance_crouch_back.dds");
		precacheShader("images/stance_crouch_left.dds");
		precacheShader("images/stance_crouch_right.dds");
		precacheShader("images/stance_prone_front.dds");
		precacheShader("images/stance_prone_back.dds");
		precacheShader("images/stance_prone_left.dds");
		precacheShader("images/stance_prone_right.dds");
		//precacheShader("gfx/hud/stance_stand.dds");
		//precacheShader("gfx/hud/stance_crouch.dds");
		//precacheShader("gfx/hud/stance_prone.dds");

		//game["STRING_STREAMERSYSTEM_XRAY_ON"] = 		"XRAY ^2On";
		//game["STRING_STREAMERSYSTEM_XRAY_OFF"] = 		"XRAY ^1Off";

		//maps\mp\gametypes\global\_global::precacheString2("STRING_STREAMERSYSTEM_ARROW_LEFT", &"<");
		//maps\mp\gametypes\global\_global::precacheString2("STRING_STREAMERSYSTEM_ARROW_RIGHT", &">");
	}

	// XRAY hudelems are keyed by client number
	level.streamerSystem_maxClients = getCvarInt("sv_maxclients");
	if (level.streamerSystem_maxClients < 1 || level.streamerSystem_maxClients > 64)
		level.streamerSystem_maxClients = 64;

	maps\mp\gametypes\global\_global::addEventListener("onConnected",  ::onConnected);
}

onConnected()
{
	logprint("_streamer_xray::onConnected start\n");
	if (!isDefined(self.pers["streamerSystem_XRAY"]))
		self.pers["streamerSystem_XRAY"] = false;

	self.streamerSystem_XRAY_inFreeSpectating = false;

	// The XRAY choice [X] now stays on from one round to the next (caster overlay)

	// 0 = 4:3, 1 = 16:9 wide (1.6X), 2 = 16:9 stretched - kept for the whole session
	if (!isDefined(self.pers["streamerSystem_xrayAspect"]))
		self.pers["streamerSystem_xrayAspect"] = 0;
	logprint("_streamer_xray::onConnected end\n");
}


toggle()
{
	if (self.streamerSystem_freeSpectating)
	{
		self.streamerSystem_XRAY_inFreeSpectating = !self.streamerSystem_XRAY_inFreeSpectating;
		self.pers["streamerSystem_XRAY"] = self.streamerSystem_XRAY_inFreeSpectating;
	}
	else
		self.pers["streamerSystem_XRAY"] = !self.pers["streamerSystem_XRAY"];

	/*if (self.pers["streamerSystem_XRAY"])
		self iprintln(game["STRING_STREAMERSYSTEM_XRAY_ON"]);
	else
		self iprintln(game["STRING_STREAMERSYSTEM_XRAY_OFF"]);*/

	self thread maps\mp\gametypes\_streamer_hud::settingsChangedForPlayer("xray");
}



// V key in the streamer menu: how the streamer's game projects the view.
// The server cannot read the streamer's resolution, so he tells it once.
toggleAspect()
{
	self.pers["streamerSystem_xrayAspect"]++;
	if (self.pers["streamerSystem_xrayAspect"] > 2)
		self.pers["streamerSystem_xrayAspect"] = 0;

	self thread maps\mp\gametypes\_streamer_hud::settingsChangedForPlayer("aspect");
}

aspectName()
{
	if (!isDefined(self.pers["streamerSystem_xrayAspect"]))
		return "4:3";
	switch (self.pers["streamerSystem_xrayAspect"])
	{
		case 1:  return "16:9 wide (1.6X)";
		case 2:  return "16:9 stretched";
		default: return "4:3";
	}
}


XRAY_Stop()
{
	self notify("streamerSystem_xray_loop");
	self XRAY_Destroy();
}

XRAY_Destroy()
{
	if (isDefined(self.streamerSystem_XRAY_huds))
	{
		keys = getArrayKeys2(self.streamerSystem_XRAY_huds);
		for (i = 0; i < keys.size; i++)
		{
			hud = self.streamerSystem_XRAY_huds[keys[i]];
			if (isDefined(hud))
				hud destroy();
		}
	}
	self.streamerSystem_XRAY_huds = undefined;
	self.streamerSystem_XRAY_count = 0;
	self.streamerSystem_playerToFollow = undefined;
}

// CoD1 has no getArrayKeys: the pool is keyed by client number
getArrayKeys2(array)
{
	keys = [];
	for (i = 0; i < level.streamerSystem_maxClients; i++)
		if (isDefined(array[i]))
			keys[keys.size] = i;
	return keys;
}


/*
	XRAY: a silhouette (stance + facing) drawn over every enemy of the followed player,
	through walls. self is the streamer.

	What CoD1 allows, and what it does not:
	- the engine has no outline / wallhack render and no world-positioned hudelem: the only way
	  is to project each player on the screen ourselves and move a 2D hudelem there;
	- the script sees a player's view yaw (player.angles[1]) but NOT his view pitch
	  (ClientThink writes angles = (0, yaw, 0), there is no getPlayerAngles in CoD1). The
	  projection therefore assumes a level view: horizontal position and size are right, the
	  height drifts when the followed player looks up or down;
	- the zoom of an aimed weapon is not visible to the script either: while the followed
	  player aims down the sights the markers spread out;
	- the streamer's field of view is fixed to 80 by the streamer menu, his screen shape is
	  given with V (4:3 / 16:9 wide / 16:9 stretched).

	One hudelem per shown enemy (5 when following in 5v5, 10 when flying), created the first
	time it is needed, hidden with alpha instead of being recreated, all destroyed when the
	XRAY is turned off or the streamer leaves. Updated every server frame.
*/
XRAY_Loop()
{
	self endon("disconnect");
	self notify("streamerSystem_xray_loop");
	self endon("streamerSystem_xray_loop");

	self XRAY_Destroy();
	self.streamerSystem_XRAY_huds = [];

	if (!isDefined(self.pers["streamerSystem_xrayAspect"]))
		self.pers["streamerSystem_xrayAspect"] = 0;

	freeSpectating = self.streamerSystem_freeSpectating;
	tick = 0;

	for (;;)
	{
		wait level.frame;
		tick++;

		if (!maps\mp\gametypes\_streamer::isStreamerModeEnabled(self))
			break;

		// the 1.6X client draws an exact XRAY itself from _streamer_native.gsc's feed
		if (maps\mp\gametypes\_streamer_native::isNative(self))
		{
			if (self.streamerSystem_XRAY_count > 0)
			{
				self XRAY_Destroy();
				self.streamerSystem_XRAY_huds = [];
			}
			self.streamerSystem_playerToFollow = undefined;
			continue;
		}

		// If player started free spectating, force XRAY by another toggler
		if (freeSpectating != self.streamerSystem_freeSpectating && self.streamerSystem_freeSpectating)
			self.streamerSystem_XRAY_inFreeSpectating = true;
		freeSpectating = self.streamerSystem_freeSpectating;

		// Camera: the followed player, or the streamer himself when flying
		camera = undefined;
		enabled = level.scr_streamer_xray && !isDefined(self.killcam) && !level.in_bash && game["state"] != "intermission" && !self.streamerSystem_inCinematic;
		if (enabled)
		{
			if (self.streamerSystem_freeSpectating)
			{
				if (self.streamerSystem_XRAY_inFreeSpectating)
					camera = self;
			}
			else if (self.pers["streamerSystem_XRAY"] && self.streamerSystem_turnedOn && isDefined(level.streamerSystem_player) && isPlayer(level.streamerSystem_player) && level.streamerSystem_player.sessionstate == "playing")
				camera = level.streamerSystem_player;
		}

		if (!isDefined(camera))
		{
			// Turned off: free the hudelems. Only hidden for a moment: keep them.
			if (!level.scr_streamer_xray || (self.streamerSystem_freeSpectating && !self.streamerSystem_XRAY_inFreeSpectating) || (!self.streamerSystem_freeSpectating && !self.pers["streamerSystem_XRAY"]))
			{
				if (self.streamerSystem_XRAY_count > 0)
				{
					self XRAY_Destroy();
					self.streamerSystem_XRAY_huds = [];
				}
			}
			else
				self XRAY_HideAll();
			self.streamerSystem_playerToFollow = undefined;
			continue;
		}

		self XRAY_Update(camera, tick % 4 == 0);
	}

	self XRAY_Destroy();
}

XRAY_HideAll()
{
	for (i = 0; i < level.streamerSystem_maxClients; i++)
	{
		hud = self.streamerSystem_XRAY_huds[i];
		if (isDefined(hud) && hud.alpha != 0)
			hud.alpha = 0;
	}
}

XRAY_Update(camera, checkSight)
{
	// Projection constants (640x480 virtual screen, field of view 80)
	tanX = 0.8391;	// tan(40): 4:3, and 16:9 stretched keeps the 4:3 width
	tanY = 0.6293;	// tan(40) * 3/4
	if (self.pers["streamerSystem_xrayAspect"] == 1)
		tanX = 1.1188;	// 16:9 wide screen (Hor+): the height of 4:3 kept, width 16/9
	else if (self.pers["streamerSystem_xrayAspect"] == 2)
		tanY = 0.4720;	// 16:9 stretched by the vanilla game: width of 4:3 kept, height 9/16
	focalX = 320 / tanX;
	focalY = 240 / tanY;

	if (camera == self)
		eye = self.origin + (0, 0, 8);
	else
		eye = camera maps\mp\gametypes\global\player::getEyeOrigin();

	yaw = camera.angles[1];
	fwd = (cos(yaw), sin(yaw), 0);
	right = (sin(yaw), -1 * cos(yaw), 0);

	shown = [];
	closest = undefined;
	closestDist = 0;

	players = getentarray("player", "classname");
	for (i = 0; i < players.size; i++)
	{
		player = players[i];
		if (player == self || player == camera)
			continue;
		if (player.sessionstate != "playing")
			continue;
		if (!isDefined(player.pers["team"]) || (player.pers["team"] != "allies" && player.pers["team"] != "axis"))
			continue;
		// following: enemies of the followed player only (DM: everybody)
		if (camera != self && camera.sessionteam == player.sessionteam && player.sessionteam != "none")
			continue;

		rel = player.origin - eye;
		depth = vectordot(rel, fwd);
		if (depth < 24)
			continue;	// behind the camera

		sx = 320 + vectordot(rel, right) / depth * focalX;
		if (sx < -40 || sx > 680)
			continue;	// out of the screen sides
		syFeet = 240 - rel[2] / depth * focalY;

		// the silhouettes fill 80 of their 128 pixels for a standing player (~72 units),
		// feet at 111/128: size and anchor follow from that
		size = 115 * focalY / depth;
		if (size < 12) size = 12;
		if (size > 480) size = 480;
		y = syFeet + 0.133 * size;

		num = player getEntityNumber();
		shown[num] = true;

		hud = self.streamerSystem_XRAY_huds[num];
		if (!isDefined(hud))
		{
			hud = maps\mp\gametypes\global\_global::newClientHudElem2(self);
			hud.archived = false;
			hud.alignX = "center";
			hud.alignY = "bottom";
			hud.sort = -1;
			hud.alpha = 0;
			hud.shaderNow = "";
			hud.pxNow = 0;
			hud.visibleNow = false;
			self.streamerSystem_XRAY_huds[num] = hud;
			self.streamerSystem_XRAY_count++;
		}

		// stance from the head height, facing relative to the camera
		stance = player maps\mp\gametypes\global\player::getStance();
		toCam = vectortoangles((eye[0] - player.origin[0], eye[1] - player.origin[1], 0));
		angle = player.angles[1] - toCam[1];
		while (angle > 180) angle -= 360;
		while (angle < -180) angle += 360;
		if (angle > 135 || angle < -135)	facing = "back";
		else if (angle > 45)			facing = "left";
		else if (angle < -45)			facing = "right";
		else					facing = "front";
		shader = "images/stance_" + stance + "_" + facing + ".dds";

		isize = (int)size;
		if (hud.shaderNow != shader || hud.pxNow != isize)
		{
			hud setShader(shader, isize, isize);
			hud.shaderNow = shader;
			hud.pxNow = isize;
		}
		hud.x = sx;
		hud.y = y;

		// team colour, going red with the damage taken
		if (player.pers["team"] == "allies")	color = (0.45, 0.65, 1.00);
		else					color = (1.00, 0.45, 0.35);
		if (player.health < 100 && player.health > 0)
		{
			f = player.health / 100.0;	// int / int would be an integer division (always 0)
			color = (color[0] + (1 - color[0]) * (1 - f), color[1] * f, color[2] * f);
		}
		if (hud.color != color)
			hud.color = color;

		// behind a wall: strong; in plain sight: faint, the model itself is visible
		if (checkSight || hud.alpha == 0)
			hud.visibleNow = camera maps\mp\gametypes\global\player::isPlayerInSight(player);
		alpha = 0.85;
		if (hud.visibleNow)
			alpha = 0.3;
		if (hud.alpha != alpha)
			hud.alpha = alpha;

		// flying: the player nearest to the screen centre is the one [attack] will follow
		if (camera == self && depth < 1500 && sx > 160 && sx < 480)
		{
			d = (sx - 320) * (sx - 320) + (y - size / 2 - 240) * (y - size / 2 - 240);
			if (!isDefined(closest) || d < closestDist)
			{
				closest = player;
				closestDist = d;
			}
		}
	}

	// hide the markers of players not shown this frame, drop those who left
	for (i = 0; i < level.streamerSystem_maxClients; i++)
	{
		hud = self.streamerSystem_XRAY_huds[i];
		if (!isDefined(hud) || isDefined(shown[i]))
			continue;
		ent = getEntByNum(i);
		if (!isDefined(ent) || !isPlayer(ent))
		{
			hud destroy();
			self.streamerSystem_XRAY_huds[i] = undefined;
			self.streamerSystem_XRAY_count--;
		}
		else if (hud.alpha != 0)
			hud.alpha = 0;
	}

	self.streamerSystem_playerToFollow = closest;
}
