// All credits of the monitoring scripts goes to vPAM and Walrus. I take no credit at all into making theese scripts. 
// Adapted to fit rPAMv1.11 by Anglhz<3

init()
{
    logprint("_rpam_monitor::init\n");

    maps\mp\gametypes\global\_global::addEventListener("onCvarChanged", ::onCvarChanged);

	maps\mp\gametypes\global\_global::registerCvar("scr_rpam_aimrun_fix", "BOOL", 1);
	maps\mp\gametypes\global\_global::registerCvar("scr_rpam_fastshoot_msg", "BOOL", 1);
	maps\mp\gametypes\global\_global::registerCvar("scr_promod_check_clipping", "BOOL", 0);

    maps\mp\gametypes\global\_global::addEventListener("onSpawned",     ::onSpawned);
}

// This function is called when cvar changes value.
// Is also called when cvar is registered
// Return true if cvar was handled here, otherwise false
onCvarChanged(cvar, value, isRegisterTime)
{
	switch(cvar)
	{
		case "scr_rpam_fastshoot_msg":
			level.scr_rpam_fastshoot_msg = value;
			if (!isRegisterTime)
			{
				result = "";
				if (level.scr_rpam_fastshoot_msg) 
					result = "enabled";
				else 
					result = "disabled";
				iPrintLn("Fastshoot message will be " + result + " from the next round.");
			}
			return true;
		case "scr_rpam_aimrun_fix":
			level.scr_rpam_aimrun_fix = value;
			if (!isRegisterTime)
			{
				result = "";
				if (level.scr_rpam_aimrun_fix) 
					result = "enabled";
				else 
					result = "disabled";
				iPrintLn("Aimrun fix will be " + result + " from the next round.");
			}
			return true;
		case "scr_promod_check_clipping":
			level.scr_promod_check_clipping = value;
			if (!isRegisterTime)
			{
				result = "";
				if (level.scr_promod_check_clipping) 
					result = "enabled";
				else 
					result = "disabled";
				iPrintLn("Up-down reporting will be " + result + " from the next round.");
			}
			return true;
	}
	return false;
}

onSpawned()
{
	// logprint("_rpam_monitor::onSpawned start\n");
	if (level.scr_rpam_fastshoot_msg || level.scr_rpam_aimrun_fix) 
	{
		thread monitor(level.scr_rpam_fastshoot_msg, level.scr_rpam_aimrun_fix);
	}
	if (level.scr_promod_check_clipping) 
	{
		self thread checkClipping();
		self thread checkLastDistance();
	}
	// logprint("_rpam_monitor::onSpawned stop\n");
}

monitor(fastshoot, aimrun)
{
	self endon("spawned");

	// logprint("_rpam_monitor::monitor starting to monitor " + self.name + " for fastshoot(" + fastshoot + ") and aimrun(" + aimrun + ")\n");
	
	slots[0] = "primary";
	slots[1] = "primaryb";
	slots[2] = "pistol";
	slots[slots.size] = "grenade";

	// Save current clip ammo of all slots.
	for (i = 0; i < slots.size; i++) {
		clip[slots[i]] = self getWeaponSlotClipAmmo(slots[i]);
	}

	shot_last_i = 0; // Slot (index) that last fired a shot.
	shot_last_time = 0; // Time of last shot.

	do {
		for (i = 0; i < slots.size; i++) {
			clip_new = self getWeaponSlotClipAmmo(slots[i]);

			// Check if shot fired.
			if (clip_new < clip[slots[i]]) {
				shot_new_time = getTime();

				if (fastshoot) {
					thread _check_fast_shot(shot_new_time - shot_last_time, slots[shot_last_i], slots[i]);
				}

				shot_last_i = i;
				shot_last_time = shot_new_time;
			} else if (clip_new > clip[slots[i]]) {
				if (aimrun) {
					thread _check_aim_run(slots[i]);
				}
			}

			clip[slots[i]] = clip_new;
		}

		wait .05;
	} while (self.sessionstate == "playing");
}

