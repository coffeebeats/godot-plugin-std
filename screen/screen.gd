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

## close_requested is emitted when a close trigger (overlay click or close action) fires
## on this screen's overlay. Emitted on *all* screens in the overlay in reverse stack
## order (topmost first). Call `cancel.call()` from any handler to abort the close for
## the entire overlay. If no handler cancels, all screens in the overlay are popped.
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

## pause_when_covered controls whether this screen's scene has its process mode set to
## disabled when another screen is pushed on top.
@export var pause_when_covered: bool = true

@export_group("Transitions")

@export_subgroup("Enter")

## transition_enter is the transition played when this screen enters view.
@export var transition_enter: StdScreenTransition

## block_on_enter controls whether the manager waits for the enter transition to
## complete before emitting entered/covered signals.
@export var block_on_enter: bool = false

@export_subgroup("Exit")

## transition_exit is the transition played when this screen exits view.
@export var transition_exit: StdScreenTransition

## block_on_exit controls whether the manager waits for the exit transition to
## complete before freeing the scene.
@export var block_on_exit: bool = false

@export_group("Dependencies")

## preload_scenes is a list of scene paths that must be loaded before this screen's
## enter transition starts. Loaded resources are held in memory for the screen's
## lifetime in the stack.
@export_file("*.tscn", "*.scn") var preload_scenes: PackedStringArray = []

@export_group("Input")

## block_input_below controls whether this screen creates a new input isolation layer.
## When true (default), a new overlay is created that blocks both mouse and keyboard
## input from reaching screens lower in the stack. When false, this screen's scene joins
## the overlay of the screen below.
@export var block_input_below: bool = true

## overlay_click_to_close is a bitmask of mouse buttons that trigger a close request
## when the overlay background (scrim) is clicked. Uses MouseButtonMask values (1=Left,
## 2=Right, 4=Middle). Set to 0 (default) to disable.
@export_flags("Left:1", "Right:2", "Middle:4") var overlay_click_to_close: int = 0

## close_action is the input action (e.g. &"ui_cancel") that triggers a close request
## when no scene control consumes it; empty (default) disables action-to-close.
@export var close_action: StringName = &""

## close_animate_intermediate controls whether closing this screen's overlay animates
## all exit transitions sequentially. When false (default), only the bottom screen in
## the overlay plays its exit animation; upper screens are torn down instantly. Only the
## bottom-most screen's value is used.
@export var close_animate_intermediate: bool = false

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## disconnect_signal_handlers disconnects all callbacks on this screen's lifecycle
## signals that are bound to the given scene. Used to remove stale connections if the
## same `StdScreen` is reused.
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
