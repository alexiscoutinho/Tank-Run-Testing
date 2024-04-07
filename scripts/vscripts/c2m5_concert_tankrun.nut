MapState <-
{
	HoldoutSpawnInterval = 30
}

function OnGameEvent_round_start_post_nav( params )
{
	for ( local ammo; ammo = Entities.FindByModel( ammo, "models/props/terror/ammo_stack.mdl" ); )
	{
		if ( ammo.GetClassname() == "weapon_ammo_spawn" )
			SpawnEntityFromTable( "upgrade_laser_sight", { origin = ammo.GetOrigin() } ); // port other non zero KVs?
	}
}