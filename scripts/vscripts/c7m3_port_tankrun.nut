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