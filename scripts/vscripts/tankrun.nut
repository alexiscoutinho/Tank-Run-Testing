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
	BaseTankModels = [ "models/infected/hulk.mdl", "models/infected/hulk_dlc3.mdl", "models/infected/hulk_l4d1.mdl" ]
	CheckDefaultModel = true
	CheckSurvivorsInFinaleArea = true
	RescueDelay = 600
	SpawnInterval = 20
	HoldoutSpawnInterval = 40
	//DoubleTanks = false // degenerate
	Tanks = {}//not registering a tank may be buggy
	StartDisabled = false
	TanksDisabled = false
	TankHealth = 4000
	DifficultyHealths = [ 2000, 3000, 4000, 5000 ]
}

local InternalState =
{
	TankModels = []
	HoldoutStarted = false
	HoldoutEnded = false
	LastSpawnTime = 0
	LastAlarmTankTime = 0
	BiledTanks = {}
	LeftSafeAreaThink = false
	SpawnTankThink = false
	TankSpeedThink = true
	BileHurtTankThink = false
	EndHoldoutThink = false
}
//remove local var declarations inside all loops
if ( Director.IsFirstMapInScenario() )
{
	function OnGameplayStart() // check for primary weapons
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
}

local director = Entities.FindByClassname( null, "info_director" ); // apparently breaks when there are duplicate entities
if ( director )
{
	director.ValidateScriptScope();
	local scope = director.GetScriptScope();

	function CheckDirectorOff() // ignoring local scripts of custom finale stages as they are most likely unrelated to safe areas
	{
		local LDO = g_MapScript.LocalScript.DirectorOptions;
		if ( ("ProhibitBosses" in LDO && LDO.ProhibitBosses == true || "TankLimit" in LDO && LDO.TankLimit == 0)
			&& ("SpecialRespawnInterval" in LDO && LDO.SpecialRespawnInterval > 1000 || "MaxSpecials" in LDO && LDO.MaxSpecials == 0)
			&& "CommonLimit" in LDO && LDO.CommonLimit == 0 )
			SessionState.TanksDisabled = true;
		else
			SessionState.TanksDisabled = false;
	}

	scope.InputBeginScript <- function ()
	{
		DoEntFire( "!self", "RunScriptCode", "g_ModeScript.CheckDirectorOff()", 0.0, null, self );
		return true;
	}
	scope.InputEndScript <- function ()
	{
		SessionState.TanksDisabled = false;
		return true;
	}
}

