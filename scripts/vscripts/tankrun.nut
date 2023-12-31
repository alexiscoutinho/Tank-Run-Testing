//-----------------------------------------------------
Msg("Activating Tank Run\n");

if ( !IsModelPrecached( "models/infected/hulk.mdl" ) )
	PrecacheModel( "models/infected/hulk.mdl" );
if ( !IsModelPrecached( "models/infected/hulk_dlc3.mdl" ) )
	PrecacheModel( "models/infected/hulk_dlc3.mdl" );
if ( !IsModelPrecached( "models/infected/hulk_l4d1.mdl" ) )
	PrecacheModel( "models/infected/hulk_l4d1.mdl" );

MutationOptions <-
{
	cm_TankRun = true
	cm_ShouldHurry = true
	cm_InfiniteFuel = true
	cm_AllowPillConversion = false
	cm_CommonLimit = 0
	cm_MaxSpecials = 0
	cm_WitchLimit = 0
	cm_TankLimit = 8
	cm_ProhibitBosses = true
	cm_AggressiveSpecials = true

	NoMobSpawns = true
	EscapeSpawnTanks = false

	// convert items that aren't useful
	weaponsToConvert =
	{
		ammo = "upgrade_laser_sight"
	}

	function ConvertWeaponSpawn( classname )
	{
		if ( classname in weaponsToConvert )
		{
			return weaponsToConvert[classname];
		}
		return 0;
	}

	DefaultItems =
	[
		"weapon_pistol_magnum",
	]

	function GetDefaultItem( idx )
	{
		if ( idx < DefaultItems.len() )
		{
			return DefaultItems[idx];
		}
		return 0;
	}
}

MutationState <-
{
	TankModelsBase = [ "models/infected/hulk.mdl", "models/infected/hulk_dlc3.mdl", "models/infected/hulk_l4d1.mdl" ]
	TankModels = []
	FinaleStarted = false
	TriggerRescue = false
	RescueDelay = 600
	LastAlarmTankTime = 0
	LastSpawnTime = 0
	SpawnInterval = 20
	DoubleTanks = false
	Tanks = {}
	TanksBiled = {}
	TanksDisabled = false
	TankHealth = 4000
	TankSpeedThink = true
	BileHurtTankThink = false
	SpawnTankThink = false
	TriggerRescueThink = false
	LeftSafeAreaThink = false
	CheckPrimaryWeaponThink = false
	FinaleType = -1
}

