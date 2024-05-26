##
## std/scene/runner.gd
##
## Runner ...
##

extends "../fsm/state_machine.gd"

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

const StateMachine := preload("../fsm/state_machine.gd")
const Loader := preload("loader.gd")
const Switcher := preload("switcher.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## loader is a path to a 'Loader' node which can load packed scenes in the background.
@export var loader: NodePath

## switcher is a path to a 'Switcher' node which can switch the active scene.
@export var switcher: NodePath

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _loader: Loader = get_node(loader)
@onready var _switcher: Switcher = get_node(switcher)

var _tracked: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
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

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
