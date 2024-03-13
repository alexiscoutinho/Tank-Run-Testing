delete ChallengeScript.TankRunHUD;
delete ChallengeScript.SetupModeHUD;
delete ChallengeScript.EndHoldoutThink;

function OnGameEvent_round_start( params )
{
	EntFire( "escape_vehicle_ready", "Kill" );

	local ent = Entities.FindByName( null, "finale_elevator" );
	EntityOutputs.RemoveOutput( ent, "OnFullyOpen", "escape_vehicle_ready", "", "" );
	EntityOutputs.AddOutput( ent, "OnFullyOpen", "escape_vehicle_trigger", "Enable", "", 0.0, 1 );
	EntityOutputs.AddOutput( ent, "OnFullyOpen", "finale_lever", "FinaleEscapeVehicleReadyForSurvivors", "", 0.0, 1 );
	EntityOutputs.AddOutput( ent, "OnFullyOpen", "van_door", "Break", "", 0.0, 1 );
	EntityOutputs.AddOutput(
		ent, "OnFullyOpen", "!self", "RunScriptCode", "SessionState.HoldoutEnded = true; Director.ForceNextStage()", 0.0, 1 );

	ent = Entities.FindByName( null, "finale_lever" );
	EntityOutputs.RemoveOutput( ent, "FinaleEscapeStarted", "", "", "" );
}

delete ChallengeScript.OnGameEvent_finale_start;
function OnGameEvent_finale_start( params )
{
	SessionState.SpawnInterval = SessionState.HoldoutSpawnInterval;
	SessionState.HoldoutStarted = true;
}