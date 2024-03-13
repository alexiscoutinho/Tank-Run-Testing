function OnGameEvent_round_start( params )
{
	local button = Entities.FindByName( null, "crane button" );
	EntityOutputs.RemoveOutput( button, "OnPressed", "dumpster push", "", "" );
	EntityOutputs.RemoveOutput( button, "OnPressed", "dumpster crush", "", "" );
	EntityOutputs.AddOutput( button, "OnPressed", "dumpster crush", "Enable", "", 26.5, 1 );
	EntityOutputs.AddOutput( button, "OnPressed", "dumpster crush", "Disable", "", 31.5, 1 );

	EntFire( "dumpster dirt", "AddOutput", "startspeed 14" );
	EntFire( "dumpster push", "Kill" );
	EntFire( "dumpster crush", "AddOutput", "damage 500" );
	EntFire( "dumpster crush", "AddOutput", "damagecap 500" );
}