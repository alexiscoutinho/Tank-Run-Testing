local NotExist = @( key, query ) !(key in query) || query[key] < 1

local gunshop_rule =
{
	name = "C1M2GunRoomDoorTankRunWhit"
	criteria =
	[
		[ "Concept", "C1M2GunRoomDoor" ],
		[ @( query ) query.whodidit in { Coach=0, Gambler=0, Mechanic=0, Producer=0, Biker=0, NamVet=0, Manager=0, TeenGirl=0 } ],
		[ "name", "orator" ],
		[ "world_auto_Button1", NotExist ],
		[ "worldC1M2FirstOutside", NotExist ]
	]
	applycontext = [ "_auto_Button1", 1 ]
	applycontexttoworld = true
	responses =
	[
		{
			applycontext = [ "Talk", 1, 8 ]
			scenename = "scenes/npcs/Whitaker_ComeUpStairs01.vcd"
			fire = [ "relay_gunshop_door", "Trigger", 6.0 ]
			followup = g_rr.RThen( "producer", "C1M2GunRoomDoorResponseGod", null, 0.01 )
		},
		{
			applycontext = [ "Talk", 1, 8 ]
			scenename = "scenes/npcs/Whitaker_ComeUpStairs02.vcd"
			fire = [ "relay_gunshop_door", "Trigger", 6.0 ]
			followup = g_rr.RThen( "any", "C1M2GunRoomDoorResponseGratitude", null, 0.01 )
		},
		{
			applycontext = [ "Talk", 1, 5 ]
			scenename = "scenes/npcs/Whitaker_ComeUpStairs03.vcd"
			fire = [ "relay_gunshop_door", "Trigger", 3.0 ]
			followup = g_rr.RThen( "producer", "C1M2GunRoomDoorResponseGod", null, 0.01 )
		}
	]
}
g_rr.rr_ProcessRules( gunshop_rule );