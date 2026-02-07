##
## router/layer.gd
##
## StdRouterLayer represents a single navigation layer with its
## own current route, params, and history stack. The router
## maintains a base layer for views and a stack of modal layers.
##

class_name StdRouterLayer
extends RefCounted

# -- INITIALIZATION ------------------------------------------------------------------ #

## root_route is the modal that created this layer (null for base).
var root_route: StdRouteModal = null

## current_route is the currently active route in this layer.
var current_route: StdRoute = null

## current_params are the parameters for the current route.
var current_params: StdRouteParams = null

## history is the navigation history stack for this layer.
var history: StdRouterHistory = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_base returns true when this is the base navigation layer.
func is_base() -> bool:
	return root_route == null


## can_pop returns whether there is history to pop.
func can_pop() -> bool:
	return not history.is_empty()


## push_state saves the current route to history and sets new.
func push_state(route: StdRoute, params: StdRouteParams) -> void:
	assert(history is StdRouterHistory, "invalid state; missing router history.")

	if current_route != null:
		history.push(current_route, current_params)
	current_route = route
	current_params = params


## pop_state pops the history and sets the new current.
func pop_state(route: StdRoute, params: StdRouteParams) -> void:
	assert(history is StdRouterHistory, "invalid state; missing router history.")

	if not history.is_empty():
		history.pop()
	current_route = route
	current_params = params


## set_current updates the current route without touching history.
func set_current(route: StdRoute, params: StdRouteParams) -> void:
	current_route = route
	current_params = params


## clear resets history and current state.
func clear() -> void:
	assert(history is StdRouterHistory, "invalid state; missing router history.")

	history.clear()
	current_route = null
	current_params = null


## get_view_beneath_modal returns the most recent non-modal route
## in history (the view visible under a modal). Returns null if
## no non-modal entry exists.
func get_view_beneath_modal() -> StdRoute:
	var all := history.entries()
	for i in range(all.size() - 1, -1, -1):
		var entry: StdRouterHistory.Entry = all[i]
		if not entry.route is StdRouteModal:
			return entry.route

	return null


## collect_routes returns current + history routes in leaf-to-root
## order (current first, then history from top to bottom).
func collect_routes() -> Array[StdRoute]:
	var routes: Array[StdRoute] = []
	if current_route != null:
		routes.append(current_route)
	var all := history.entries()
	for i in range(all.size() - 1, -1, -1):
		var entry: StdRouterHistory.Entry = all[i]
		if entry.route not in routes:
			routes.append(entry.route)
	return routes
