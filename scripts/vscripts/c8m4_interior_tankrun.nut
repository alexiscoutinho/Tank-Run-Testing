function OnGameEvent_round_start( params )
{
	local wall;
	foreach ( model in [ "*260", "*264", "*265", "*266", "*290" ] )
	{
		wall = Entities.FindByModel( null, model );
		DoEntFire( "!self", "Break", "", 0.0, null, wall );
	}
}