local triggerFinale = Entities.FindByClassname( null, "trigger_finale" );
if ( IsMissionFinalMap() || triggerFinale )
{
	MutationOptions.ShouldPlayBossMusic <- @( idx ) true;

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

	function GetNextStage()
	{
		if ( InternalState.HoldoutEnded )
		{
			SessionOptions.ScriptedStageType = STAGE_ESCAPE;
			return;
		}
		if ( InternalState.HoldoutStarted )
		{
			SessionOptions.ScriptedStageType = STAGE_DELAY;
			SessionOptions.ScriptedStageValue = -1;
		}
	}

	function EndHoldoutThink()
	{
		if ( HUDReadTimer( 0 ) <= 0 )
		{
			InternalState.EndHoldoutThink = false;
			InternalState.HoldoutEnded = true;
			Director.ForceNextStage();

			TankRunHUD.Fields.rescue_time.flags = TankRunHUD.Fields.rescue_time.flags | HUD_FLAG_NOTVISIBLE;
			HUDManageTimers( 0, TIMER_DISABLE, 0 );
		}
	}

	if ( triggerFinale )
	{
		const FINALE = 64;

		function OnGameEvent_round_start_post_nav( params )
		{
			if ( !("allAreas" in getroottable()) )
			{
				::allAreas <- {};
				NavMesh.GetAllAreas( allAreas );

				if ( SessionState.CheckSurvivorsInFinaleArea )
				{
					::finaleAreas <- {};
					foreach ( area in allAreas )
					{
						if ( area.HasSpawnAttributes( FINALE ) )
							finaleAreas[area] <- true;
					}
				}
			}

			foreach ( area in allAreas )
				area.RemoveSpawnAttributes( FINALE );
		}

		triggerFinale.ValidateScriptScope(); // what if you have multiple trigger_finale entities?
		local scope = triggerFinale.GetScriptScope();

		scope.InputUse <- function ()
		{
			if ( SessionState.CheckSurvivorsInFinaleArea )
			{
				for ( local player; player = Entities.FindByClassname( player, "player" ); )
				{
					if ( player.IsSurvivor() && !player.IsDead() && !player.IsDying() && !player.IsIncapacitated()
						&& !player.IsHangingFromLedge() && !(player.GetLastKnownArea() in finaleAreas) )
						return true;
				}
			}

			foreach ( area in allAreas )
				area.SetSpawnAttributes( area.GetSpawnAttributes() | FINALE );
			return true;
		}
		scope.InputForceFinaleStart <- scope.InputUse;

		if ( NetProps.GetPropInt( triggerFinale, "m_bIsSacrificeFinale" ) )
		{
			function OnGameEvent_generator_started( params )
			{
				if ( !InternalState.HoldoutStarted )
					return;

				HUDManageTimers( 0, TIMER_COUNTDOWN, HUDReadTimer( 0 ) - 30 );
				if ( SessionState.Tanks.len() < SessionOptions.cm_TankLimit )
					ZSpawn( { type = 8 } );
			}
		}
	}

	function OnGameEvent_finale_start( params )
	{
		if ( SessionState.StartDisabled )
		{
			InternalState.SpawnTankThink = true;
			ReleaseTriggerMultiples();
		}

		local triggerFinale = Entities.FindByClassname( null, "trigger_finale" );
		if ( NetProps.GetPropInt( triggerFinale, "m_type" ) == 4 )
			return;

		HUDManageTimers( 0, TIMER_COUNTDOWN, SessionState.RescueDelay );
		TankRunHUD.Fields.rescue_time.flags = TankRunHUD.Fields.rescue_time.flags & ~HUD_FLAG_NOTVISIBLE;

		SessionState.SpawnInterval = SessionState.HoldoutSpawnInterval;
		InternalState.HoldoutStarted = true;
		InternalState.EndHoldoutThink = true;
	}

	function OnGameEvent_gauntlet_finale_start( params )
	{
		if ( SessionState.StartDisabled )
		{
			InternalState.SpawnTankThink = true;
			ReleaseTriggerMultiples();
		}
	}

	function OnGameEvent_finale_vehicle_leaving( params )
	{
		InternalState.SpawnTankThink = false;
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
				else if ( weaponClass == "weapon_rifle_m60" )
					damageTable.DamageDone = damageTable.DamageDone * 1.5;

				if ( damageTable.DamageType & DMG_BLAST )
				{
					if ( weaponClass.find( "smg" ) != null )
						damageTable.Victim.OverrideFriction( 0.9, 2.5 );
					else if ( weaponClass.find( "shotgun" ) != null )
						damageTable.Victim.OverrideFriction( 1.8, 2.5 );
					else if ( weaponClass.find( "sniper" ) != null || weaponClass.find( "hunting" ) != null )
						damageTable.Victim.OverrideFriction( 0.9, 2.5 );
					else if ( weaponClass.find( "rifle" ) != null )
						damageTable.Victim.OverrideFriction( 0.9, 2.5 );
				}//cant easily differentiate bigger gl explosion
			}
		}
	}
	return true;
}

function ReleaseTriggerMultiples()//or Activate/StartTankSpawning? depends if u lock them
{
	for ( local trigger; trigger = Entities.FindByClassname( trigger, "trigger_multiple" ); )
	{
		if ( NetProps.GetPropInt( trigger, "m_bAllowIncapTouch" ) == 1 && NetProps.GetPropInt( trigger, "m_iEntireTeam" ) == 2 )//should I go overkill with == to <>= transform? probably being creative would be enough
			NetProps.SetPropInt( trigger, "m_bAllowIncapTouch", 0 );
	}//should I revive modifiedKV to refresh the triggerFinale pointer and enforce that the Input hook exists? so far, no real case exists
}

function LeftSafeAreaThink()
{
	for ( local player; player = Entities.FindByClassname( player, "player" ); )
	{
		if ( NetProps.GetPropInt( player, "m_iTeamNum" ) != 2 )
			continue;

		if ( ResponseCriteria.GetValue( player, "instartarea" ) == "0" )
		{
			InternalState.LeftSafeAreaThink = false;
			InternalState.SpawnTankThink = true;
			ReleaseTriggerMultiples();
			break;
		}
	}
}

function SpawnTankThink()//finale stage tanks still spawn it seems
{
	if ( SessionState.TanksDisabled )
		return;

	if ( (SessionState.Tanks.len() < SessionOptions.cm_TankLimit || SessionOptions.cm_TankLimit == -1)
		&& (Time() - InternalState.LastSpawnTime >= SessionState.SpawnInterval || InternalState.LastSpawnTime == 0) )
	{
		if ( ZSpawn( { type = 8 } ) )
		{
			if ( InternalState.HoldoutStarted )
				ZSpawn( { type = 8 } );
			InternalState.LastSpawnTime = Time();
		}
	}
}

