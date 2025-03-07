//-----------------------------------------------------------------------------

PANIC <- 0
TANK <- 1
DELAY <- 2
ONSLAUGHT <- 3

//-----------------------------------------------------------------------------

SharedOptions <-
{
	A_CustomFinale_StageCount = 9

 	A_CustomFinale1 = PANIC
	A_CustomFinaleValue1 = 1

 	A_CustomFinale2 = PANIC
	A_CustomFinaleValue2 = 1

	A_CustomFinale3 = DELAY
	A_CustomFinaleValue3 = 15

	A_CustomFinale4 = TANK
	A_CustomFinaleValue4 = 1
	A_CustomFinaleMusic4 = ""

	A_CustomFinale5 = DELAY
	A_CustomFinaleValue5 = 15

	A_CustomFinale6 = PANIC
	A_CustomFinaleValue6 = 2

	A_CustomFinale7 = DELAY
	A_CustomFinaleValue7 = 10

	A_CustomFinale8 = TANK
	A_CustomFinaleValue8 = 1
	A_CustomFinaleMusic8 = ""

	A_CustomFinale9 = DELAY
	A_CustomFinaleValue9 = RandomInt( 5, 10 )

	PreferredMobDirection = SPAWN_LARGE_VOLUME
	PreferredSpecialDirection = SPAWN_LARGE_VOLUME
	ShouldConstrainLargeVolumeSpawn = false

	ZombieSpawnRange = 3000

	SpecialRespawnInterval = 20
}

InitialPanicOptions <-
{
	ShouldConstrainLargeVolumeSpawn = true
}

PanicOptions <-
{
	CommonLimit = 25
}

TankOptions <-
{
	ShouldAllowSpecialsWithTank = true
	SpecialRespawnInterval = 30
}


DirectorOptions <- clone SharedOptions

//-----------------------------------------------------------------------------

function OnBeginCustomFinaleStage( num, type )
{
	if ( developer() > 0 )
	{
		printl("========================================================")
		printl( "Beginning custom finale stage " + num + " of type " + type )
	}

	local waveOptions
	if ( num == 1 )
	{
		waveOptions = InitialPanicOptions
	}
	else if ( type == PANIC )
	{
		waveOptions = PanicOptions
		if ( "MegaMobMinSize" in PanicOptions )
		{
			waveOptions.MegaMobSize <- RandomInt( PanicOptions.MegaMobMinSize, PanicOptions.MegaMobMaxSize )
		}
	}
	else if ( type == TANK )
	{
		waveOptions = TankOptions
	}

	//---------------------------------

	DirectorOptions = clone SharedOptions

	if ( waveOptions != null )
	{
		foreach ( key, val in waveOptions )
		{
			DirectorOptions[key] <- val
		}
	}

	//---------------------------------

	if ( developer() > 0 )
	{
		Msg( "\n*****\nMapScript.DirectorOptions:\n" )
		foreach ( key, value in MapScript.DirectorOptions )
		{
			Msg( "    " + key + " = " + value + "\n" )
		}

		if ( LocalScript.rawin( "DirectorOptions" ) )
		{
			Msg( "\n*****\nLocalScript.DirectorOptions:\n" )
			foreach ( key, value in LocalScript.DirectorOptions )
			{
				Msg( "    " + key + " = " + value + "\n" )
			}
		}
		printl("========================================================")
	}

	//---------------------------------

	switch ( num )
	{
		case 4:
			EntFire( "arch_beams_relay", "Trigger" )
			EntFire( "side_beams_relay", "Trigger" )
			EntFire( "stage_lights_dim_relay", "Trigger" )
			EntFire( "tank1_music", "PlaySound" )
			break

		case 5:
			EntFire( "arch_beams_stop_relay", "Trigger", "", 3.0 )
			EntFire( "side_beams_off_relay", "Trigger", "", 3.0 )
			break

		case 6:
			EntFire( "stage_lastsong_relay", "Trigger" )
			break

		case 7:
			EntFire( "mic_spotlights_relay", "Trigger" )
			EntFire( "stage_lights_dim_relay", "Trigger" )
			break

		case 8:
			EntFire( "fireworks_relay", "Trigger" )
			EntFire( "tank2_music", "PlaySound" )
	}
}
