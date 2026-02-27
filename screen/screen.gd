##
## screen/screen.gd
##
## StdScreen is a resource describing a screen in the screen stack. Each screen defines
## its scene source, transitions, and lifecycle signals that scene instances can connect
## to.
##

class_name StdScreen
extends Resource

# -- SIGNALS ------------------------------------------------------------------------- #

## close_requested is emitted when a close is requested for this screen via `pop()` or
## an overlay background click. Call `cancel.call()` from any handler to abort closing.
@warning_ignore("unused_signal")
signal close_requested(event: InputEvent, cancel: Callable)

## covered is emitted when another screen is pushed on top.
##
## NOTE: This is only emitted when this scene *was* just covered.
@warning_ignore("unused_signal")
signal covered(scene: Node)

## entered is emitted after the enter transition completes.
@warning_ignore("unused_signal")
signal entered(scene: Node)

## entering is emitted after the scene mounts but before the enter transition starts.
@warning_ignore("unused_signal")
signal entering(scene: Node)

## exited is emitted after the exit transition completes, but before freeing the scene.
@warning_ignore("unused_signal")
signal exited(scene: Node)

## exiting is emitted before the exit transition starts.
@warning_ignore("unused_signal")
signal exiting(scene: Node)

## uncovered is emitted when the covering screen is popped.
##
## NOTE: This is only emitted when this scene *was* just uncovered.
@warning_ignore("unused_signal")
signal uncovered(scene: Node)

# -- CONFIGURATION ------------------------------------------------------------------- #

## scene_path is the path to the packed scene file. Optional; when empty, the caller
## must provide a pre-built instance to push/replace/reset methods.
@export_file("*.tscn", "*.scn") var scene_path: String = ""

## cache_instance prevents the manager from freeing the scene on pop. The scene is
## removed from the tree and stored internally. On the next push of this screen, the
## cached instance is reused (re-added to tree) instead of instantiating from scene_path.
@export var cache_instance: bool = false

## pause_when_covered controls whether this screen's scene has its process mode set to
## disabled when another screen is pushed on top.
@export var pause_when_covered: bool = false

@export_group("Transition")

## transition is the default transition used for this screen's visual lifecycle.
@export var transition: StdScreenTransition

@export_subgroup("Overrides")

## transition_push overrides `transition` for push, replace, and reset operations.
@export var transition_push: StdScreenTransition

## transition_pop overrides `transition` for pop operations.
@export var transition_pop: StdScreenTransition

@export_group("Dependencies")

## preload_scenes is a list of scene paths that must be loaded before this screen's
## target scene may enter the scene tree.
##
@export_file("*.tscn", "*.scn") var preload_scenes: PackedStringArray = []

@export_group("Input")

## block_input_below controls whether this screen creates a new input isolation layer.
## When true (default), a new overlay is created that blocks both mouse and keyboard
## input from reaching screens lower in the stack. When false, this screen's scene joins
## the overlay of the screen below.
@export var block_input_below: bool = true

## overlay_click_to_close is a bitmask of mouse buttons that trigger a close request
## when the overlay background (scrim) is clicked.
@export_flags("Left:1", "Right:2", "Middle:4") var overlay_click_to_close: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## disconnect_signal_handlers disconnects all callbacks on this screen's lifecycle
## signals that are bound to the given scene.
func disconnect_signal_handlers(scene: Node) -> void:
	for s in [
		close_requested,
		covered,
		entered,
		entering,
		exited,
		exiting,
		uncovered,
	]:
		for connection in s.get_connections():
			var callable: Callable = connection["callable"]
			if callable.get_object() == scene:
				s.disconnect(callable)
