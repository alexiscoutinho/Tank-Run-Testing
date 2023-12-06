function OnGameEvent_round_start_pre_entity( params )
{
	EntFire( "info_map_parameters", "AddOutput", "PainPillDensity 2.15" );
	EntFire( "info_map_parameters", "AddOutput", "AdrenalineDensity 2.5" );
}