_check_fast_shot(ms, slot_1, slot_2)
{
	weapon_1 = self getWeaponSlotWeapon(slot_1);
	weapon_2 = self getWeaponSlotWeapon(slot_2);

	ms_threshold = 0;

	if (slot_1 == slot_2) {
		switch (weapon_1) {
		case "enfield_mp": // fireTime + rechamberTime = 0.33 + 1.1 = 1.43
		case "kar98k_mp": // fireTime + rechamberTime = 0.33 + 1 = 1.33
		case "kar98k_sniper_mp": // fireTime + rechamberTime = 0.33 + 1 = 1.33
		case "mosin_nagant_mp": // fireTime + rechamberTime = 0.33 + 1 = 1.33
		case "springfield_mp": // fireTime + rechamberTime = 0.33 + 0.95 = 1.28
			ms_threshold = 1250;
			break;
		case "mosin_nagant_sniper_mp": // fireTime + rechamberTime = 0.5 + 1 = 1.5
		case "fraggrenade_mp": // fireTime + holdFireTime = 1 + 0.5 = 1.5
		case "mk1britishfrag_mp": // fireTime + holdFireTime = 1 + 0.6 = 1.6
		case "rgd-33russianfrag_mp": // fireTime + holdFireTime = 1 + 0.5 = 1.5
		case "stielhandgranate_mp": // fireTime + holdFireTime = 1 + 0.5 = 1.5
			ms_threshold = 1400;
			break;
		case "colt_mp": // fireTime = 0.135
		case "luger_mp": // fireTime = 0.135
			ms_threshold = 100;
//			break;
//		case "bar_mp": // fireTime = 0.11
//		case "bren_mp": // fireTime = 0.12
//		case "mp44_mp": // fireTime = 0.12
//			ms_threshold = 100;
		}

		// The last thrown nade will be gone, thus we check the slot.
		if (weapon_1 == "none" && slot_1 == "grenade") {
			ms_threshold = 1400;
		}
	} else {
		// Fast weapon switch.

		// fireTime + dropTime + raiseTime = 0.33 + 0.4 + 0.5 = 1.22
		if ((weapon_1 == "kar98k_mp" && weapon_2 == "mosin_nagant_mp")
		|| (weapon_2 == "kar98k_mp" && weapon_1 == "mosin_nagant_mp")) {
			ms_threshold = 1150;
		}
	}

	if (ms < ms_threshold) {
		if (slot_2 == "pistol" || slot_2 == "grenade") {
			extra_info = " (^3" + slot_2 + "^7)";
		} else {
			extra_info = "";
		}
		iPrintLn("^7rPAM^3 ~ " +  "^1FASTSHOOT^7" + extra_info + ": " + self.name);
	}
}

_check_aim_run(slot)
{
	// Aim running is done with a bolt action rifle by holding the attack button at reloading.
	// While holding the attack button after reloading, a player can aim while maintaining regular speed.

	if (slot != "primary" && slot != "primaryb" && slot != "pistol") {
		return;
	}

	weapon = self getWeaponSlotWeapon(slot);

	// logprint("_rpam_monitor::_check_aim_rum slot=" + slot + ", weapon=" + weapon + "\n");

	if (
		weapon != "enfield_mp" &&
		weapon != "m1garand_mp" &&
		weapon != "m1carbine_mp" &&
		weapon != "kar98k_mp" &&
		weapon != "kar98k_sniper_mp" &&
		weapon != "mosin_nagant_mp" &&
		weapon != "mosin_nagant_sniper_mp" &&
		weapon != "springfield_mp" &&
		weapon != "luger_mp" &&
		weapon != "colt_mp"
	) {
		return;
	}

	// Roughly 1 second after clip count is increased, weapon can fire again.
	// We will check for the attack button being pressed during a small window.
	// If inside the window a bullet is fired, the window ends.
	ammo = self getWeaponSlotClipAmmo(slot);

	// Wait for reloading animation to progress.
	wait 0.9;

	// Check during the next 0.5 second window for holding it.
	for (tick = 0; tick < 10 && self.sessionstate == "playing"; tick++) {
		// If a shot was fired (by pressing attack), aimrunning isn't relevant anymore.
		if (self getWeaponSlotClipAmmo(slot) != ammo || self getCurrentWeapon() != weapon) {
			break;
		}

		if (self attackButtonPressed() && self getCurrentWeapon() == weapon) {
			self disableWeapon();
		}

		wait 0.05;
		self enableWeapon();
	}
}

