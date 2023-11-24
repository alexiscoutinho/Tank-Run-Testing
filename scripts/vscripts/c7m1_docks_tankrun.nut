MapState <-
{
	TankModelsBase = [ "models/infected/hulk.mdl", "models/infected/hulk_l4d1.mdl" ]
}

local TrainCarTankSpawn = false;

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
	if ( numTanks >= SessionOptions.cm_TankLimit )
		SessionOptions.cm_TankLimit = numTanks + 1;

	TrainCarTankSpawn = true;
	return true;
}

function OnGameEvent_round_start( params )
{
	local spawner = Entities.FindByName( null, "spawn_train_tank_coop" );

	spawner.ValidateScriptScope();
	spawner.GetScriptScope().InputSpawnZombie <- OnSpawnZombie;
}

local func = delete ChallengeScript.OnGameEvent_tank_spawn;
function OnGameEvent_tank_spawn( params )
{
	local tank = GetPlayerFromUserID( params["userid"] );
	if ( !TrainCarTankSpawn || (tank.GetOrigin() - Entities.FindByName( null, "spawn_train_tank_coop" ).GetOrigin()).Length() > 10 )
	{
		func( params );
		return;
	}

	SessionState.Tanks.rawset( tank, tank );

	tank.SetMaxHealth( SessionState.TankHealth * 1.25 );
	tank.SetHealth( SessionState.TankHealth * 1.25 );

	SessionOptions.cm_TankLimit = 8;
	TrainCarTankSpawn = false;
}