if ( IsMissionFinalMap() )
{
	MutationOptions.ShouldPlayBossMusic <- @( idx ) true;

	local triggerFinale = Entities.FindByClassname( null, "trigger_finale" );
	if ( triggerFinale )
	{
		MutationState.FinaleType = NetProps.GetPropInt( triggerFinale, "m_type" );
		if ( NetProps.GetPropInt( triggerFinale, "m_bIsSacrificeFinale" ) )
		{
			function OnGameEvent_generator_started( params )
			{
				if ( !SessionState.FinaleStarted )
					return;

				HUDManageTimers( 0, TIMER_COUNTDOWN, HUDReadTimer( 0 ) - 30 );
				if ( SessionState.Tanks.len() < SessionOptions.cm_TankLimit )
					ZSpawn( { type = 8 } );
			}
		}
	}

	TankRunHUD <- {};
	function SetupModeHUD()
	{
		TankRunHUD =
		{
			Fields =
			{
				rescue_time =
				{
					slot = HUD_MID_TOP
					name = "rescue"
					special = HUD_SPECIAL_TIMER0
					flags = HUD_FLAG_COUNTDOWN_WARN | HUD_FLAG_BEEP | HUD_FLAG_ALIGN_CENTER | HUD_FLAG_NOTVISIBLE
				}
			}
		}
		HUDSetLayout( TankRunHUD );
	}

	if ( MutationState.FinaleType != 4 )
	{
		function GetNextStage()
		{
			if ( SessionState.TriggerRescue )
			{
				SessionOptions.ScriptedStageType = STAGE_ESCAPE;
				return;
			}
			if ( SessionState.FinaleStarted )
			{
				SessionOptions.ScriptedStageType = STAGE_DELAY;
				SessionOptions.ScriptedStageValue = -1;
			}
		}
	}

	function OnGameEvent_finale_start( params )
	{
		if ( g_MapName == "c6m3_port" || g_MapName == "c11m5_runway" )
		{
			SessionState.TanksDisabled = false;
			SessionState.SpawnTankThink = true;
		}

		if ( SessionState.FinaleType == 4 )
			return;

		HUDManageTimers( 0, TIMER_COUNTDOWN, SessionState.RescueDelay );
		TankRunHUD.Fields.rescue_time.flags = TankRunHUD.Fields.rescue_time.flags & ~HUD_FLAG_NOTVISIBLE;

		SessionState.DoubleTanks = true;
		SessionState.SpawnInterval *= 2;
		SessionState.FinaleStarted = true;
		SessionState.TriggerRescueThink = true;
	}

	function OnGameEvent_gauntlet_finale_start( params )
	{
		if ( g_MapName == "c5m5_bridge" )
		{
			SessionState.TanksDisabled = false;
			SessionState.SpawnTankThink = true;
		}
	}

	function OnGameEvent_finale_vehicle_leaving( params )
	{
		SessionState.SpawnTankThink = false;
	}

	function InputForceFinaleStart() // because of https://github.com/Tsuey/L4D2-Community-Update/issues/462
	{
		const FINALE = 64;

		for ( local player, area; player = Entities.FindByClassname( player, "player" ); )
		{
			if ( player.IsSurvivor() && (player.IsIncapacitated() || player.IsHangingFromLedge()) )
			{
				if ( (area = player.GetLastKnownArea()) && area.GetSpawnAttributes() & FINALE )
					continue;
				//check if Use works with incap with null area
				if ( !activator || !activator.IsPlayer() )
					activator = Director.GetRandomSurvivor();
				DoEntFire( "trigger_finale", "Use", "", 0.0, activator, caller );
				return false;
			}
		}
		return true;
	}
}

function AllowTakeDamage( damageTable )
{
	if ( !damageTable.Attacker || !damageTable.Victim || !damageTable.Inflictor )
		return true;

	if ( damageTable.Victim.IsPlayer() && damageTable.Attacker.IsPlayer() )
	{
		if ( damageTable.Attacker.IsSurvivor() && damageTable.Victim.GetZombieType() == ZOMBIE_TANK )
		{
			if ( damageTable.Inflictor.GetClassname() == "pipe_bomb_projectile" )
				damageTable.DamageDone = 500;
			else if ( damageTable.Weapon )
			{
				local weaponClass = damageTable.Weapon.GetClassname();
				if ( weaponClass == "weapon_pistol" )
					damageTable.DamageDone = damageTable.DamageDone * 1.25;
				else if ( weaponClass == "weapon_melee" )
					damageTable.DamageDone = damageTable.DamageDone * 1.334;
				else if ( damageTable.DamageType & DMG_BLAST )
				{
					if ( weaponClass.find( "smg" ) != null )
						damageTable.Victim.OverrideFriction( 1.2, 2.0 );
					else if ( weaponClass.find( "shotgun" ) != null )
						damageTable.Victim.OverrideFriction( 2.3, 2.0 );
					else if ( weaponClass.find( "sniper" ) != null || weaponClass.find( "hunting" ) != null )
						damageTable.Victim.OverrideFriction( 1.5, 2.0 );
					else if ( weaponClass.find( "rifle" ) != null )
						damageTable.Victim.OverrideFriction( 1.2, 2.0 );
				}//cant easily differentiate bigger gl explosion
			}
		}
	}
	return true;
}

function TriggerRescueThink()
{
	if ( HUDReadTimer( 0 ) <= 0 )
	{
		SessionState.TriggerRescue = true;
		SessionState.TriggerRescueThink = false;
		Director.ForceNextStage();

		TankRunHUD.Fields.rescue_time.flags = TankRunHUD.Fields.rescue_time.flags | HUD_FLAG_NOTVISIBLE;
		HUDManageTimers( 0, TIMER_DISABLE, 0 );
	}
}

