##
## std/scene/event.gd
##
## Event is a base class for scene-related events supported by the root 'Scene' node.
##

extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## data is user-provided data provided with the state machine event.
@export var data: Resource = null
