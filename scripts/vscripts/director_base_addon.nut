if ( g_MapName.find("l4d2_deathcraft") == 0 || g_MapName == "l4d2_minecraft_evolution" ) // Deathcraft II
	SessionState.TankModels = [ "models/infected/hulk.mdl" ];
else if ( g_MapName == "l4d2_stadium5_stadium" ) // Suicide Blitz 2
	SessionState.FirstSpawnDelay = -1;