function OnGameEvent_round_start_pre_entity( params )
{
	EntFire( "info_map_parameters", "AddOutput", "PropaneTankDensity 6.5" );
	EntFire( "info_map_parameters", "AddOutput", "GasCanDensity 15" );
}