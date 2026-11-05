##
## std/input/action_set_layer.gd
##
## StdInputActionSetLayer adds to the mode of play its `parent` defines, keeping every
## binding below it that it doesn't override. UI which takes over input loads a set and
## lists a layer under it for what stays live; overriding a binding doesn't turn an
## action off.
##

@tool
class_name StdInputActionSetLayer
extends StdInputActionSet

# -- CONFIGURATION ------------------------------------------------------------------- #

## parent is the `StdInputActionSet` this layer is enabled over, and the set it sits
## under in the Steam Input manifest. It's required, so a layer several sets enable is
## one file per set, each with its own `name`.
##
## NOTE: Enabling or disabling a layer while its parent isn't loaded is an error.
@export var parent: StdInputActionSet = null
