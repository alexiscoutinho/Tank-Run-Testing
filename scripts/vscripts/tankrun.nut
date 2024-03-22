//-----------------------------------------------------
Msg("Activating Tank Run\n");

if ( !IsModelPrecached( "models/infected/hulk.mdl" ) )
	PrecacheModel( "models/infected/hulk.mdl" );
if ( !IsModelPrecached( "models/infected/hulk_l4d1.mdl" ) )
	PrecacheModel( "models/infected/hulk_l4d1.mdl" );
if ( !IsModelPrecached( "models/infected/hulk_dlc3.mdl" ) )
	PrecacheModel( "models/infected/hulk_dlc3.mdl" );

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
	TankModels = [ "models/infected/hulk.mdl", "models/infected/hulk_dlc3.mdl", "models/infected/hulk_l4d1.mdl" ]
	CheckDefaultModel = true
	CheckSurvivorsInFinaleArea = true
	HoldoutStarted = false
	HoldoutEnded = false
	RescueDelay = 600
	FirstSpawnDelay = 0
	SpawnInterval = 20
	HoldoutSpawnInterval = 40
	//DoubleTanks = false // degenerate
	TanksDisabled = false
	TankHealth = 4000
	DifficultyHealths = [ 2000, 3000, 4000, 5000 ]
	DeployChance = 50
	SafeRoomAbandonDelay = 10
}

local InternalState =
{
	LastSpawnTime = 0
	LastAlarmTankTime = 0
	SafeRoomCloseTime = 0
	Tanks = {}
	BiledTanks = {}
	LeftSafeAreaThink = false
	SpawnTankThink = false
	TankSpeedThink = true
	BileHurtTankThink = false
	SafeRoomAbandonThink = false
	EndHoldoutThink = false
}

local function ReleaseTriggerMultiples()//or Activate/StartTankSpawning? depends if u lock them
{
	for ( local trigger; trigger = Entities.FindByClassname( trigger, "trigger_multiple" ); )
	{
		if ( NetProps.GetPropInt( trigger, "m_bAllowIncapTouch" ) == 1 && NetProps.GetPropInt( trigger, "m_iEntireTeam" ) == 2 )//should I go overkill with == to <>= transform? probably being creative would be enough
			NetProps.SetPropInt( trigger, "m_bAllowIncapTouch", 0 );
	}//should I revive modifiedKV to refresh the triggerFinale pointer and enforce that the Input hook exists? so far, no real case exists
}

local function LeftSafeAreaThink()
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

local function SpawnTankThink()//finale stage tanks still spawn it seems
{
	if ( SessionState.TanksDisabled )
		return;

	if ( (InternalState.Tanks.len() < SessionOptions.cm_TankLimit || SessionOptions.cm_TankLimit == -1)
		&& (Time() - InternalState.LastSpawnTime >= SessionState.SpawnInterval || InternalState.LastSpawnTime == 0) )
	{
		if ( ZSpawn( { type = 8 } ) )//lock safe room door when players are still loading
		{
			if ( SessionState.HoldoutStarted )
				ZSpawn( { type = 8 } );
			InternalState.LastSpawnTime = Time();
		}
	}
}

