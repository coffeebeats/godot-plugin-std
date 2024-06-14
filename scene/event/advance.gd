##
## std/scene/event/advance.gd
##
## Advance is a 'Scene' event which requests a transition to the next state.
##
## NOTE: This event does not allow specifying a custom target 'Scene.State'. Instead it
## relies on the current state to define its target. To allow an input event to specify
## a custom target, see 'std/scene/event/transition.gd'.
##

extends "../event.gd"
