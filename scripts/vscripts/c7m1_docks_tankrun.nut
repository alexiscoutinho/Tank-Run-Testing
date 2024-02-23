MapState <-
{
	TankModelsBase = [ "models/infected/hulk.mdl", "models/infected/hulk_l4d1.mdl" ]
	CheckDefaultModel = false
}

local oldTankLimit;
local TrainCarTankSpawn = false;

function InputSpawnZombie()
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

	TrainCarTankSpawn = true;
	return true;
}

local TrainCarTankPos;

function OnGameEvent_round_start_post_nav( params )
{
	foreach ( name in [ "button_locked_message", "survivor_brush_blocker" ] )
		EntFire( name, "Kill" );

	local ent = Entities.FindByName( null, "minifinale_button_unlocker" );
	EntityOutputs.RemoveOutput( ent, "OnEntireTeamStartTouch", "tankdoorin_button", "Unlock", "" );
	EntityOutputs.RemoveOutput( ent, "OnEntireTeamStartTouch", "button_locked_message", "Kill", "" );
	EntityOutputs.RemoveOutput( ent, "OnEntireTeamStartTouch", "survivor_brush_blocker", "Enable", "" );
	//?"OnEntireTeamStartTouch" "tank_door_clipEnable0-1"

	EntFire( "tankdoorin_button", "Unlock" );
	EntFire( "tankdoorin_button", "AddOutput", "use_time 2" );
	ent = Entities.FindByName( null, "tankdoorin_button" );
	EntityOutputs.RemoveOutput( ent, "OnUseLocked", "button_locked_message", "GenerateGameEvent", "" );

	ent = Entities.FindByName( null, "spawn_train_tank_coop" );
	ent.ValidateScriptScope();
	ent.GetScriptScope().InputSpawnZombie <- InputSpawnZombie;
	TrainCarTankPos = ent.GetOrigin();

	EntFire( "tankdoorout_button", "AddOutput", "use_time 2" );
}

local func = delete ChallengeScript.OnGameEvent_tank_spawn;
function OnGameEvent_tank_spawn( params )
{
	local tank = GetPlayerFromUserID( params["userid"] );
	if ( !TrainCarTankSpawn || (tank.GetOrigin() - TrainCarTankPos).Length() > 10 )
	{
		func( params );
		return;
	}

	SessionState.Tanks.rawset( tank, tank );

	tank.SetMaxHealth( SessionState.TankHealth * 1.25 );
	tank.SetHealth( SessionState.TankHealth * 1.25 );

	SessionOptions.cm_TankLimit = oldTankLimit;
	TrainCarTankSpawn = false;
}