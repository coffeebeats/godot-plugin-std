##
## std/input/action_set.gd
##
## `InputActionSet` is a collection of input actions which, collectively, define
## available player actions during a section of the game.
##

@tool
class_name InputActionSetLayer
extends InputActionSet

# -- CONFIGURATION ------------------------------------------------------------------- #

## parent is an `InputActionSet` that must be activated for this action set layer to be
## applied. When this layer is activated, all non-overridden bindings from the parent
## action set (and any previously activated layers) will remain active.
@export var parent: InputActionSet = null
