MapState <-
{
	TanksDisabled = true
}

function OnGameEvent_player_left_safe_area( params )
{
	EntFire( "worldspawn", "RunScriptCode", "SessionState.TanksDisabled = false", 3.0 );
}