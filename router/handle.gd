##
## router/handle.gd
##
## StdRouteHandle is a resource-based reference to a specific route in the application's
## router. Handles are the sole mechanism for navigation, providing a type-safe
## interface for navigating between routes.
##
## Users can attach a `StdRouteHandle` to a `StdRoute`, causing that handle instance to
## become linked with the route; calling navigation methods on a handle that's linked to
## a route will just work. Because handles are resources, they can be saved to the file
## system and safely accessed from multiple locations. Additionally, developers can
## override this script to provide type-safe access to the route (i.e. override the
## route params required to navigate to it).
##

class_name StdRouteHandle
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## default_controller will be used as the default controller to drive navigation events
## *to* this route. If this property is omitted, the global default will be used. Note
## that the `StdRouterController` passed to the navigation methods will take priority.
@export var default_controller: StdRouterController = null

# -- INITIALIZATION ------------------------------------------------------------------ #

## NOTE: This will be injected by `StdRoute` when registered with the router.
var _router: StdRouter = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## pop exits this route, returning to the previous route in the navigation history
## stack. Returns an error if this route is not active.
func pop(controller: StdRouterController = null) -> Error:
	assert(_router, "handle not registered with a router")

	var route: StdRoute = _router.get_current_route()
	if not route or route.handle != self:
		assert(false, "invalid state; attempted to pop inactive route")
		return ERR_DOES_NOT_EXIST

	return _router.pop(controller)


## push navigates to the associated route and adds it onto the navigation history stack;
## the previous route can be returned to by calling `pop()`.
func push(
	params: StdRouteParams = null, controller: StdRouterController = null
) -> Error:
	assert(_router, "handle not registered with a router")
	return _router.push(self, params, controller)


## replace navigates to the associated route and then clears the current navigation
## history stack; this route becomes the new history root.
func replace(params: StdRouteParams = null) -> Error:
	assert(_router, "handle not registered with a router")
	return _router.replace(self, params)
