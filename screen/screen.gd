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

## covered is emitted when another screen is pushed on top.
##
## NOTE: This is only emitted when this scene *was* just covered.
signal covered(scene: Node)

## entered is emitted after the enter transition completes.
signal entered(scene: Node)

## entering is emitted after the scene mounts but before the enter transition starts.
signal entering(scene: Node)

## exited is emitted after the exit transition completes, but before freeing the scene.
signal exited(scene: Node)

## exiting is emitted before the exit transition starts.
signal exiting(scene: Node)

## uncovered is emitted when the covering screen is popped.
##
## NOTE: This is only emitted when this scene *was* just uncovered.
signal uncovered(scene: Node)

# -- CONFIGURATION ------------------------------------------------------------------- #

## scene_path is the path to the packed scene file. Optional; when
## empty, the caller must provide a pre-built instance to
## push/replace/reset methods.
@export_file("*.tscn", "*.scn") var scene_path: String = ""

## pause_when_covered controls whether this screen's scene has its
## process mode set to disabled when another screen is pushed on top.
@export var pause_when_covered: bool = true

@export_group("Transitions")

## enter_transition is the transition played when this screen
## enters view.
@export var enter_transition: StdScreenTransition

## block_on_enter controls whether the manager waits for the enter
## transition to complete before emitting entered/covered signals.
@export var block_on_enter: bool = false

## exit_transition is the transition played when this screen exits
## view.
@export var exit_transition: StdScreenTransition

## block_on_exit controls whether the manager waits for the exit
## transition to complete before freeing the scene.
@export var block_on_exit: bool = false

@export_group("Dependencies")

## preload_scenes is a list of scene paths to begin loading in the
## background after this screen finishes entering.
@export_file var preload_scenes: PackedStringArray = []
