local oldTankLimit;
local ChurchGuySpawn = false;

function InputSpawnZombie()
{
	local numplayers = 0, numTanks = 0;
	for ( local player; player = Entities.FindByClassname( player, "player" ); )
	{
		numplayers++;
		if ( player.GetZombieType() == ZOMBIE_TANK )
			numTanks++;
	}

	// since entity indexes from 1 to maxplayers are reserved for player entities
	local maxplayers = Entities.FindByClassname( null, "cs_team_manager" ).GetEntityIndex() - 1;

	if ( numplayers == maxplayers )
	{
		// kick furthest tank not visible or spawn ragdoll. maybe delay door opening so corpse could fall nicely
		return false;
	}

	oldTankLimit = SessionOptions.cm_TankLimit;
	if ( numTanks >= oldTankLimit )
		SessionOptions.cm_TankLimit = numTanks + 1;

	ChurchGuySpawn = true;
	return true;
}

local ChurchGuyPos;

function OnGameEvent_round_start_post_nav( params )
{
	local spawner = Entities.FindByName( null, "spawn_church_zombie" );
	NetProps.SetPropString( spawner, "m_szPopulation", "tank" );
	spawner.ValidateScriptScope();
	spawner.GetScriptScope().InputSpawnZombie <- InputSpawnZombie.bindenv( this );
	ChurchGuyPos = spawner.GetOrigin();
}

function OnGameEvent_round_start( params )
{
	EntFire( "relay_enable_chuch_zombie_loop", "AddOutput", "OnTrigger !self:RunScriptCode:SessionState.SpawnInterval = 30:0:1" );

	//substitute zombie with tank sounds

	for ( local prop; prop = Entities.FindByModel( prop, "models/props/cs_office/file_cabinet2.mdl" ); )
		DoEntFire( "!self", "AddOutput", "nodamageforces 1", 0.0, null, prop );
}

function OnGameEvent_tank_spawn( params ) // assuming OnGameEvents are run in the order they are registered
{
	if ( ChurchGuySpawn )
	{
		local tank = GetPlayerFromUserID( params["userid"] );
		if ( (tank.GetOrigin() - ChurchGuyPos).Length() < 1 )
		{
			tank.SetMaxHealth( SessionState.TankHealth / 4 );
			tank.SetHealth( SessionState.TankHealth / 4 );

			SessionOptions.cm_TankLimit = oldTankLimit;
			ChurchGuySpawn = false;
		}
	}
}