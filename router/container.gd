##
## router/container.gd
##
## StdRouteContainer is a placeholder node that can be swapped for nested route content
## (e.g. nested route views or modals). When a nested route is navigated to, its scene
## is instantiated and added as a child of the matching `StdRouteContainer` node in the
## parent route's rendered scene.
##
## Note that when a route is navigated to, one and only one route container must match.
## This means that a route container for the router's game root, the router's modal
## root, and any nested routes, all must exist. Furthermore, only one of each type may
## exist under the parent route's portion of the scene tree.
##

class_name StdRouteContainer
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

## GROUP_ROUTE_CONTAINER is the StdGroup ID for route container registration.
const GROUP_ROUTE_CONTAINER := &"std/router:container"

## ViewType is the type of route view this placeholder accepts. This affects how the
## rendered scene will be displayed.
enum ViewType {  # gdlint:ignore=class-definitions-order
	VIEW_TYPE_CONTENT,  ## Standard, router-managed game scene.
	VIEW_TYPE_MODAL,  ## Router-managed game scene that overlays the standard content.
}

# -- CONFIGURATION ------------------------------------------------------------------- #

## view_type is the type of nested route content this view accepts. Content views are
## for regular nested routes, while modal views are for nested modal overlays.
@export var view_type: ViewType = ViewType.VIEW_TYPE_CONTENT

# -- INITIALIZATION ------------------------------------------------------------------ #

## route is the route this container is currently assigned to. Set by the router when
## the container is discovered during a navigation transition.
var route: StdRoute = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## all returns all registered StdRouteContainer instances.
static func all() -> Array[StdRouteContainer]:
	var result: Array[StdRouteContainer] = []

	for member in StdGroup.with_id(GROUP_ROUTE_CONTAINER).list_members():
		if member is StdRouteContainer:
			result.append(member)

	return result


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	StdGroup.with_id(GROUP_ROUTE_CONTAINER).add_member(self)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_ROUTE_CONTAINER).remove_member(self)
