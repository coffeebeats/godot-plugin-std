##
## router/route.gd
##
## StdRoute is a base class for all route types in the routing system. Routes are nodes
## that define navigation targets and should be placed under a `StdRouter` node. Each
## route provides navigation methods (push, pop, replace) and an optional frozen params
## schema for type-safe parameter passing.
##

@tool
class_name StdRoute
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

## DependencyWaitMode controls how dependencies are managed when navigating to this
## route.
enum DependencyWaitMode {
	DEPENDENCY_WAIT_MODE_ALLOW,  ## Allow navigation even if loading hasn't finished.
	DEPENDENCY_WAIT_MODE_BLOCK,  ## Wait for all dependencies before navigating.
	DEPENDENCY_WAIT_MODE_REJECT,  ## Reject navigation if not yet done loading.
}

const DEPENDENCY_WAIT_MODE_ALLOW := DependencyWaitMode.DEPENDENCY_WAIT_MODE_ALLOW
const DEPENDENCY_WAIT_MODE_BLOCK := DependencyWaitMode.DEPENDENCY_WAIT_MODE_BLOCK
const DEPENDENCY_WAIT_MODE_REJECT := DependencyWaitMode.DEPENDENCY_WAIT_MODE_REJECT

# -- CONFIGURATION ------------------------------------------------------------------- #

## handle is a lightweight identity resource that uniquely identifies this route. If
## omitted, one will be auto-created. A route and its handle have a 1:1 mapping; the
## same handle cannot be used by multiple routes.
@export var handle: StdRouteHandle

## params is a frozen schema for this route's parameters. Clone it to create a mutable
## instance for use with navigation methods (e.g. `route.params.clone()`).
@export var params: StdRouteParams

## segment is the route path segment for this route (e.g., &"game", &"pause"); it's used
## to construct the full route path by joining it with all ancestor route segments.
@export var segment: StringName = &""

@export_subgroup("Nesting")

## is_index controls whether this route is the default child of its parent. When
## navigating to the parent route directly, the router redirects to the child which has
## this enabled. It's an error for multiple sibling routes to enable this.
@export var is_index: bool = false

@export_group("Guards")

## guards is a list of guards to evaluate before navigation. All guards must succeed for
## navigation to proceed. Guards are evaluated in order; if any guard fails, subsequent
## guards are skipped.
@export var guards: Array[StdRouteGuard]

@export_group("Hooks")

## hooks is a list of navigation hooks to execute during navigation. Hooks can block
## navigation, redirect to different routes, or execute side effects. Hooks are run in
## order; if a hook returns BLOCK or REDIRECT, subsequent hooks are skipped. "After"
## hooks are only run if the navigation succeeds.
@export var hooks: Array[StdRouteHook]

@export_group("Dependencies")

## dependency_wait_mode controls how navigation is affected by loading resources.
@export var dependency_wait_mode: DependencyWaitMode = DEPENDENCY_WAIT_MODE_BLOCK

## dependencies is a list of Resource dependency sets to preload when this route is
## activated. These resources will be background loaded and then kept in memory while as
## long as the route is active.
@export var dependencies: Array[StdRouteDependencies]

# -- INITIALIZATION ------------------------------------------------------------------ #

var _path: StringName = &""
var _router: StdRouter = null  ## NOTE: Injected by `StdRouter` during registration.

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_full_path constructs the full route path for this route from its ancestor path
## segments. Returns an "absolute" path like "/foo/bar/baz", where the last segment is
## this route's segment name.
func get_full_path() -> StringName:
	if _path:
		return _path

	var segments: PackedStringArray = []

	var current: Node = self
	while current:
		if current is StdRoute:
			segments.append(current.segment)
		elif current is StdRouter:
			break

		current = current.get_parent()

	segments.reverse()

	assert(not segments.is_empty(), "invalid state; missing route path segments")

	_path = StringName("/" + "/".join(segments))
	return _path


## pop exits this route, returning to the previous route in the navigation history
## stack. Returns an error if this route is not the current route.
func pop(
	parameters = null,
	controller: StdRouterController = null,
	interrupt: bool = false,
) -> Error:
	assert(_router, "route not registered with a router")

	var topmost: StdRoute = _router.get_topmost_route()
	if topmost != self:
		assert(false, "invalid state; pop on inactive route")
		return ERR_DOES_NOT_EXIST

	return _router.pop(parameters, controller, interrupt)


## push navigates to this route and adds it onto the navigation history stack; the
## previous route can be returned to via `pop()`.
func push(
	parameters = null,
	controller: StdRouterController = null,
	interrupt: bool = false,
) -> Error:
	assert(_router, "route not registered with a router")
	return _router.push(self, parameters, controller, interrupt)


## replace navigates to this route and clears the current navigation history stack; this
## route becomes the new history root.
func replace(
	parameters = null,
	controller: StdRouterController = null,
	interrupt: bool = false,
) -> Error:
	assert(_router, "route not registered with a router")
	return _router.replace(self, parameters, controller, interrupt)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(segment, "invalid configuration; missing required property.")

	if handle == null:
		handle = StdRouteHandle.new()

	if params != null:
		params = params.frozen() as StdRouteParams
