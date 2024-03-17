MapState <-
{
	HoldoutSpawnInterval = 30
}

delete ChallengeScript.OnGameEvent_round_start_post_nav;
function OnGameEvent_round_start_post_nav( params )
{
	if ( !("finaleAreas" in getroottable()) )
	{
		local allAreas = {};
		NavMesh.GetAllAreas( allAreas );

		::finaleAreas <- {};
		foreach ( area in allAreas )
		{
			if ( area.HasSpawnAttributes( FINALE ) )
				finaleAreas[area] <- area;
		}
	}
}

function OnGameEvent_round_start( params )
{
	for ( local ammo; ammo = Entities.FindByModel( ammo, "models/props/terror/ammo_stack.mdl" ); )
	{
		if ( ammo.GetClassname() == "weapon_ammo_spawn" )
			SpawnEntityFromTable( "upgrade_laser_sight", { origin = ammo.GetOrigin() } ); // port other non zero KVs?
		ammo.Kill();
	}
}

function OnGameEvent_player_left_safe_area( params )
{
	foreach ( area in finaleAreas )
		area.RemoveSpawnAttributes( FINALE );
}