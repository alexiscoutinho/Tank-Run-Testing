MapState <-
{
	TankModels = [ "models/infected/hulk.mdl", "models/infected/hulk_l4d1.mdl" ]
	CheckDefaultModel = false
}

local oldTankLimit;
local TrainCarTankSpawn = false;

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

	TrainCarTankSpawn = true;
	return true;
}

local TrainCarTankPos;

function OnGameEvent_round_start( params )
{
	foreach ( name in [ "button_locked_message", "survivor_brush_blocker" ] )
		EntFire( name, "Kill" );

	local ent = Entities.FindByName( null, "minifinale_button_unlocker" );
	EntityOutputs.RemoveOutput( ent, "OnEntireTeamStartTouch", "", "", "" );
	//?"OnEntireTeamStartTouch" "tank_door_clipEnable0-1" // assuming it is irrelevant in Tank Run and removing

	EntFire( "tankdoorin_button", "Unlock" );
	EntFire( "tankdoorin_button", "AddOutput", "use_time 2" );
	ent = Entities.FindByName( null, "tankdoorin_button" );
	EntityOutputs.RemoveOutput( ent, "OnUseLocked", "", "", "" );

	ent = Entities.FindByName( null, "spawn_train_tank_coop" );
	ent.ValidateScriptScope();
	ent.GetScriptScope().InputSpawnZombie <- InputSpawnZombie;
	TrainCarTankPos = ent.GetOrigin();

	EntFire( "tankdoorout_button", "AddOutput", "use_time 2" );
}

function OnGameEvent_tank_spawn( params ) // assuming OnGameEvents are run in the order they are registered
{
	if ( TrainCarTankSpawn )
	{
		local tank = GetPlayerFromUserID( params["userid"] );
		if ( (tank.GetOrigin() - TrainCarTankPos).Length() < 10 )
		{
			tank.SetMaxHealth( SessionState.TankHealth * 1.5 );
			tank.SetHealth( SessionState.TankHealth * 1.5 );
			tank.SetModel( "models/infected/hulk_dlc3.mdl" );

			SessionOptions.cm_TankLimit = oldTankLimit;
			TrainCarTankSpawn = false;
		}
	}
}