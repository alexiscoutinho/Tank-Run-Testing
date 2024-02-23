function OnGameEvent_round_start_post_nav( params )
{
	local trigger = Entities.FindByModel( null, "*285" );
	NetProps.SetPropInt( trigger, "m_spawnflags", 0 ); // because just Kill won't exclude it from the main tankrun trigger search in time
	trigger.Kill();
}