checkClipping()
{
    self endon("spawned");

	logprint("_rpam_monitor::checkClipping() start\n");

    crouchStartTime = 0;

    for (;;)
    {
        wait 0.05;
        if (self.sessionstate != "playing")
            return;

        if (self getStance() == "stand")
        {
            if (crouchStartTime == 0.0)            
            {
                crouchStartTime = gettime();
                //self iPrintln("stand");
            }

        }
        else if( self getStance() == "crouch" && crouchStartTime != 0 /*&& !self.sprinting*/ && self isOnGround() )
        {   

            timeDiff = ( gettime() - crouchStartTime ) / 1000.0;
			//self iPrintln("timeDiff=" + timeDiff);
            if ( timeDiff <= 0.4 && isDefined( self.lastDistance ) && self.lastDistance < 50 )
            {
                // A clip was detected
                crouchStartTime = 0.0; // Reset the start time

                // self shellshock( "hold_breath", 2);

                //if( self promod\client::get_config( "PROMOD_CLIPINFO" ) )
                //    self iPrintln( "^3Clip detected^7" + ", time: " + timeDiff + "s");
                //visualizeTriggers();           

                // if( isDefined( level.strat_over ) && level.strat_over && game["promod_in_timeout"] == 0 && isAlive(self) && isDefined( game["PROMOD_MATCH_MODE"] ) && game["PROMOD_MATCH_MODE"] == "match" && level.gametype == "sd" && game["PROMOD_KNIFEROUND"] == 0 && level.fps_ac_check == 1 && level.fps_match_id != 0 && level.fps_track_stats == 1)
                // {
                //     self.pers["clips"]++;

                //     thread promod\stats::clipReport( self, game["totalroundsplayed"]+1, timeDiff );

                //     if ( self promod\client::get_config( "PROMOD_CLIPINFO" ) )
                //     {
                //         self iPrintln( "^1Clip detected^7" + ", time: " + timeDiff + "s");
                //     }
                // } else if ( self promod\client::get_config( "PROMOD_CLIPINFO" ) ) 
                // {
                //     self iPrintln( "^3Clip detected^7" + ", time: " + timeDiff + "s");
                // }

				self iPrintln( "^3Clip detected^7" + ", time: " + timeDiff + "s");
                //self shellshock( "dog_bite", 2);               
            }
            else
            {            
                crouchStartTime = 0; // Reset the start time            
            }
        }
        else 
        {
            crouchStartTime = 0;        
        }
    }
}

checkLastDistance()
{
    self endon("spawned");

	logprint("_rpam_monitor::checkLastDistance() start\n");

    startTime = getTime();
    startPos = self.origin;
    distanceTraveled = 0;

    do
    {
        currentPos = self.origin;
        elapsedTime = getTime() - startTime;

        if (elapsedTime >= 300)
        {
            // Calculate the distance traveled by the player
            distanceTraveled = distance(startPos, currentPos);

            // Reset the tracking
            startTime = getTime();
            startPos = currentPos;
        }

        self.lastDistance = distanceTraveled;
        // self iprintln("Distance Traveled: " + (int)(distanceTraveled) );
        wait 0.2;
    } while (self.sessionstate == "playing");
}