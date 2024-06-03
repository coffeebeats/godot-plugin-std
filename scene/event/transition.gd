##
## std/scene/event/transition.gd
##
## Transition is a 'Scene' event which requests a transition to the specified state.
##

extends "../event.gd"

# -- CONFIGURATION ------------------------------------------------------------------- #

## target is the new state's node path, from the state machine root, to which to
## transition.
@export var target: NodePath
