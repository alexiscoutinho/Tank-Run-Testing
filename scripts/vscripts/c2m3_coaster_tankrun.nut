function OnGameEvent_round_start_pre_entity( params )
{
	EntFire( "info_map_parameters", "AddOutput", "UpgradepackDensity 3" );
	EntFire( "info_map_parameters", "AddOutput", "PipeBombDensity 4" );
}

function OnGameEvent_round_start( params )
{
	local wall = Entities.FindByModel( null, "*157" );
	DoEntFire( "!self", "Break", "", 0.0, null, wall );
}