function SpawnTankThink()//finale stage tanks still spawn it seems
{//deal with unlimited tanks (-1)
	if ( SessionState.Tanks.len() < SessionOptions.cm_TankLimit && (Time() - SessionState.LastSpawnTime >= SessionState.SpawnInterval
		|| SessionState.LastSpawnTime == 0) )
	{
		if ( ZSpawn( { type = 8 } ) )
		{
			if ( SessionState.DoubleTanks )
				ZSpawn( { type = 8 } );
			SessionState.LastSpawnTime = Time();
		}
	}
}

function ReleaseTriggerMultiples()
{
	local modifiedKV = false;
	for ( local trigger; trigger = Entities.FindByClassname( trigger, "trigger_multiple" ); )
	{
		if ( NetProps.GetPropInt( trigger, "m_bAllowIncapTouch" ) == 1 && NetProps.GetPropInt( trigger, "m_iEntireTeam" ) == 2 )
		{//should I go overkill with == to <>= transform? probably being creative would be enough
			NetProps.SetPropInt( trigger, "m_bAllowIncapTouch", 0 );
			modifiedKV = true;
		}
	}

	if ( modifiedKV )
	{
		local triggerFinale = Entities.FindByClassname( null, "trigger_finale" );
		if ( triggerFinale )
		{
			triggerFinale.ValidateScriptScope();
			triggerFinale.GetScriptScope().InputForceFinaleStart <- InputForceFinaleStart;
		}
	}
}

function LeftSafeAreaThink()
{
	for ( local player; player = Entities.FindByClassname( player, "player" ); )
	{
		if ( NetProps.GetPropInt( player, "m_iTeamNum" ) != 2 )
			continue;

		if ( ResponseCriteria.GetValue( player, "instartarea" ) == "0" )
		{
			SessionState.LeftSafeAreaThink = false;
			SessionState.SpawnTankThink = true;
			ReleaseTriggerMultiples();
			break;
		}
	}
}

function TankSpeedThink()//what if a custom map wants a faster tank?
{
	foreach ( tank in SessionState.Tanks )
	{
		if ( tank in SessionState.TanksBiled )
		{
			if ( NetProps.GetPropInt( tank, "m_nWaterLevel" ) == 0 )
				tank.SetFriction( 2.0 );
			else
				tank.SetFriction( 2.5 );
		}
		else
		{
			if ( NetProps.GetPropInt( tank, "m_nWaterLevel" ) == 0 )
				tank.SetFriction( 1.0 );
			else
				tank.SetFriction( 1.7 );
		}
	}
}

function BileHurtTankThink()
{
	foreach ( tank, survivor in SessionState.TanksBiled )
		tank.TakeDamage( 100, 0, survivor );
}

function CheckDifficultyForTankHealth( difficulty )
{
	local health = [ 2000, 3000, 4000, 5000 ];
	SessionState.TankHealth = health[difficulty];
}

if ( Director.IsFirstMapInScenario() )
{
	function CheckPrimaryWeaponThink()
	{
		local startArea = null;
		local startPos = null;
		for ( local survivorSpawn; survivorSpawn = Entities.FindByClassname( survivorSpawn, "info_survivor_position" ); )
		{
			local area = NavMesh.GetNearestNavArea( survivorSpawn.GetOrigin(), 100, false, false );
			if ( area && (area.HasSpawnAttributes( 128 ) || area.HasSpawnAttributes( 2048 )) )
			{
				startArea = area;
				startPos = survivorSpawn.GetOrigin();
				break;
			}
		}

		if ( !startPos )
			return;

		for ( local weapon; weapon = Entities.FindByClassnameWithin( weapon, "weapon_*", startPos, 1200 ); )
		{
			if ( weapon.GetOwnerEntity() )
				continue;

			local weaponName = weapon.GetClassname();
			local primaryNames = [ "smg", "rifle", "shotgun", "sniper", "grenade" ];
			if ( weaponName == "weapon_spawn" )
			{
				weaponName = NetProps.GetPropString( weapon, "m_iszWeaponToSpawn" );
				if ( weaponName.find( "pistol" ) != null )
					continue;
				primaryNames.append( "any" );
			}

			foreach( name in primaryNames )
			{
				if ( weaponName.find( name ) != null )
					return;
			}
		}

		local itemNames = [ "weapon_pistol_spawn", "weapon_pistol_magnum_spawn", "weapon_spawn", "weapon_melee_spawn" ];
		foreach( name in itemNames )
		{
			local item = Entities.FindByClassnameNearest( name, startPos, 600 );
			if ( item )
			{
				local nearestArea = NavMesh.GetNearestNavArea( item.GetOrigin(), 100, false, false );
				if ( nearestArea )
					startArea = nearestArea;
				break;
			}
		}

		local w = [ "any_smg", "tier1_shotgun" ];
		for ( local i = 0; i < 2; i++ )
			SpawnEntityFromTable( "weapon_spawn", {
				spawn_without_director = 1
				weapon_selection = w[i]
				count = 5
				spawnflags = 3
				origin = startArea.FindRandomSpot() + Vector( 0, 0, 50 )
				angles = Vector( RandomInt( 0, 90 ), RandomInt( 0, 90 ), 90 )
			} );
	}

	function OnGameplayStart()
	{
		SessionState.CheckPrimaryWeaponThink = true;
	}
}

