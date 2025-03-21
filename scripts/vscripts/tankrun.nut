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

	BileMobSize = 0
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
	HoldoutEnded = false
	RescueDelay = 360
	FirstSpawnDelay = 0
	SpawnInterval = 20
	HoldoutSpawnInterval = 40
	DoubleTanks = false
	TanksDisabled = false
	TankHealth = 4000
	DifficultyHealths = [ 2000, 3000, 4000, 5000 ]
	DeployChance = 75
	SafeRoomAbandonDelay = 10
}

local InternalState =
{
	LastTankTime = 0
	LastSpawnTime = 0
	LastAlarmTankTime = 0
	SafeRoomCloseTime = 0
	PlayingMetal = false
	Tanks = {}
	BiledTanks = {}
	FinaleType = -1
	HoldoutFinale = false
	LeftSafeAreaThink = false
	SpawnTankThink = false
	BileHurtTankThink = false
	SafeRoomAbandonThink = false
	FinaleAreaThink = false
	EndHoldoutThink = false
}

MutationOptions.ShouldPlayBossMusic <- @( idx ) !InternalState.PlayingMetal; // necessary to prevent music conflicts with double tanks

local function ReleaseTriggerMultiples()//or Activate/StartTankSpawning? depends if u lock them
{
	for ( local trigger; trigger = Entities.FindByClassname( trigger, "trigger_multiple" ); )
	{
		if ( NetProps.GetPropInt( trigger, "m_bAllowIncapTouch" ) == 1 && NetProps.GetPropInt( trigger, "m_iEntireTeam" ) == 2 )//should I go overkill with == to <>= transform? probably being creative would be enough
			NetProps.SetPropInt( trigger, "m_bAllowIncapTouch", 0 );
	}
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

local function SpawnTankThink()
{
	if ( SessionState.TanksDisabled )
		return;

	if ( (InternalState.Tanks.len() < SessionOptions.cm_TankLimit || SessionOptions.cm_TankLimit == -1)
		&& (Time() - InternalState.LastSpawnTime >= SessionState.SpawnInterval || InternalState.LastSpawnTime == 0) )
	{
		if ( ZSpawn( { type = 8 } ) )//lock safe room door when players are still loading
		{
			if ( SessionState.DoubleTanks )
				ZSpawn( { type = 8 } );
			InternalState.LastSpawnTime = Time();
		}
	}
}

local function BileHurtTankThink()
{
	foreach ( tank, survivor in InternalState.BiledTanks )
		tank.TakeDamage( 100, 0, survivor );
}

local SafeRoomAbandonThink, FinaleAreaThink, EndHoldoutThink;

local function TankRunThink()
{
	if ( InternalState.LeftSafeAreaThink )
		LeftSafeAreaThink();
	if ( InternalState.SpawnTankThink )
		SpawnTankThink();
	if ( InternalState.BileHurtTankThink )
		BileHurtTankThink();
	if ( InternalState.SafeRoomAbandonThink )
		SafeRoomAbandonThink();
	if ( InternalState.FinaleAreaThink )
		FinaleAreaThink();
	if ( InternalState.EndHoldoutThink )
		EndHoldoutThink();

	EntFire( "worldspawn", "CallScriptFunction", "TankRunThink", 1.0 );
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
						damageTable.Victim.OverrideFriction( 0.9, 3.0 );
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
local hasChangelevel, CheckAbandonCondition, ResetAbandonSystem;

weaponsToConvert <-
{
	weapon_upgradepack_explosive = "upgrade_ammo_explosive" #L4D being L4D...
	weapon_upgradepack_incendiary = "upgrade_ammo_incendiary"
	weapon_upgradepack_explosive_spawn = "upgrade_ammo_explosive"
	weapon_upgradepack_incendiary_spawn = "upgrade_ammo_incendiary"
}

function OnGameEvent_round_start( params )
{
	SessionState.TankHealth = SessionState.DifficultyHealths[ GetDifficulty() ];

	SpawnEntityFromTable( "ambient_music", {
		targetname = "tank_music_single"
		message = "Event.Tank"
	} );
	SpawnEntityFromTable( "ambient_music", {
		targetname = "tank_music_double"
		message = "Event.TankMidpoint_Metal"
	} );
	if ( hasFinale )
	{
		SpawnEntityFromTable( "ambient_music", {
			targetname = "tank_music_finale"
			message = "Event.TankMidpoint"
		} );
	}

	for ( local spawner, population; spawner = Entities.FindByClassname( spawner, "info_zombie_spawn" ); )
	{
		population = NetProps.GetPropString( spawner, "m_szPopulation" );
		if ( population != "tank" && population != "river_docks_trap" )
			spawner.Kill();
	}

	for ( local ammo; ammo = Entities.FindByModel( ammo, "models/props/terror/ammo_stack.mdl" ); ) // c2m5, c3m4 & c14m2 ammo glow entities
		ammo.Kill();

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

	if ( hasChangelevel )
	{
		for ( local door, scope; door = Entities.FindByClassname( door, "prop_door_rotating_checkpoint" ); )
		{
			if ( GetFlowPercentForPosition( door.GetCenter(), false ) > 50 ) // must use conservative flow cutoff for multi-ending maps
			{
				door.ValidateScriptScope();
				scope = door.GetScriptScope();
				scope.CheckAbandonCondition <- CheckAbandonCondition.bindenv( this ); // a bit inefficient in multi-ending maps
				scope.ResetAbandonSystem <- ResetAbandonSystem.bindenv( this );
				door.ConnectOutput( "OnFullyClosed", "CheckAbandonCondition" );
				door.ConnectOutput( "OnOpen", "ResetAbandonSystem" );
			}
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
	if ( "toggledAreas" in getroottable() )
	{
		foreach ( area in toggledAreas )
			area.RemoveSpawnAttributes( FINALE );
		toggledOff = true;
	}
	if ( FinaleAreaThink )
		InternalState.FinaleAreaThink = true;

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

	if ( !InternalState.PlayingMetal )
	{
		if ( Time() - InternalState.LastTankTime == 0 )
		{
			EntFire( "tank_music_single", "StopSound" );
			EntFire( "tank_music_double", "PlaySound" );
			InternalState.PlayingMetal = true;
		}
		else if ( InternalState.FinaleType >= 0 )
		{
			EntFire( "tank_music_single", "StopSound" );//can still cut off music
			EntFire( "tank_music_finale", "PlaySound" );
		}
	}
	InternalState.LastTankTime = Time();

	if ( InternalState.HoldoutFinale && InternalState.Tanks.len() == 3 )
		SessionState.SpawnInterval = SessionState.HoldoutSpawnInterval;
}

function OnGameEvent_player_death( params ) // because of https://github.com/Tsuey/L4D2-Community-Update/issues/37
{
	local player = GetPlayerFromUserID( params["userid"] );

	if ( player.GetZombieType() == ZOMBIE_TANK )
	{
		InternalState.Tanks.rawdelete( player );
		if ( InternalState.Tanks.len() == 0 )
		{
			EntFire( "tank_music_*", "StopSound" );
			InternalState.PlayingMetal = false;
		}

		InternalState.BiledTanks.rawdelete( player );
		if ( InternalState.BiledTanks.len() == 0 )
			InternalState.BileHurtTankThink = false;

		if ( InternalState.HoldoutFinale )
		{
			if ( InternalState.Tanks.len() == 2 )
				SessionState.SpawnInterval = SessionState.HoldoutSpawnInterval - 10;

			if ( !SessionState.HoldoutEnded )
			{
				local attacker = GetPlayerFromUserID( params["attacker"] );//assuming existence
				if ( NetProps.GetPropInt( attacker, "m_iTeamNum" ) == 2 )
					DecreaseHUDTimerBy( 10 );
			}
		}
	}
}

function OnGameEvent_player_disconnect( params )
{
	local player = GetPlayerFromUserID( params["userid"] );
	if ( !player )
		return;

	if ( player.GetZombieType() == ZOMBIE_TANK )
	{
		InternalState.Tanks.rawdelete( player );
		if ( InternalState.Tanks.len() == 0 )
		{
			EntFire( "tank_music_*", "StopSound" );
			InternalState.PlayingMetal = false;
		}

		InternalState.BiledTanks.rawdelete( player );
		if ( InternalState.BiledTanks.len() == 0 )
			InternalState.BileHurtTankThink = false;

		if ( InternalState.HoldoutFinale && InternalState.Tanks.len() == 2 )
			SessionState.SpawnInterval = SessionState.HoldoutSpawnInterval - 10;
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
		victim.SetFriction( 2.3 );
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
		victim.SetFriction( 1.0 );
		InternalState.BiledTanks.rawdelete( victim );
		if ( InternalState.BiledTanks.len() == 0 )
			InternalState.BileHurtTankThink = false;
	}
}

function OnGameEvent_triggered_car_alarm( params )
{
	if ( (InternalState.Tanks.len() < SessionOptions.cm_TankLimit || SessionOptions.cm_TankLimit == -1)
		&& (Time() - InternalState.LastAlarmTankTime >= SessionState.SpawnInterval || InternalState.LastAlarmTankTime == 0) )
	{
		if ( ZSpawn( { type = 8 } ) )
			InternalState.LastAlarmTankTime = Time();
	}
}

function OnGameEvent_mission_lost( params )
{
	InternalState.SpawnTankThink = false;
}
//remove local var declarations inside all loops?
if ( Director.IsFirstMapInScenario() ) // do multi-start maps exist though?
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

		foreach ( name in [ "weapon_pistol_spawn", "weapon_pistol_magnum_spawn", "weapon_spawn", "weapon_melee_spawn" ] )
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

		foreach ( w in [ "any_smg", "tier1_shotgun" ] )
			SpawnEntityFromTable( "weapon_spawn", {
				spawn_without_director = 1
				weapon_selection = w
				count = 5
				spawnflags = 3
				origin = startArea.FindRandomSpot() + Vector( 0, 0, 50 )
				angles = Vector( RandomInt( 0, 90 ), RandomInt( 0, 90 ), 90 )
			} );
	}
}

if ( !g_SecondRun )
	return;

hasChangelevel = Entities.FindByClassname( null, "info_changelevel" ) || Entities.FindByClassname( null, "trigger_changelevel" );
if ( hasChangelevel )
{
	const CHECKPOINT = 2048;
	local survivor_incap_decay_rate;

	SafeRoomAbandonThink = function ()
	{
		if ( Time() - InternalState.SafeRoomCloseTime >= SessionState.SafeRoomAbandonDelay )
		{
			for ( local player; player = Entities.FindByClassname( player, "player" ); )
			{
				if ( NetProps.GetPropInt( player, "m_iTeamNum" ) != 2 || NetProps.GetPropInt( player, "m_lifeState" ) != 0 )
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

			survivor_incap_decay_rate = Convars.GetFloat( "survivor_incap_decay_rate" );
			Convars.SetValue( "survivor_incap_decay_rate", Convars.GetFloat( "survivor_incap_hopeless_decay_rate" ) );
			InternalState.SafeRoomAbandonThink = false;

			function OnShutdown()
			{
				Convars.SetValue( "survivor_incap_decay_rate", survivor_incap_decay_rate );
			}
		}
	}

	CheckAbandonCondition = function ()
	{
		for ( local player; player = Entities.FindByClassname( player, "player" ); )
		{
			if ( NetProps.GetPropInt( player, "m_iTeamNum" ) != 2 || NetProps.GetPropInt( player, "m_lifeState" ) != 0 )
				continue;

			if ( GetCurrentFlowPercentForPlayer( player ) > 50 && player.GetLastKnownArea().HasSpawnAttributes( CHECKPOINT ) )//what about those null cases?//u should instead test if the standing players are in the closed saferoom, not any random open end saferoom
			{
				InternalState.SafeRoomCloseTime = Time();
				InternalState.SafeRoomAbandonThink = true;
				break;
			}
		}
	}

	ResetAbandonSystem = function ()
	{
		InternalState.SafeRoomAbandonThink = false;
	}
}

const FINALE = 64;

if ( !("hasFinale" in getroottable()) )
{
	::hasFinale <- false;

	if ( Entities.FindByClassname( null, "trigger_finale" ) )
		hasFinale = true;
	else
	{
		local allAreas = {};
		NavMesh.GetAllAreas( allAreas );

		foreach ( area in allAreas )
		{
			if ( area.HasSpawnAttributes( FINALE ) )
			{
				hasFinale = true;
				break;
			}
		}
	}
}

if ( hasFinale )
{
	local triggerFinales = [], finaleTypes = {};
	for ( local triggerFinale; triggerFinale = Entities.FindByClassname( triggerFinale, "trigger_finale" ); )
	{
		triggerFinales.append( triggerFinale );
		finaleTypes[ NetProps.GetPropInt( triggerFinale, "m_type" ) ] <- true;
	}

	local hasHoldout = 0 in finaleTypes || 2 in finaleTypes;
	local compatMode = !triggerFinales.len();

	if ( compatMode )
		printl("Running in finale compatibility mode");

	if ( hasHoldout || compatMode ) // official tankrun.nut won't include compatMode
	{
		if ( triggerFinales.len() == 1 )
		{
			FinaleAreaThink = function ()
			{
				for ( local player; player = Entities.FindByClassname( player, "player" ); )
				{
					if ( NetProps.GetPropInt( player, "m_iTeamNum" ) != 2 )
						continue;

					if ( player.GetLastKnownArea() in finaleAreas )
					{
						SessionState.SpawnInterval = (SessionState.SpawnInterval + SessionState.HoldoutSpawnInterval) / 2.0;
						InternalState.FinaleAreaThink = false;
						return;
					}
				}
			}
		}

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
	}

	function GetNextStage()
	{
		if ( SessionState.HoldoutEnded ) // unnecessary for gauntlet and scavenge finales?
		{
			SessionOptions.ScriptedStageType = STAGE_ESCAPE;#would it be nice to have an ESCAPE stage for every finale type? for compat maybe?
		}
		else if ( Director.IsFinale() )
		{
			SessionOptions.ScriptedStageType = STAGE_DELAY;
			SessionOptions.ScriptedStageValue = -1;
		}
	}

	if ( "toggledOff" in getroottable() && toggledOff )
	{
		foreach ( area in toggledAreas )
			area.SetSpawnAttributes( area.GetSpawnAttributes() | FINALE ); // to prevent flow errors
		toggledOff = false;
	}

	function OnGameEvent_round_start_post_nav( params )
	{
		if ( !("toggledAreas" in getroottable()) )
		{
			local allAreas = {}, finaleAreas = {};
			NavMesh.GetAllAreas( allAreas );

			if ( SessionState.CheckSurvivorsInFinaleArea || hasHoldout )
			{
				foreach ( area in allAreas )
				{
					if ( area.HasSpawnAttributes( FINALE ) )
						finaleAreas.rawset( area, area );
				}
				if ( hasHoldout || compatMode )
					::finaleAreas <- finaleAreas;
			}
			::toggledAreas <- SessionState.CheckSurvivorsInFinaleArea ? finaleAreas : allAreas;
			::toggledOff <- null;
		}
	}

	local hasSacrifice = false;
	foreach ( triggerFinale in triggerFinales )
	{
		if ( NetProps.GetPropInt( triggerFinale, "m_bIsSacrificeFinale" ) )
		{
			hasSacrifice = true;
			break;
		}
	}
	if ( hasSacrifice || compatMode )#is this acceptable? does the hook break stuff in non sacrifice? in fact it should be encouraged
	{
		function OnGameEvent_generator_started( params )
		{
			if ( !Director.IsFinale() )
				return;

			if ( !SessionState.HoldoutEnded ) // shouldn't the generators be disabled instead?
				DecreaseHUDTimerBy( 30 );

			if ( InternalState.Tanks.len() < SessionOptions.cm_TankLimit || SessionOptions.cm_TankLimit == -1 )
				ZSpawn( { type = 8 } );
		}
	}

	local function InputUse()
	{
		if ( SessionState.CheckSurvivorsInFinaleArea )
		{
			for ( local player; player = Entities.FindByClassname( player, "player" ); )
			{
				if ( NetProps.GetPropInt( player, "m_iTeamNum" ) != 2 || NetProps.GetPropInt( player, "m_lifeState" ) != 0 )
					continue;

				if ( !player.IsIncapacitated() && !player.IsHangingFromLedge() && !(player.GetLastKnownArea() in toggledAreas) )
					return true;
			}
		}

		InternalState.FinaleType = NetProps.GetPropInt( self, "m_type" );
		InternalState.HoldoutFinale = InternalState.FinaleType == 0 || InternalState.FinaleType == 2;

		if ( toggledOff )
		{
			foreach ( area in toggledAreas )
				area.SetSpawnAttributes( area.GetSpawnAttributes() | FINALE );
			toggledOff = false;
		}
		return true;
	}

	local function InputForceFinaleStart()
	{
		InternalState.FinaleType = NetProps.GetPropInt( self, "m_type" );
		InternalState.HoldoutFinale = InternalState.FinaleType == 0 || InternalState.FinaleType == 2;

		if ( toggledOff )
		{
			foreach ( area in toggledAreas )
				area.SetSpawnAttributes( area.GetSpawnAttributes() | FINALE );
			toggledOff = false;
		}

		// because of https://github.com/Tsuey/L4D2-Community-Update/issues/462
		for ( local player, area; player = Entities.FindByClassname( player, "player" ); )
		{
			if ( NetProps.GetPropInt( player, "m_iTeamNum" ) != 2 || NetProps.GetPropInt( player, "m_lifeState" ) != 0 )
				continue;

			if ( (area = player.GetLastKnownArea()) && !area.HasSpawnAttributes( FINALE ) )//null area case may be hopeless
			{
				area.SetSpawnAttributes( area.GetSpawnAttributes() | FINALE );
				EntFire( "worldspawn", "RunScriptCode", "NavMesh.GetNavAreaByID(" + area.GetID() + ").RemoveSpawnAttributes( FINALE )" );
			}
		}
		return true;
	}

	local function PatchTriggerFinale( triggerFinale )
	{
		triggerFinale.ValidateScriptScope();
		local scope = triggerFinale.GetScriptScope();
		// poor compatibility though//assuming first-to serve?
		scope.InputUse <- InputUse;
		scope.InputForceFinaleStart <- InputForceFinaleStart;
	}

	if ( compatMode )
	{
		local function PostSpawn( entities )
		{
			foreach ( ent in entities )
			{
				if ( ent.GetClassname() == "trigger_finale" )
					PatchTriggerFinale( ent );
			}
		}

		for ( local template; template = Entities.FindByClassname( template, "point_template" ); )
		{
			template.ValidateScriptScope();
			template.GetScriptScope().PostSpawn <- PostSpawn; // poor compatibility
		}
	}
	else
	{
		foreach ( triggerFinale in triggerFinales )
			PatchTriggerFinale( triggerFinale );
	}

	if ( !(1 in finaleTypes) )
	{
		function OnGameEvent_finale_start( params )
		{
			if ( SessionState.FirstSpawnDelay == -1 )
			{
				InternalState.SpawnTankThink = true;
				ReleaseTriggerMultiples();
			}
			delete SessionOptions.ShouldPlayBossMusic;
			Director.ForceNextStage(); // to prevent the HALFTIME_BOSS and FINAL_BOSS stages and skip stage 0

			if ( InternalState.FinaleType == 4 )
			{
				EntFire( "info_director", "EndScript" ); // would benefit from https://github.com/Tsuey/L4D2-Community-Update/issues/545
				return;
			}

			HUDManageTimers( 0, TIMER_COUNTDOWN, SessionState.RescueDelay );
			TankRunHUD.Fields.rescue_time.flags = TankRunHUD.Fields.rescue_time.flags & ~HUD_FLAG_NOTVISIBLE;

			SessionState.DoubleTanks = true;
			SessionState.SpawnInterval = SessionState.HoldoutSpawnInterval - (InternalState.Tanks.len() <= 2 ? 10 : 0);
			InternalState.EndHoldoutThink = true;
		}
	}
	if ( 1 in finaleTypes || compatMode )
	{
		function OnGameEvent_gauntlet_finale_start( params )
		{
			if ( SessionState.FirstSpawnDelay == -1 )
			{
				InternalState.SpawnTankThink = true;
				ReleaseTriggerMultiples();
			}
			delete SessionOptions.ShouldPlayBossMusic;
			Director.ForceNextStage(); // to prevent the GAUNTLET_BOSS stage
		}
	}

	function OnGameEvent_finale_vehicle_leaving( params )
	{
		InternalState.SpawnTankThink = false;
	}
}