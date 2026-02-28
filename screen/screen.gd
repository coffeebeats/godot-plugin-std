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

## popped is emitted after the screen is removed from the stack, regardless of the
## removal path (pop, pop_to, replace, reset, teardown). The result is the value passed
## to `pop(result)`, or `null` for all other removal paths. This signal is guaranteed to
## fire exactly once per push, preventing coroutine leaks when using `await`.
@warning_ignore("unused_signal")
signal popped(result: Variant)

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

## dependency_screens is a list of `StdScreen`s whose scene paths and extra
## dependencies are loaded alongside this screen's target scene. Each referenced
## screen's own dependencies are resolved recursively.
@export var dependency_screens: Array[StdScreen] = []

## dependency_scenes is a list of scene paths that are loaded alongside this screen's
## target scene. Loading begins immediately when the operation starts, overlapping with
## any exit transition; resolution blocks at mount time only if still in progress.
@export_file("*.tscn", "*.scn") var dependency_scenes: PackedStringArray = []

@export_group("Input")

## block_input_below controls whether this screen creates a new input isolation layer.
## When true (default), a new overlay is created that blocks both mouse and keyboard
## input from reaching screens lower in the stack. When false, this screen's scene joins
## the overlay of the screen below.
@export var block_input_below: bool = true

## overlay_click_to_close is a bitmask of mouse buttons that trigger a close request
## when the overlay background (scrim) is clicked.
@export_flags("Left:1", "Right:2", "Middle:4") var overlay_click_to_close: int = 0

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/screen")  # gdlint:ignore=class-definitions-order,max-line-length

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


## get_dependency_paths returns every scene path that should be pre-loaded as a
## dependency of this screen, combining 'dependency_scenes' and the resolved paths of
## 'dependency_screens'.
func get_dependency_paths() -> PackedStringArray:
	return _resolve_dependency_paths({}, {})


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _resolve_dependency_paths(
	pending: Dictionary, visited: Dictionary
) -> PackedStringArray:
	if self in pending:
		var get_resource_path := func(s: StdScreen) -> String: return s.resource_path

		var chain := pending.keys().map(get_resource_path)
		chain.append(resource_path)

		_logger.error("Dependency cycle detected.", {&"chain": ",".join(chain)})

		return PackedStringArray()

	if self in visited:
		return PackedStringArray()

	pending[self] = true

	var paths: PackedStringArray = []

	for path in dependency_scenes:
		if path not in visited:
			visited[path] = true
			paths.append(path)

	for screen in dependency_screens:
		if screen == null:
			assert(false, "null entry in dependency_screens")
			continue

		if screen.scene_path and screen.scene_path not in visited:
			visited[screen.scene_path] = true
			paths.append(screen.scene_path)

		paths.append_array(screen._resolve_dependency_paths(pending, visited))

	pending.erase(self)
	visited[self] = true

	return paths
