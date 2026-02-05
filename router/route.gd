##
## router/route.gd
##
## StdRoute is a base class for all route types in the routing system. Routes are nodes
## that define navigation targets and should be placed under a `StdRouter` node. Each
## route has a 1:1 mapping with a `StdRouteHandle` resource, which is the sole mechanism
## for navigating to that route.
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

## segment is the route path segment for this route (e.g., &"game", &"pause"); it's used
## to construct the full route path by joining it with all ancestor route segments.
@export var segment: StringName = &""

## The handle that uniquely identifies this route. Navigation to this route is
## performed exclusively through this handle. A route and its handle have a 1:1
## mapping; the same handle cannot be used by multiple routes.
@export var handle: StdRouteHandle

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
## navigation, redirect to different routes, or execute side effects; they will be run
## in order and not skipped, even if execution fails (though "after" events are skipped
## if the navigation did not succeed).
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

		current = current.get_parent()

	segments.reverse()

	assert(not segments.is_empty(), "invalid state; missing route path segments")
	return StringName("/" + "/".join(segments))


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(segment, "invalid configuration; missing required property.")
	assert(handle, "invalid configuration; missing required property.")
