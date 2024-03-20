function OnGameEvent_round_start_post_nav( params )
{
	local startPos = Vector( -1362.5, -9462.5, 616.5 ), startArea, endPos, endArea;
	for ( local i = 0; i < 8; i++ )
	{
		if ( i == 0 )
			endPos = Vector( -1362.5, -9587.5, 128.5 );
		else if ( i == 2 )
			endPos = Vector( -1312.5, -9662.5, 218.5 );

		startArea = NavMesh.GetNavArea( startPos, 1.0 );
		endArea = NavMesh.GetNavArea( endPos, 1.0 );
		startArea.ConnectTo( endArea, 0 );
		startPos.x += 25;
		endPos.x += 25;
	}
}

function OnGameEvent_round_start( params )
{
	foreach ( name in [ "event_elevator", "trigger_elevator", "event_elevator_deny", "event_elevator_success", "relay_elevator_down" ] )
		Entities.FindByName( null, name ).Kill(); // because relay_elevator_down is respawned below

	EntFire( "button_callelevator", "AddOutput", "speed 100" ); // to mitigate the delay from missing "Don't move" flag
	local ent = Entities.FindByName( null, "button_callelevator" );
	EntityOutputs.RemoveOutput( ent, "OnPressed", "", "", "" );
	EntityOutputs.AddOutput( ent, "OnPressed", "!activator", "SpeakResponseConcept", "c4m2_elevator_top_button", 0.0, 1 );
	// because of https://github.com/Tsuey/L4D2-Community-Update/issues/487
	EntityOutputs.AddOutput( ent, "OnIn", "!self", "RunScriptCode", "EntFire(\"relay_elevator_*\", \"Trigger\", null, 0, self)", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnUser1", "prop_elevator_callbutton_top", "SetAnimation", "TURN_ON", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnUser1", "button_inelevator", "PressIn", "", 0.1, -1 );
	EntityOutputs.AddOutput( ent, "OnUser1", "prop_elevator_callbutton_top", "SetAnimation", "idleon", 0.2, -1 );

	EntFire( "button_inelevator", "Unlock" );
	ent = Entities.FindByName( null, "button_inelevator" );
	EntityOutputs.RemoveOutput( ent, "OnUseLocked", "", "", "" );
	EntityOutputs.RemoveOutput( ent, "OnPressed", "", "", "" );
	EntityOutputs.AddOutput( ent, "OnIn", "!self", "RunScriptCode", "EntFire(\"relay_elevator_*\", \"Trigger\", null, 0, self)", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnUser1", "prop_elevator_button", "SetAnimation", "TURN_ON", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnUser1", "button_callelevator", "PressIn", "", 0.1, -1 );
	EntityOutputs.AddOutput( ent, "OnUser1", "prop_elevator_button", "SetAnimation", "idleon", 0.2, -1 );

	SpawnEntityFromTable( "logic_relay", {
		targetname = "relay_elevator_first"
		spawnflags = 1
		connections =
		{
			OnTrigger =
			{
				cmd1 = "!activatorFireUser101"
				cmd2 = "elevatorMoveToFloortop0.11"
				cmd3 = "shake_elevator_startStartShake0.11"
				cmd4 = "sound_elevator_startupPlaySound0.11"
				cmd5 = "sound_elevator_movePlaySound0.11"
				cmd6 = "relay_elevator_upEnable11"
			}
		}
	} );
	SpawnEntityFromTable( "logic_relay", {
		targetname = "relay_elevator_down"
		StartDisabled = true
		connections =
		{
			OnTrigger =
			{
				cmd1 = "!activatorFireUser10-1"
				cmd2 = "push_elevatorEnable0.1-1"
				cmd3 = "prop_elevator_gate_topSetAnimationclose0.1-1"
				cmd4 = "sound_elevator_door_top_closePlaySound0.1-1"
				cmd5 = "brush_elevator_door_topEnable0.6-1"
				cmd6 = "push_elevatorDisable0.61-1"
				cmd7 = "navblock_elevator_door_topBlockNav2.1-1"
				cmd8 = "elevatorMoveToFloorbottom2.1-1"
				cmd9 = "shake_elevator_startStartShake2.1-1"
				cmd10 = "sound_elevator_startupPlaySound2.1-1"
				cmd11 = "sound_elevator_movePlaySound2.1-1"
			}
		}
	} );
	SpawnEntityFromTable( "logic_relay", {
		targetname = "relay_elevator_up"
		StartDisabled = true
		connections =
		{
			OnTrigger =
			{
				cmd1 = "!activatorFireUser10-1"
				cmd2 = "prop_elevator_gate_bottomSetAnimationclose0.1-1"
				cmd3 = "sound_elevator_door_bot_closePlaySound0.1-1"
				cmd4 = "brush_elevator_door_bottomEnable0.6-1"
				cmd5 = "navblock_elevator_door_bottomBlockNav2.1-1"
				cmd6 = "elevatorMoveToFloortop2.1-1"
				cmd7 = "shake_elevator_startStartShake2.1-1"
				cmd8 = "sound_elevator_startupPlaySound2.1-1"
				cmd9 = "sound_elevator_movePlaySound2.1-1"
			}
		}
	} );

	ent = Entities.FindByName( null, "elevator" );
	EntityOutputs.RemoveOutput( ent, "OnReachedTop", "orator", "", "" );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "orator", "SpeakResponseConcept", "c4m2_elevator_arrived", 0.0, 1 );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "relay_elevator_*", "Toggle", "", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "prop_elevator_callbutton_top", "SetAnimation", "idleoff", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "prop_elevator_button", "SetAnimation", "idleoff", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "navblock_elevator_door_top", "UnblockNav", "", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "button_inelevator", "PressOut", "", 2.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedBottom", "relay_elevator_*", "Toggle", "", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedBottom", "navblock_elevator_door_bottom", "UnblockNav", "", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedBottom", "button_callelevator", "PressOut", "", 2.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedBottom", "button_inelevator", "PressOut", "", 2.0, -1 );

	SpawnEntityFromTable( "script_nav_blocker", {
		teamToBlock = -1
		targetname = "navblock_elevator_door_top"
		origin = "-1475 -9550 621"
		extent = "50 50 4"
	} );
	SpawnEntityFromTable( "script_nav_blocker", {
		teamToBlock = -1
		targetname = "navblock_elevator_door_bottom"
		origin = "-1475 -9550 141.5"
		extent = "50 50 4"
	} );
	EntFire( "navblock_elevator_door_top", "BlockNav" );
	EntFire( "navblock_elevator_door_bottom", "BlockNav" );

	EntFire( "brush_elevator_clip_top", "AddOutput", "targetname brush_elevator_door_top" );

	SpawnEntityFromTable( "env_player_blocker", {
		origin = "-1417 -9543.5 185.5"
		targetname = "brush_elevator_door_bottom"
		mins = "-3 -56.5 -70.5"
		maxs = "3 56.5 70.5"
		initialstate = 1
		BlockType = 1
	} );
}