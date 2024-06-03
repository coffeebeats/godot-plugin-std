##
## std/scene/state/playable.gd
##
## Playable is a base class for any state which defines a node that should be added to
## the current scene. This state's sole behavior is to load the configured scene upon
## entry.
##

extends "../scene.gd".State

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Loader := preload("../loader.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## path is the path at which the node' specified by 'scene' should be added. Defaults
## to replacing the game root node.
@export var path: NodePath

## scene is a filepath to a packed scene which should be instantiated and added to the
## scene tree at the node path specified by 'path'. Ignored if empty.
@export_file("*.tscn") var scene: String

# -- INITIALIZATION ------------------------------------------------------------------ #

var _load_result: Loader.Result = null

# -- PRIVATE METHODS (OVERRIDES)------------------------------------------------------ #


## A virtual method called when this state is entered (after exiting previous state).
func _on_enter(_previous: State) -> void:
	if not scene.is_empty():
		_load_result = _get_loader().load(scene)


## A virtual method called when leaving this state (prior to entering next state).
func _on_exit(_next: State) -> void:
	_load_result = null