function OnGameEvent_round_start( params )
{
	for ( local spawner; spawner = Entities.FindByClassname( spawner, "info_zombie_spawn" ); )
	{
		local population = NetProps.GetPropString( spawner, "m_szPopulation" );

		if ( population == "tank" || population == "river_docks_trap" )
			continue;
		else
			spawner.Kill();
	}

	for ( local ammo; ammo = Entities.FindByModel( ammo, "models/props/terror/ammo_stack.mdl" ); )
		ammo.Kill();

	local filter_survivor;
	for ( local filter; filter = Entities.FindByClassname( filter, "filter_activator_team" ); )
	{
		if ( NetProps.GetPropInt( filter, "m_iFilterTeam" ) == 2 )
		{
			filter_survivor = filter.GetName();
			break;
		}
	}
	if ( filter_survivor )
	{
		for ( local trigger, spawnflags; trigger = Entities.FindByClassname( trigger, "trigger_playermovement" ); )
		{
			spawnflags = NetProps.GetPropInt( trigger, "m_spawnflags" );

			if ( NetProps.GetPropString( trigger, "m_iFilterName" ) == filter_survivor && spawnflags & 4096 ) // Auto-walk while in trigger
			{
				SpawnEntityFromTable( "trigger_playermovement", { // because just changing filter doesn't work
					model = trigger.GetModelName()
					vscripts = NetProps.GetPropString( trigger, "m_iszVScripts" )
					thinkfunction = trigger.GetScriptId()
					targetname = trigger.GetName()
					StartDisabled = NetProps.GetPropInt( trigger, "m_bDisabled" )
					spawnflags = spawnflags
					parentname = NetProps.GetPropString( trigger, "m_iParent" ) // presumably faster than trigger.GetMoveParent().GetName() //does direct handle work though? getname method works with parents set by Input
					origin = trigger.GetOrigin()
					globalname = NetProps.GetPropString( trigger, "m_iGlobalname" )
				} ); // I/Os missing and possibly more. Needs more thorough testing in general.
				trigger.Kill();
			}
		}
	}

	if ( g_MapName == "c5m5_bridge" || g_MapName == "c6m3_port" || g_MapName == "c11m5_runway" )
		SessionState.TanksDisabled = true;

	CheckDifficultyForTankHealth( GetDifficulty() );
	EntFire( "worldspawn", "RunScriptCode", "g_ModeScript.TankRunThink()", 1.0 );
}

function OnGameEvent_difficulty_changed( params )
{
	CheckDifficultyForTankHealth( params["newDifficulty"] );
}

function OnGameEvent_player_left_safe_area( params )
{
	if ( SessionState.TanksDisabled )
		return;

	local player = GetPlayerFromUserID( params["userid"] );
	if ( !player )
	{
		SessionState.SpawnTankThink = true;
		ReleaseTriggerMultiples();
		return;
	}

	if ( ResponseCriteria.GetValue( player, "instartarea" ) == "1" )
		SessionState.LeftSafeAreaThink = true;
	else
	{
		SessionState.SpawnTankThink = true;
		ReleaseTriggerMultiples();
	}
}

