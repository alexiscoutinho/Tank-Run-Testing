MapState <-
{
	HoldoutSpawnInterval = 30
	MinTankMusicDuration = 15
	MinTankStageDuration = 5
}

local InternalState =
{
	StageDurations = [ -1, -1, 10, 170, 15, -1, 15, 85, 85/*, 5*/ ]
	TankStageStartTime = 0
}

local function EndTankStageThink()
{
	if ( SessionOptions.ScriptedStageType == STAGE_ESCAPE )
		return;

	local num = 9 - InternalState.StageDurations.len();
	local countdownTime = HUDReadTimer( 0 );
	local elapsedTime = InternalState.TankStageStartTime - countdownTime; // also considered the 2nd Tank stage duration

	if ( countdownTime - (num == 4 ? 195 + elapsedTime : 0) - SessionOptions.A_CustomFinaleValue9 <= 0 )
	{
		EntFire( "tank" + num / 4 + "_music", "StopSound" );
		Director.ForceNextStage();
	}
	else
		EntFire( "worldspawn", "CallScriptFunction", "EndTankStageThink", 1.0 );
}

local function CheckTankStageDuration( num )//try to predict available time based on trend
{
	local countdownTime = HUDReadTimer( 0 );

	if ( countdownTime - 8 / num * SessionState.MinTankMusicDuration - (num == 4 ? 195 : 0) - SessionOptions.A_CustomFinaleValue9 >= 0 )
	{
		InternalState.TankStageStartTime = countdownTime;
		EntFire( "worldspawn", "CallScriptFunction", "EndTankStageThink", SessionState.MinTankMusicDuration );
	}
	else
	{
		EntFire( "tank" + num / 4 + "_music", "Kill" );
		EntFire( "trigger_finale", "AdvanceFinaleState", "", SessionState.MinTankStageDuration );
	}
}

ChallengeScript.rawdelete( "GetNextStage" );
function GetNextStage()
{
	if ( SessionState.HoldoutEnded )
	{
		SessionOptions.ScriptedStageType = STAGE_ESCAPE;//should i force fireworks and stop music, or maybe queue them?
	}
	else if ( SessionState.FinaleStarted )
	{
		SessionOptions.ScriptedStageType = STAGE_DELAY;
		SessionOptions.ScriptedStageValue = InternalState.StageDurations.pop();

		if ( SessionOptions.ScriptedStageValue == -1 && InternalState.StageDurations.len() )
			CheckTankStageDuration( 9 - InternalState.StageDurations.len() );
	}
}

function OnGameEvent_round_start( params )
{
	foreach ( name in [ "tank_music_double", "tank_music_finale" ] )
		EntFire( name, "Kill" );

	foreach ( name in [ "tank1_music", "tank2_music" ] )
	{
		for ( local i = 0, music; i < 2; i++ )
		{
			music = Entities.FindByName( music, name );
			SpawnEntityFromTable( "ambient_generic", {
				targetname = name
				spawnflags = 17
				message = NetProps.GetPropString( music, "m_iszSound" )
			} );
			music.Kill();
		}
	}

	EntFire( "stage_sound_startup_relay", "AddOutput", "OnTrigger tank_music_single:StopSound::0:1" );
	Entities.First().GetScriptScope().EndTankStageThink <- EndTankStageThink.bindenv( this );
}