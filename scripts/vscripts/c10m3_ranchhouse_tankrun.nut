local oldTankLimit;
local ChurchGuySpawn = false;

function OnSpawnZombie()
{
	local numplayers = 0;
	for ( local player; player = Entities.FindByClassname( player, "player" ); )
		numplayers++;

	// since entity indexes from 1 to maxplayers are reserved for player entities
	local maxplayers = Entities.FindByClassname( null, "cs_team_manager" ).GetEntityIndex() - 1;

	if ( numplayers == maxplayers )
	{
		// kick furthest tank not visible or spawn ragdoll. maybe delay door opening so corpse could fall nicely
		return false;
	}

	local numTanks = SessionState.Tanks.len();
	oldTankLimit = SessionOptions.cm_TankLimit;
	if ( numTanks >= oldTankLimit )
		SessionOptions.cm_TankLimit = numTanks + 1;

	ChurchGuySpawn = true;
	return true;
}

function OnGameEvent_round_start_post_nav( params )
{
	local spawner = Entities.FindByName( null, "spawn_church_zombie" );

	NetProps.SetPropString( spawner, "m_szPopulation", "tank" );

	spawner.ValidateScriptScope();
	spawner.GetScriptScope().InputSpawnZombie <- OnSpawnZombie;

	//substitute zombie with tank sounds
}

function OnGameEvent_tank_spawn( params ) // assuming OnGameEvents are run in the order they are registered
{
	if ( ChurchGuySpawn )
	{
		local tank = GetPlayerFromUserID( params["userid"] );
		if ( (tank.GetOrigin() - Entities.FindByName( null, "spawn_church_zombie" ).GetOrigin()).Length() < 1 )
		{
			tank.SetMaxHealth( SessionState.TankHealth / 4 );
			tank.SetHealth( SessionState.TankHealth / 4 );

			SessionOptions.cm_TankLimit = oldTankLimit;
			ChurchGuySpawn = false;
		}
	}
}