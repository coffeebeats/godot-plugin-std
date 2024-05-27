##
## std/scene/runner.gd
##
## Runner ...
##

extends "../../fsm/state_machine.gd"

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Loader := preload("../loader.gd")
const RunnerState := preload("state.gd")
const Switcher := preload("../switcher/switcher.gd")
const Transition := preload("../switcher/transition.gd")
const TransitionInstant := preload("../switcher/transition/instant.gd")


# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## loader is a path to a 'Loader' node which can load packed scenes in the background.
@export var loader: NodePath

## switcher is a path to a 'Switcher' node which can switch the active scene.
@export var switcher: NodePath

## root is the path to the root game node.
@export var root: NodePath

# -- INITIALIZATION ------------------------------------------------------------------ #

var _tracked: Dictionary = {}

@onready var _loader: Loader = get_node(loader)
@onready var _switcher: Switcher = get_node(switcher)

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	super()

	var err := state_entered.connect(_on_state_entered)
	assert(err == OK, "failed to connect to signal")

	err = state_exited.connect(_on_state_exited)
	assert(err == OK, "failed to connect to signal")


func _exit_tree() -> void:
	assert(state_entered.is_connected(_on_state_entered), "signal wasn't connected")
	state_entered.disconnect(_on_state_entered)

	assert(state_exited.is_connected(_on_state_exited), "signal wasn't connected")
	state_exited.disconnect(_on_state_exited)


func _ready() -> void:
	super()

	assert(_loader != null, "failed to load 'Loader'")
	assert(_switcher != null, "failed to load 'Switcher'")



# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _track stores a reference to a loaded scene, allowing one state to load a resource
## on behalf of another without needing to track it itself.
func _track(scene: String, result: Loader.Result):
	assert(scene != "", "missing argument: scene")
	assert(result != null, "missing argument: result")

	if scene in _tracked:
		assert(result == _tracked[scene], "invalid argument; refusing to overwrite")
		return

	_tracked[scene] = result


## _untrack is used to removed a stored reference to a loaded scene.
func _untrack(scene: String) -> bool:
	assert(scene != "", "missing argument: scene")
	return _tracked.erase(scene)

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

func _on_state_entered(path: NodePath) -> void:
	var node := get_node_or_null(path)
	assert(node != null, "failed to find state node")

	var state := node as Object as RunnerState
	assert(state != null, "failed to find state")

	for transition in state.dependencies:
		var target := node.get_node_or_null(transition) as Object as RunnerState
		assert(target != null, "failed to find target state")

		_track(target.scene, _loader.load_scene(target.scene, true))

	var next := ResourceLoader.load(state.scene, "PackedScene")
	_untrack(state.scene)

	var target := NodePath(str(get_tree().root.get_path_to(self)) + "/" + str(root))

	var transition: Transition
	if state.transition != null:
		transition = state.transition.instantiate()

	_switcher.transition_to(target, next, transition)

func _on_state_exited(path: NodePath) -> void:
	pass

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
