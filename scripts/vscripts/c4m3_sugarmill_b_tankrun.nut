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
	foreach ( name in [
		"trigger_elevator", "event_elevator_deny", "event_elevator_success", "relay_elevator_up", "ptemplate_falltrigger"
	] )//is it bad to remove point_template? cus hurt_fall would be hanging.
		Entities.FindByName( null, name ).Kill(); // because relay_elevator_up is respawned below

	EntFire( "button_inelevator", "Unlock" );
	local ent = Entities.FindByName( null, "button_inelevator" );
	EntityOutputs.RemoveOutput( ent, "OnUseLocked", "", "", "" );
	EntityOutputs.RemoveOutput( ent, "OnPressed", "", "", "" );
	// because of https://github.com/Tsuey/L4D2-Community-Update/issues/487
	EntityOutputs.AddOutput( ent, "OnIn", "!self", "RunScriptCode", "EntFire(\"relay_elevator_*\", \"Trigger\", null, 0, self)", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnUser1", "prop_elevator_button", "SetAnimation", "TURN_ON", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnUser1", "button_callelevator_*", "PressIn", "", 0.1, -1 );
	EntityOutputs.AddOutput( ent, "OnUser1", "prop_elevator_button", "SetAnimation", "idleon", 0.2, -1 );

	SpawnEntityFromTable( "logic_relay", {
		targetname = "relay_elevator_up"
		connections =
		{
			OnTrigger =
			{
				cmd1 = "!activatorFireUser10-1"
				cmd2 = "push_elevatorEnable0.1-1"
				cmd3 = "prop_elevator_gate_bottomSetAnimationclose0.1-1"
				cmd4 = "sound_elevator_door_bot_closePlaySound0.1-1"
				cmd5 = "brush_elevator_door_bottomEnable0.6-1"
				cmd6 = "push_elevatorDisable0.61-1"
				cmd7 = "navblock_elevator_door_bottomBlockNav2.1-1"
				cmd8 = "elevatorMoveToFloortop2.1-1"
				cmd9 = "shake_elevator_startStartShake2.1-1"
				cmd10 = "sound_elevator_startupPlaySound2.1-1"
				cmd11 = "sound_elevator_movePlaySound2.1-1"
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
				cmd2 = "prop_elevator_gate_topSetAnimationclose0.1-1"
				cmd3 = "sound_elevator_door_top_closePlaySound0.1-1"
				cmd4 = "brush_elevator_door_topEnable0.6-1"
				cmd5 = "navblock_elevator_door_topBlockNav2.1-1"
				cmd6 = "elevatorMoveToFloorbottom2.1-1"
				cmd7 = "shake_elevator_startStartShake2.1-1"
				cmd8 = "sound_elevator_startupPlaySound2.1-1"
				cmd9 = "sound_elevator_movePlaySound2.1-1"
			}
		}
	} );

	EntFire( "brush_elevator_clip_bottom", "AddOutput", "targetname brush_elevator_door_bottom" );

	SpawnEntityFromTable( "script_nav_blocker", {
		teamToBlock = -1
		targetname = "navblock_elevator_door_bottom"
		origin = "-1475 -9550 141.5"
		extent = "50 50 4"
	} );
	SpawnEntityFromTable( "script_nav_blocker", {
		teamToBlock = -1
		targetname = "navblock_elevator_door_top"
		origin = "-1475 -9550 621"
		extent = "50 50 4"
	} );
	EntFire( "navblock_elevator_door_top", "BlockNav" );

	ent = Entities.FindByName( null, "elevator" );
	EntityOutputs.RemoveOutput( ent, "OnReachedTop", "ptemplate_falltrigger", "", "" );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "relay_elevator_*", "Toggle", "", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "prop_elevator_button", "SetAnimation", "idleoff", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "prop_elevator_callbutton_top", "SetAnimation", "idleoff", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "navblock_elevator_door_top", "UnblockNav", "", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "button_inelevator", "PressOut", "", 2.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedTop", "button_callelevator_down", "PressOut", "", 2.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedBottom", "relay_elevator_*", "Toggle", "", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedBottom", "prop_elevator_callbutton_bottom", "SetAnimation", "idleoff", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedBottom", "navblock_elevator_door_bottom", "UnblockNav", "", 0.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedBottom", "button_inelevator", "PressOut", "", 2.0, -1 );
	EntityOutputs.AddOutput( ent, "OnReachedBottom", "button_callelevator_up", "PressOut", "", 2.0, -1 );

	SpawnEntityFromTable( "env_player_blocker", {
		origin = "-1479.5 -9495 684"
		targetname = "brush_elevator_door_top"
		mins = "-56.5 -3 -76"
		maxs = "56.5 3 76"
		initialstate = 1
		BlockType = 1
	} );

	SpawnEntityFromTable( "prop_dynamic", {
		origin = "-1406.5 -9609 172.5"
		targetname = "prop_elevator_callbutton_bottom"
		model = "models/props_mill/freightelevatorbutton01.mdl"
	} );

	SpawnEntityFromTable( "script_func_button", {
		wait = -1
		targetname = "button_callelevator_down"
		spawnflags = 1025
		origin = "-1401 -9605.5 182"
		glow = "prop_elevator_callbutton_bottom"
		extent = "2.5 4 10"
		connections =
		{
			OnIn =
			{
				cmd1 = "!selfRunScriptCodeEntFire(\"relay_elevator_down\", \"Trigger\", null, 0, self)0-1"
			}
			OnUser1 =
			{
				cmd1 = "prop_elevator_callbutton_bottomSetAnimationTURN_ON0-1"
				cmd2 = "button_inelevatorPressIn0.1-1"
				cmd3 = "prop_elevator_callbutton_bottomSetAnimationidleon0.2-1"
			}
		}
	} );
	EntFire( "button_callelevator_down", "PressIn" );

	SpawnEntityFromTable( "script_func_button", {
		wait = -1
		targetname = "button_callelevator_up"
		spawnflags = 1025
		origin = "-1407.5 -9484 662"
		glow = "prop_elevator_callbutton_top"
		extent = "4 2.5 10"
		connections =
		{
			OnIn =
			{
				cmd1 = "!selfRunScriptCodeEntFire(\"relay_elevator_up\", \"Trigger\", null, 0, self)0-1"
			}
			OnUser1 =
			{
				cmd1 = "prop_elevator_callbutton_topSetAnimationTURN_ON0-1"
				cmd2 = "button_inelevatorPressIn0.1-1"
				cmd3 = "prop_elevator_callbutton_topSetAnimationidleon0.2-1"
			}
		}
	} );
}