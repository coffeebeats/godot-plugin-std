##
## std/input/action_set.gd
##
## StdInputActionSet is a collection of input actions which, collectively, define
## available player actions during a section of the game.
##

@tool
class_name StdInputActionSetLayer
extends StdInputActionSet

# -- CONFIGURATION ------------------------------------------------------------------- #

## parent is an `StdInputActionSet` that must be activated for this action set layer to
## be applied. When this layer is activated, all non-overridden bindings from the parent
## action set (and any previously activated layers) will remain active.
@export var parent: StdInputActionSet = null