function TankSpeedThink()//what if a custom map wants a faster tank?
{
	foreach ( tank in SessionState.Tanks )
	{
		if ( tank in InternalState.BiledTanks )
		{
			if ( NetProps.GetPropInt( tank, "m_nWaterLevel" ) == 0 )
				tank.SetFriction( 2.3 );
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
	foreach ( tank, survivor in InternalState.BiledTanks )
		tank.TakeDamage( 100, 0, survivor );
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

	//for ( local ammo; ammo = Entities.FindByModel( ammo, "models/props/terror/ammo_stack.mdl" ); ) // what about coffee ammo?
	//	ammo.Kill();

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

	SessionState.TankHealth = SessionState.DifficultyHealths[ GetDifficulty() ];
	EntFire( "worldspawn", "RunScriptCode", "g_ModeScript.TankRunThink()", 1.0 );
}

function OnGameEvent_difficulty_changed( params )
{
	SessionState.TankHealth = SessionState.DifficultyHealths[ params["newDifficulty"] ];
}

function OnGameEvent_player_left_safe_area( params )
{
	if ( SessionState.StartDisabled )
		return;

	local player = GetPlayerFromUserID( params["userid"] );
	if ( !player )
	{
		InternalState.SpawnTankThink = true;
		ReleaseTriggerMultiples();//should u add a LockTriggerMultiples based on director off? nah should be based on current # of tanks
		return;
	}

	if ( ResponseCriteria.GetValue( player, "instartarea" ) == "1" )
		InternalState.LeftSafeAreaThink = true;
	else
	{
		InternalState.SpawnTankThink = true;
		ReleaseTriggerMultiples();
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

	if ( SessionState.CheckDefaultModel )
	{
		SessionState.CheckDefaultModel = false;

		if ( SessionState.BaseTankModels.find( modelName ) == null )
			SessionState.BaseTankModels.append( modelName );
	}

	local tankModels = InternalState.TankModels;
	if ( tankModels.len() == 0 )
		tankModels.extend( SessionState.BaseTankModels );

	local randomElement = RandomInt( 0, tankModels.len() - 1 );
	local randomModel = tankModels[randomElement];
	tankModels.remove( randomElement );

	if ( randomModel != modelName )
		tank.SetModel( randomModel );
}

function OnGameEvent_tank_killed( params )
{
	local tank = GetPlayerFromUserID( params["userid"] );

	SessionState.Tanks.rawdelete( tank );
	InternalState.BiledTanks.rawdelete( tank );
	if ( InternalState.BiledTanks.len() == 0 )
		InternalState.BileHurtTankThink = false;

	if ( InternalState.HoldoutStarted )
		HUDManageTimers( 0, TIMER_COUNTDOWN, HUDReadTimer( 0 ) - 10 );
}

function OnGameEvent_player_disconnect( params )
{
	local player = GetPlayerFromUserID( params["userid"] );
	if ( !player )
		return;

	if ( player.GetZombieType() == ZOMBIE_TANK )
	{
		SessionState.Tanks.rawdelete( player );
		InternalState.BiledTanks.rawdelete( player );
		if ( InternalState.BiledTanks.len() == 0 )
			InternalState.BileHurtTankThink = false;
	}
}

function OnGameEvent_player_now_it( params )
{
	local attacker = GetPlayerFromUserID( params["attacker"] );
	local victim = GetPlayerFromUserID( params["userid"] );

	if ( !attacker || !victim )
		return;

	if ( attacker.IsSurvivor() && victim.GetZombieType() == ZOMBIE_TANK && !(victim in InternalState.BiledTanks) )
	{
		InternalState.BiledTanks.rawset( victim, attacker );
		if ( InternalState.BiledTanks.len() == 1 )
			InternalState.BileHurtTankThink = true;
	}
}

function OnGameEvent_player_no_longer_it( params )
{
	local victim = GetPlayerFromUserID( params["userid"] );

	if ( !victim )
		return;

	if ( victim.GetZombieType() == ZOMBIE_TANK && victim in InternalState.BiledTanks )
	{
		InternalState.BiledTanks.rawdelete( victim );
		if ( InternalState.BiledTanks.len() == 0 )
			InternalState.BileHurtTankThink = false;
	}
}

function OnGameEvent_triggered_car_alarm( params )
{
	if ( SessionState.Tanks.len() < SessionOptions.cm_TankLimit && (Time() - InternalState.LastAlarmTankTime >= SessionState.SpawnInterval
		|| InternalState.LastAlarmTankTime == 0) )
	{
		if ( ZSpawn( { type = 8 } ) )
			InternalState.LastAlarmTankTime = Time();
	}
}

function OnGameEvent_mission_lost( params )
{
	InternalState.SpawnTankThink = false;
}

function TankRunThink()
{
	if ( InternalState.LeftSafeAreaThink )
		LeftSafeAreaThink();
	if ( InternalState.SpawnTankThink )
		SpawnTankThink();
	if ( InternalState.TankSpeedThink ) //stale check right now
		TankSpeedThink();
	if ( InternalState.BileHurtTankThink )
		BileHurtTankThink();
	if ( InternalState.EndHoldoutThink )
		EndHoldoutThink();

	if ( Director.GetCommonInfectedCount() > 0 )//why only remove commons?
	{// because CI and SI limits are permeable
		EntFire( "infected", "Kill" );
	}
	EntFire( "worldspawn", "RunScriptCode", "g_ModeScript.TankRunThink()", 1.0 );
}