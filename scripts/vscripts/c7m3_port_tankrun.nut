ChallengeScript.rawdelete( "OnGameEvent_round_start_post_nav" );
function OnGameEvent_round_start_post_nav( params )
{
	if ( !("toggledAreas" in getroottable()) )
	{
		local allAreas = {};
		NavMesh.GetAllAreas( allAreas );

		::toggledAreas <- {};
		foreach ( area in allAreas )
		{
			if ( area.HasSpawnAttributes( FINALE ) )
				toggledAreas.rawset( area, area );
		}
	}
}

function GeneratorButtonPressed()
{
    Msg("**c7m3_port GeneratorButtonPressed **\n")
	EntFire( "@director", "EndScript" )
	EntFire( "generator_start_model", "Enable" )
    EntFire( "generator_start_model", "ForceFinaleStart" )
}

function OnGameEvent_round_start( params )
{
	local relay = Entities.FindByName( null, "relay_finale_script_event" );
	EntityOutputs.RemoveOutput( relay, "OnTrigger", "", "", "" );
	EntityOutputs.AddOutput( relay, "OnTrigger", "@director", "RunScriptCode", "g_MapScript.GeneratorButtonPressed()", 0.0, 1 );
}

function OnGameEvent_player_left_safe_area( params )
{
	foreach ( area in toggledAreas )
		area.RemoveSpawnAttributes( FINALE );
}