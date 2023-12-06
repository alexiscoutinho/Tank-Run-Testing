function OnGameEvent_round_start_post_nav( params )
{
	for ( local trigger; trigger = Entities.FindByClassname( trigger, "trigger_playermovement" ); )
	{
		if ( trigger.GetModelName() == "*285" )
		{
			NetProps.SetPropInt( trigger, "m_spawnflags", 0 ); // since just Kill won't exclude it from the tankrun trigger search in time
			trigger.Kill();
			break;
		}
	}
}