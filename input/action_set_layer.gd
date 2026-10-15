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

## parent is the `StdInputActionSet` this layer is written under in the Steam Input
## manifest, and the only set it can be enabled over. A layer with no parent fits any
## set: the manifest writes a copy of it under every set, and enabling it over whatever
## set is active binds its actions on top. When this layer is enabled, all
## non-overridden bindings from the set (and any previously enabled layers) remain.
##
## NOTE: Leave `parent` unset only for a layer any set may enable, such as a menu's
## navigation actions; a layer meant for one set should name it.
@export var parent: StdInputActionSet = null
