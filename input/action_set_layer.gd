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

## parent is the only `StdInputActionSet` this layer can be enabled over, and the set it
## sits under in the Steam Input manifest. An enabled layer keeps every binding below it
## that it does not override.
##
## NOTE: A layer with no parent fits any set, so the manifest writes a copy of it under
## each one. Leave `parent` unset only for a layer every set may enable.
@export var parent: StdInputActionSet = null
