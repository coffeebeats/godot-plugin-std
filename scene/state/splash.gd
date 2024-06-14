##
## std/scene/state/splash.gd
##
## Splash implements a 'Scene.State' for a splash screen.
##

extends "playable.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Scene := preload("../scene.gd")
const AdvanceEvent := preload("../event/advance.gd")
const Instantiable := preload("instantiable.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## to is the node path from this state to the state to which this node will transition.
@export var to: NodePath

@export_group("Splash Duration")
@export var duration_minimum_enabled: bool = true
@export_range(0.0, 5.0) var duration_minimum: float = 1.5

@export_group("Auto-transition")
@export var auto_transition_enabled: bool = true
@export_range(0.0, 5.0) var auto_transition_delay: float = 3.0

# -- INITIALIZATION ------------------------------------------------------------------ #

var _elapsed: float = 0.0
var _to_load_result: Loader.Result = null
var _transition_requested: bool = false

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## A virtual method called when this state is entered (after exiting previous state).
func _on_enter(previous: State) -> void:
	super(previous)

	_elapsed = 0.0
	_to_load_result = null
	_transition_requested = false

	var target := _get_target()
	assert(target is Scene.State, "missing transition target")

	if target is Instantiable:
		_to_load_result = _get_loader().load(target.scene)


## A virtual method called to process 'StateMachine' input for the current frame.
func _on_input(event: Event) -> State:
	if event is AdvanceEvent:
		_transition_requested = true

	return _parent


## A virtual method called to process a frame/tick, given the frame time 'delta'.
func _on_update(delta: float) -> State:
	super(delta)

	_elapsed += delta

	if (
		# Transition target is ready to be transitioned to.
		(
			(
				_to_load_result == null
				or _to_load_result.stats == ResourceLoader.THREAD_LOAD_LOADED
			)
			# Player requested transition.
			and (
				_transition_requested
				and (not duration_minimum_enabled or _elapsed >= duration_minimum)
			)
		)
		# Auto-transition.
		or (
			auto_transition_enabled
			and _elapsed >= auto_transition_delay
			and (not duration_minimum_enabled or _elapsed >= duration_minimum)
		)
	):
		var target := _get_target()
		assert(target is Scene.State, "missing transition target")

		return _transition_to(_root.get_path_to(target as Object))

	return null


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_target() -> Scene.State:
	var node: Node = self as Object as Node
	assert(node, "invalid configuration; not a node")

	return node.get_node_or_null(to) as Object
