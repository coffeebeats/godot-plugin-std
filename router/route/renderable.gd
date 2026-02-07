##
## router/route/renderable.gd
##
## An intermediate base class for routes that render a scene. This class extends
## StdRoute with scene instantiation, visual transitions, and dependency loading
## configuration.
##

@tool
class_name StdRouteRenderable
extends StdRoute

# -- DEFINITIONS --------------------------------------------------------------------- #

## ChildDependencyLoadMode enumerates settings controlling whether child routes'
## dependencies are loaded when this route enters.
enum ChildDependencyLoadMode {  # gdlint:ignore=class-definitions-order
	CHILD_DEPENDENCY_LOAD_OFF,  ## Only load this route's dependencies.
	CHILD_DEPENDENCY_LOAD_DIRECT,  ## Load direct child route dependencies.
	CHILD_DEPENDENCY_LOAD_RECURSIVE,  ## Load dependencies of all descendent routes.
}

const CHILD_DEPENDENCY_LOAD_OFF := ChildDependencyLoadMode.CHILD_DEPENDENCY_LOAD_OFF
const CHILD_DEPENDENCY_LOAD_DIRECT := (
	ChildDependencyLoadMode.CHILD_DEPENDENCY_LOAD_DIRECT
)
const CHILD_DEPENDENCY_LOAD_RECURSIVE := (
	ChildDependencyLoadMode.CHILD_DEPENDENCY_LOAD_RECURSIVE
)

# -- CONFIGURATION ------------------------------------------------------------------- #

## scene_path defines a path to a packed scene; this scene will be instantiated when
## this route becomes active. The scene is added to the appropriate view container,
## content or modal, based on the route type.
@export_file("*.tscn") var scene_path: String

@export_group("Transitions")

## transition_enter is the visual transition effect to play when this route enters view.
## If null, no transition is played.
@export var transition_enter: StdRouteTransition

## transition_exit is the visual transition effect to play when this route exits view.
## If null, no transition is played.
@export var transition_exit: StdRouteTransition

@export_group("Interrupts")

## allow_interrupt controls whether in-flight transitions to or from this route can be
## interrupted by new navigation requests. When false, new interrupt requests are queued
## until this route's transition completes.
@export var allow_interrupt: bool = true

@export_group("Dependencies")

## child_dependency_load_mode controls whether child route dependencies are loaded when
## this route is activated.
@export
var child_dependency_load_mode: ChildDependencyLoadMode = CHILD_DEPENDENCY_LOAD_OFF

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_scene returns the packed scene for this route. The scene should already be loaded
## via the dependency system; this method retrieves it from the cache.
func get_scene() -> PackedScene:
	if not scene_path:
		return null
	# Scene should already be loaded via dependency system.
	return ResourceLoader.load(
		scene_path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE
	)
