getconsttable().HUD_MID_TOP <- HUD_MID_TOP;

function OnGameEvent_round_start( params ) // should more I/O changes be made?
{
	foreach ( name in [ "gascans_finale_normal", "gascans_finale_expert" ] )
		EntFire( name, "Kill" );

	local relay = Entities.FindByName( null, "relay_lighthouse_off" );
	EntityOutputs.AddOutput( relay, "OnTrigger", "!self", "RunScriptCode", "HUDPlace( HUD_MID_TOP, 0.45, 0.14, 0.1, 0.04 )", 0.0, 1 );

	relay = Entities.FindByName( null, "relay_generator_ready" );
	EntityOutputs.AddOutput( relay, "OnTrigger", "!self", "RunScriptCode", "HUDPlace( HUD_MID_TOP, 0.45, 0.03, 0.1, 0.04 )", 0.0, 1 );
	EntityOutputs.AddOutput( relay, "OnTrigger", "!self", "RunScriptCode", "g_ModeScript.DecreaseHUDTimerBy( 150 )", 1.0, 1 );
}

function InitializeScavenge()
{
	EntFire( "relay_boat_coming2", "Trigger" );
	EntFire( "lighthouse_light", "SetPattern", "mmamammmmammamamaaamammma", 7.0 );
	EntFire( "spotlight_beams", "LightOff", "", 7.0 );
	EntFire( "spotlight_glow", "HideSprite", "", 7.0 );
	EntFire( "brush_light", "Enable", "", 7.0 );
	EntFire( "spotlight_beams", "LightOn", "", 7.5 );
	EntFire( "spotlight_glow", "ShowSprite", "", 7.5 );
	EntFire( "brush_light", "Disable", "", 7.5 );
	EntFire( "spotlight_beams", "LightOff", "", 8.0 );
	EntFire( "spotlight_glow", "HideSprite", "", 8.0 );
	EntFire( "brush_light", "Enable", "", 8.0 );
	EntFire( "spotlight_beams", "LightOn", "", 8.5 );
	EntFire( "spotlight_glow", "ShowSprite", "", 8.5 );
	EntFire( "brush_light", "Disable", "", 8.5 );
	EntFire( "lighthouse_light", "SetPattern", "", 9.5 );
	EntFire( "lighthouse_light", "TurnOff", "", 10.0 );
	EntFire( "relay_lighthouse_off", "Trigger", "", StageDelay );
	EntFire( "worldspawn", "RunScriptCode", "g_MapScript.SpawnScavengeCans( 2 )", StageDelay );
}

function OnGameEvent_finale_start( params )
{
	NumCansNeeded = Director.IsSinglePlayerGame() ? 4 : 8;
	EntFire( "progress_display", "SetTotalItems", NumCansNeeded );
	EntFire( "worldspawn", "RunScriptCode", "g_MapScript.InitializeScavenge()", RandomInt( 50, 100 ) );
}

function OnGameEvent_finale_escape_start( params ) // shouldn't restarting the generator be mandatory?
{
	EntFire( "explain_fuel_generator", "Kill" );
	EntFire( "weapon_scavenge_item_spawn", "TurnGlowsOff" );
	EntFire( "weapon_scavenge_item_spawn", "Kill" );
	EntFire( "pour_target", "Deactivate" );
	EntFire( "gas_nozzle", "StopGlowing" );
	EntFire( "lighthouse_generator", "StopGlowing" );
	EntFire( "progress_display", "TurnOff" );
	EntFire( "sound_scavenge", "StopSound" );
}