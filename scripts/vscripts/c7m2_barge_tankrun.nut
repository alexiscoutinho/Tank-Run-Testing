function OnGameEvent_round_start_post_nav( params )
{
	Entities.FindByModel( null, "*285" ).Kill();
}