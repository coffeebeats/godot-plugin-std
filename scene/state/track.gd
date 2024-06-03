##
## std/scene/state/track.gd
##
## Track is a non-instantiable state which loads all instantiable descendent states'
## scenes (direct and, optionally, indirect). It will also keep a reference to these
## scenes so that they will always be cached by the resource loader.
##

extends "../scene.gd".State

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Instantiable := preload("instantiable.gd")
const Loader := preload("../loader.gd")
const Nodes := preload("../../iter/node.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## track_direct_only configures the 'Track' state to only load scenes of direct child
## states. Set to 'false' to load scene files for all descendents.
@export var track_direct_only: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

var _tracked: Array[Loader.Result] = []

# -- PRIVATE METHODS (OVERRIDES)------------------------------------------------------ #


## A virtual method called when this state is entered (after exiting previous state).
func _on_enter(_previous: State) -> void:
	assert(_tracked.is_empty(), "invalid state; found leftover resources")

	for n in Nodes.descendents(
		self as Object, Nodes.Filter.ALL, Nodes.Order.BREADTH_FIRST
	):
		if not track_direct_only and n.get_parent() != self:
			break

		var descendent: Instantiable = n as Object as Instantiable
		if not descendent or descendent.scene == "":
			continue

		_tracked.append(_root._loader.load(descendent.scene))


## A virtual method called when leaving this state (prior to entering next state).
func _on_exit(_next: State) -> void:
	_tracked.clear()