local function TankSpeedThink()//what if a custom map wants a faster tank?
{
	foreach ( tank in InternalState.Tanks )
	{
		if ( InternalState.BiledTanks.rawin( tank ) )
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

local function BileHurtTankThink()
{
	foreach ( tank, survivor in InternalState.BiledTanks )
		tank.TakeDamage( 100, 0, survivor );
}

local SafeRoomAbandonThink, EndHoldoutThink;

local function TankRunThink()
{
	if ( InternalState.LeftSafeAreaThink )
		LeftSafeAreaThink();
	if ( InternalState.SpawnTankThink )
		SpawnTankThink();
	if ( InternalState.TankSpeedThink ) //stale check right now
		TankSpeedThink();
	if ( InternalState.BileHurtTankThink )
		BileHurtTankThink();
	if ( InternalState.SafeRoomAbandonThink )
		SafeRoomAbandonThink();
	if ( InternalState.EndHoldoutThink )
		EndHoldoutThink();

	if ( Director.GetCommonInfectedCount() > 0 )//why only remove commons?
	{// because CI and SI limits are permeable
		EntFire( "infected", "Kill" );
	}
	EntFire( "worldspawn", "CallScriptFunction", "TankRunThink", 1.0 );
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

			foreach ( name in primaryNames )
			{
				if ( weaponName.find( name ) != null )
					return;
			}
		}

		local itemNames = [ "weapon_pistol_spawn", "weapon_pistol_magnum_spawn", "weapon_spawn", "weapon_melee_spawn" ];
		foreach ( name in itemNames )
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
/*
local director = Entities.FindByClassname( null, "info_director" ); // apparently breaks when there are duplicate entities
if ( director )
{
	director.ValidateScriptScope();
	local scope = director.GetScriptScope();

	scope.InputBeginScript <- function () // ignoring local scripts of custom finale stages as they are most likely unrelated to safe areas
	{
		local LDO = g_MapScript.LocalScript.DirectorOptions;
		if ( ("ProhibitBosses" in LDO && LDO.ProhibitBosses == true || "TankLimit" in LDO && LDO.TankLimit == 0)
			&& ("SpecialRespawnInterval" in LDO && LDO.SpecialRespawnInterval > 1000 || "MaxSpecials" in LDO && LDO.MaxSpecials == 0)
			&& "CommonLimit" in LDO && LDO.CommonLimit == 0 )
			SessionState.TanksDisabled = true;
		else
			SessionState.TanksDisabled = false;

		return true;
	}
	scope.InputEndScript <- function ()
	{
		SessionState.TanksDisabled = false;
		return true;
	}
}
*/
local triggerFinale = Entities.FindByClassname( null, "trigger_finale" ); // ignoring conditional point_template spawns
if ( IsMissionFinalMap() || triggerFinale )
{
	MutationOptions.ShouldPlayBossMusic <- @( idx ) true;

	local finaleType = NetProps.GetPropInt( triggerFinale, "m_type" );
	if ( !triggerFinale || finaleType == 0 || finaleType == 2 )
	{
		EndHoldoutThink = function ()
		{
			if ( HUDReadTimer( 0 ) <= 0 )
			{
				InternalState.EndHoldoutThink = false;
				SessionState.HoldoutEnded = true;
				Director.ForceNextStage();

				TankRunHUD.Fields.rescue_time.flags = TankRunHUD.Fields.rescue_time.flags | HUD_FLAG_NOTVISIBLE;
				HUDManageTimers( 0, TIMER_DISABLE, 0 );
			}
		}

		function DecreaseHUDTimerBy( time )
		{
			HUDManageTimers( 0, TIMER_COUNTDOWN, HUDReadTimer( 0 ) - time );

			for ( local player; player = Entities.FindByClassname( player, "player" ); )
			{
				if ( !IsPlayerABot( player ) )
				{
					EmitSoundOnClient( "ScavengeSB.RoundTimeIncrement", player );
					EmitSoundOnClient( "ScavengeSB.RoundTimeIncrement", player );
					EmitSoundOnClient( "ScavengeSB.RoundTimeIncrement", player );
				}
			}
		}

		function SetupModeHUD()
		{
			TankRunHUD <-
			{
				Fields =
				{
					rescue_time =
					{
						slot = HUD_MID_TOP
						name = "rescue"
						special = HUD_SPECIAL_TIMER0
						flags = HUD_FLAG_NOTVISIBLE/* | HUD_FLAG_ALIGN_CENTER*/ | HUD_FLAG_COUNTDOWN_WARN | HUD_FLAG_BEEP
					}
				}
			}
			HUDPlace( HUD_MID_TOP, 0.45, 0.03, 0.1, 0.04 );
			HUDSetLayout( TankRunHUD );
		}

		function GetNextStage()
		{
			if ( SessionState.HoldoutEnded )
			{
				SessionOptions.ScriptedStageType = STAGE_ESCAPE;
				return;
			}
			if ( SessionState.HoldoutStarted )
			{
				SessionOptions.ScriptedStageType = STAGE_DELAY;
				SessionOptions.ScriptedStageValue = -1;
			}
		}
	}

	if ( triggerFinale )
	{
		const FINALE = 64;

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
						finaleAreas.rawset( area, area );
				}
			}

			foreach ( area in finaleAreas )
				area.RemoveSpawnAttributes( FINALE );
		}

		triggerFinale.ValidateScriptScope(); // what if you have multiple trigger_finale entities?
		local scope = triggerFinale.GetScriptScope();

		scope.InputUse <- function () // poor compatibility though
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

			foreach ( area in finaleAreas )
				area.SetSpawnAttributes( area.GetSpawnAttributes() | FINALE );
			return true;
		}
		scope.InputForceFinaleStart <- scope.InputUse;

		if ( NetProps.GetPropInt( triggerFinale, "m_bIsSacrificeFinale" ) )
		{
			function OnGameEvent_generator_started( params )
			{
				if ( !SessionState.HoldoutStarted )
					return;

				if ( !SessionState.HoldoutEnded ) // shouldn't the generators be disabled instead?
					DecreaseHUDTimerBy( 30 );

				if ( InternalState.Tanks.len() < SessionOptions.cm_TankLimit )
					ZSpawn( { type = 8 } );
			}
		}
	}

	function OnGameEvent_finale_start( params )
	{
		if ( SessionState.FirstSpawnDelay == -1 )
		{
			InternalState.SpawnTankThink = true;
			ReleaseTriggerMultiples();
		}

		if ( finaleType == 4 )
			return;

		HUDManageTimers( 0, TIMER_COUNTDOWN, SessionState.RescueDelay );
		TankRunHUD.Fields.rescue_time.flags = TankRunHUD.Fields.rescue_time.flags & ~HUD_FLAG_NOTVISIBLE;

		SessionState.SpawnInterval = SessionState.HoldoutSpawnInterval;
		SessionState.HoldoutStarted = true;
		InternalState.EndHoldoutThink = true;
	}

	function OnGameEvent_gauntlet_finale_start( params )
	{
		if ( SessionState.FirstSpawnDelay == -1 )
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
else
{
	const CHECKPOINT = 2048;

	SafeRoomAbandonThink = function ()
	{
		if ( Time() - InternalState.SafeRoomCloseTime >= SessionState.SafeRoomAbandonDelay )
		{
			for ( local player; player = Entities.FindByClassname( player, "player" ); )
			{
				if ( !player.IsSurvivor() || player.IsDead() || player.IsDying() )
					continue;

				if ( player.IsIncapacitated() || player.IsHangingFromLedge() )
				{
					if ( GetCurrentFlowPercentForPlayer( player ) > 50 && player.GetLastKnownArea().HasSpawnAttributes( CHECKPOINT ) )
						return;
				}
				else
				{
					if ( GetCurrentFlowPercentForPlayer( player ) < 50 || !player.GetLastKnownArea().HasSpawnAttributes( CHECKPOINT ) )
						return;
				}
			}
			Convars.SetValue( "survivor_incap_decay_rate", Convars.GetFloat( "survivor_incap_hopeless_decay_rate" ) );
			InternalState.SafeRoomAbandonThink = false;
		}
	}

	function OnFullyClosed()
	{
		for ( local player; player = Entities.FindByClassname( player, "player" ); )
		{
			if ( player.IsSurvivor() && !player.IsDead() && !player.IsDying()
				&& GetCurrentFlowPercentForPlayer( player ) > 50 && player.GetLastKnownArea().HasSpawnAttributes( CHECKPOINT ) )//what about those null cases?//u should instead test if the standing players are in the closed saferoom, not any random open end saferoom
			{
				InternalState.SafeRoomCloseTime = Time();
				InternalState.SafeRoomAbandonThink = true;
				break;
			}
		}
	}

	function OnOpen()
	{
		InternalState.SafeRoomAbandonThink = false;
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

const FL_KILLME = 67108864;

weaponsToConvert <-
{
	// ignoring non-_spawn items//what about rng spawners?
	weapon_upgradepack_explosive_spawn = "upgrade_ammo_explosive"
	weapon_upgradepack_incendiary_spawn = "upgrade_ammo_incendiary"
}

function OnGameEvent_round_start( params )
{
	SessionState.TankHealth = SessionState.DifficultyHealths[ GetDifficulty() ];
	Convars.SetValue( "survivor_incap_decay_rate", 3 );

	for ( local spawner, population; spawner = Entities.FindByClassname( spawner, "info_zombie_spawn" ); )
	{
		population = NetProps.GetPropString( spawner, "m_szPopulation" );
		if ( population != "tank" && population != "river_docks_trap" )
			spawner.Kill();
	}

	for ( local upgradepack; upgradepack = Entities.FindByClassname( upgradepack, "weapon_upgradepack_*" ); )
	{
		if ( NetProps.GetPropInt( upgradepack, "m_fFlags" ) & FL_KILLME )
			continue;

		if ( RandomInt( 1, 100 ) <= SessionState.DeployChance )
		{
			SpawnEntityFromTable( weaponsToConvert[ upgradepack.GetClassname() ], {
				origin = upgradepack.GetOrigin()
				angles = upgradepack.GetAngles().ToKVString()
			} );//port other KVs like parent? does standard conversion even consider angles, etc?
			upgradepack.Kill();
		}
	}

	for ( local door, scope; door = Entities.FindByClassname( door, "prop_door_rotating_checkpoint" ); )
	{
		if ( GetFlowPercentForPosition( door.GetOrigin(), false ) > 50 ) // must use conservative flow cutoff because of multi-ending maps
		{
			EntityOutputs.AddOutput( door, "OnFullyClosed", "!self", "RunScriptCode", "g_ModeScript.OnFullyClosed()", 0.0, -1 );
			EntityOutputs.AddOutput( door, "OnOpen", "!self", "RunScriptCode", "g_ModeScript.OnOpen()", 0.0, -1 );
		}
	}

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
			if ( NetProps.GetPropInt( trigger, "m_fFlags" ) & FL_KILLME )
				continue;

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

	local worldspawn = Entities.First();
	worldspawn.ValidateScriptScope();
	worldspawn.GetScriptScope().TankRunThink <- TankRunThink.bindenv( this );
	EntFire( "worldspawn", "CallScriptFunction", "TankRunThink", 1.0 );
}

function OnGameEvent_difficulty_changed( params )
{
	SessionState.TankHealth = SessionState.DifficultyHealths[ params["newDifficulty"] ];
}

function OnGameEvent_player_left_safe_area( params )
{
	if ( SessionState.FirstSpawnDelay == -1 )
		return;
	if ( SessionState.FirstSpawnDelay > 0 )
	{
		SessionState.TanksDisabled = true;
		EntFire( "worldspawn", "RunScriptCode", "SessionState.TanksDisabled = false", SessionState.FirstSpawnDelay );
	}

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

	InternalState.Tanks.rawset( tank, tank );
	tank.SetMaxHealth( SessionState.TankHealth );
	tank.SetHealth( SessionState.TankHealth );

	local tankModels = SessionState.TankModels;
	local modelName = tank.GetModelName();

	if ( SessionState.CheckDefaultModel )
	{
		SessionState.CheckDefaultModel = false;

		if ( tankModels.find( modelName ) == null )
			tankModels.append( modelName );
	}

	local randomModel = tankModels[ RandomInt( 0, tankModels.len() - 1 ) ];
	if ( randomModel != modelName )
		tank.SetModel( randomModel );
}

function OnGameEvent_tank_killed( params )
{
	local tank = GetPlayerFromUserID( params["userid"] );

	InternalState.Tanks.rawdelete( tank );
	InternalState.BiledTanks.rawdelete( tank );
	if ( InternalState.BiledTanks.len() == 0 )
		InternalState.BileHurtTankThink = false;

	if ( SessionState.HoldoutStarted && !SessionState.HoldoutEnded )
		DecreaseHUDTimerBy( 10 );
}

function OnGameEvent_player_disconnect( params )
{
	local player = GetPlayerFromUserID( params["userid"] );
	if ( !player )
		return;

	if ( player.GetZombieType() == ZOMBIE_TANK )
	{
		InternalState.Tanks.rawdelete( player );
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

	if ( attacker.IsSurvivor() && victim.GetZombieType() == ZOMBIE_TANK && !InternalState.BiledTanks.rawin( victim ) )
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

	if ( victim.GetZombieType() == ZOMBIE_TANK && InternalState.BiledTanks.rawin( victim ) )
	{
		InternalState.BiledTanks.rawdelete( victim );
		if ( InternalState.BiledTanks.len() == 0 )
			InternalState.BileHurtTankThink = false;
	}
}

function OnGameEvent_triggered_car_alarm( params )
{
	if ( InternalState.Tanks.len() < SessionOptions.cm_TankLimit && (Time() - InternalState.LastAlarmTankTime >= SessionState.SpawnInterval
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