##
## std/scene/state/track.gd
##
## Track is a non-instantiable state which loads all instantiable descendent states'
## scenes (direct and, optionally, indirect). It will also keep a reference to these
## scenes so that they will always be cached by the resource loader.
##

extends "../scene.gd".State

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Nodes := preload("../../iter/node.gd")
const Loader := preload("../loader.gd")
const Scene := preload("../scene.gd")
const Instantiable := preload("instantiable.gd")
const Track := preload("track.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## track_direct_only configures the 'Track' state to only load scenes of direct child
## states. Set to 'false' to load scene files for all descendents.
@export var track_direct_only: bool = true

## track_extra specifies an additional set of 'State' nodes whose dependencies this
## state should load and track.
@export var track_extra: Array[NodePath] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

var _tracked: Array[Loader.Result] = []

# -- PRIVATE METHODS (OVERRIDES)------------------------------------------------------ #


## A virtual method called when this state is entered (after exiting previous state).
func _on_enter(_previous: State) -> void:
	assert(_tracked.is_empty(), "invalid state; found leftover resources")

	_tracked = _track_states()


## A virtual method called when leaving this state (prior to entering next state).
func _on_exit(_next: State) -> void:
	_tracked.clear()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _track_states() -> Array[Loader.Result]:
	var out: Array[Loader.Result] = []
	var node: Node = self as Object

	# Duplicate are OK; the scene loader is idempotent.
	var states: Array[Scene.State] = []

	for path in track_extra:
		var state: Scene.State = node.get_node_or_null(path) as Object
		assert(state, "invalid config; expected path to a 'Scene' state")

		states.append(state)

	for state in Nodes.descendents(node, Nodes.Filter.ALL, Nodes.Order.BREADTH_FIRST):
		if track_direct_only and state.get_parent() != self:
			break

		if not (state as Object) is Scene.State:
			continue

		states.append(state)

	for state in states:
		if state as Object is Instantiable and state.scene != "":
			out.append(_root._loader.load(state.scene))

		if state as Object is Track and state != self and len(state.track_extra) > 0:
			out.append_array(state._track_states())  # gdlint:ignore=private-method-call

	return out