function OnGameEvent_player_disconnect( params )
{
	local player = GetPlayerFromUserID( params["userid"] );
	if ( !player )
		return;

	if ( player.GetZombieType() == ZOMBIE_TANK )
	{
		SessionState.Tanks.rawdelete( player );
		SessionState.TanksBiled.rawdelete( player );
		if ( SessionState.TanksBiled.len() == 0 )
			SessionState.BileHurtTankThink = false;
	}
}

function OnGameEvent_mission_lost( params )
{
	SessionState.SpawnTankThink = false;
}

function OnGameEvent_player_now_it( params )
{
	local attacker = GetPlayerFromUserID( params["attacker"] );
	local victim = GetPlayerFromUserID( params["userid"] );

	if ( !attacker || !victim )
		return;

	if ( attacker.IsSurvivor() && victim.GetZombieType() == ZOMBIE_TANK && !(victim in SessionState.TanksBiled) )
	{
		SessionState.TanksBiled.rawset( victim, attacker );
		if ( SessionState.TanksBiled.len() == 1 )
			SessionState.BileHurtTankThink = true;
	}
}

function OnGameEvent_player_no_longer_it( params )
{
	local victim = GetPlayerFromUserID( params["userid"] );

	if ( !victim )
		return;

	if ( victim.GetZombieType() == ZOMBIE_TANK && victim in SessionState.TanksBiled )
	{
		SessionState.TanksBiled.rawdelete( victim );
		if ( SessionState.TanksBiled.len() == 0 )
			SessionState.BileHurtTankThink = false;
	}
}

function OnGameEvent_triggered_car_alarm( params )
{
	if ( SessionState.Tanks.len() < SessionOptions.cm_TankLimit && (Time() - SessionState.LastAlarmTankTime >= SessionState.SpawnInterval
		|| SessionState.LastAlarmTankTime == 0) )
	{
		if ( ZSpawn( { type = 8 } ) )
			SessionState.LastAlarmTankTime = Time();
	}
}

function OnGameEvent_tank_spawn( params )
{
	local tank = GetPlayerFromUserID( params["userid"] );
	if ( !tank )
		return;

	SessionState.Tanks.rawset( tank, tank );

	tank.SetMaxHealth( SessionState.TankHealth );
	tank.SetHealth( SessionState.TankHealth );
	local modelName = tank.GetModelName();

	if ( SessionState.TankModelsBase.len() == 0 )
		SessionState.TankModelsBase.append( modelName );

	local tankModels = SessionState.TankModels;
	if ( tankModels.len() == 0 )
		tankModels.extend( SessionState.TankModelsBase );
	local foundModel = tankModels.find( modelName );
	if ( foundModel != null )
	{
		tankModels.remove( foundModel );
		return;
	}

	local randomElement = RandomInt( 0, tankModels.len() - 1 );
	local randomModel = tankModels[randomElement];
	tankModels.remove( randomElement );

	tank.SetModel( randomModel );
}

function OnGameEvent_tank_killed( params )
{
	local tank = GetPlayerFromUserID( params["userid"] );

	SessionState.Tanks.rawdelete( tank );
	SessionState.TanksBiled.rawdelete( tank );
	if ( SessionState.TanksBiled.len() == 0 )
		SessionState.BileHurtTankThink = false;

	if ( SessionState.FinaleStarted )
		HUDManageTimers( 0, TIMER_COUNTDOWN, HUDReadTimer( 0 ) - 10 );
}

function TankRunThink()
{
	if ( SessionState.LeftSafeAreaThink )
		LeftSafeAreaThink();
	if ( SessionState.SpawnTankThink )
		SpawnTankThink();
	if ( SessionState.TriggerRescueThink )
		TriggerRescueThink();
	if ( SessionState.TankSpeedThink ) //stale check right now
		TankSpeedThink();
	if ( SessionState.BileHurtTankThink )
		BileHurtTankThink();
	if ( SessionState.CheckPrimaryWeaponThink )
	{
		CheckPrimaryWeaponThink();
		SessionState.CheckPrimaryWeaponThink = false;
	}
	if ( Director.GetCommonInfectedCount() > 0 )//why only remove commons?
	{// because CI and SI limits are permeable
		for ( local infected; infected = Entities.FindByClassname( infected, "infected" ); )
			infected.Kill();
	}
	EntFire( "worldspawn", "RunScriptCode", "g_ModeScript.TankRunThink()", 1.0 );
}