##
## router/guard.gd
##
## StdRouteGuard is a base class for route navigation guards. Guards determine whether
## navigation to a route is allowed based on application state.
##

class_name StdRouteGuard
extends Resource

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_allowed returns whether the navigation event is allowed for the given context.
func is_allowed(context: StdRouteContext) -> bool:
	return _is_allowed(context)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## A virtual method returning whether navigation is allowed to proceed.
##
## NOTE: This method must be overridden.
func _is_allowed(_context: StdRouteContext) -> bool:
	assert(false, "unimplemented; this method must be overridden.")
	return true
