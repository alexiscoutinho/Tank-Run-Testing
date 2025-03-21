ChallengeScript.rawdelete( "DecreaseHUDTimerBy" );
function DecreaseHUDTimerBy(_) {}

ChallengeScript.rawdelete( "SetupModeHUD" );

function OnGameEvent_round_start( params )
{
	EntFire( "escape_vehicle_ready", "Kill" );

	local ent = Entities.FindByName( null, "finale_elevator" );
	EntityOutputs.RemoveOutput( ent, "OnFullyOpen", "escape_vehicle_ready", "", "" );
	EntityOutputs.AddOutput( ent, "OnFullyOpen", "escape_vehicle_trigger", "Enable", "", 0.0, 1 );
	EntityOutputs.AddOutput( ent, "OnFullyOpen", "finale_lever", "FinaleEscapeVehicleReadyForSurvivors", "", 0.0, 1 );
	EntityOutputs.AddOutput( ent, "OnFullyOpen", "van_door", "Break", "", 0.0, 1 );
	EntityOutputs.AddOutput( ent, "OnFullyOpen", "!self", "RunScriptCode",
		"SessionState.HoldoutEnded = true; Director.ForceNextStage()", 0.0, 1 );

	ent = Entities.FindByName( null, "finale_lever" );
	EntityOutputs.RemoveOutput( ent, "FinaleEscapeStarted", "", "", "" );
}

ChallengeScript.rawdelete( "OnGameEvent_finale_start" );
function OnGameEvent_finale_start( params )
{
	delete SessionOptions.ShouldPlayBossMusic;
	Director.ForceNextStage();
	SessionState.DoubleTanks = true;
	local infStats = {};
	GetInfectedStats( infStats );
	if ( infStats.Tanks > 2 )
		SessionState.SpawnInterval = SessionState.HoldoutSpawnInterval;
}//investigate effect of shorter finale