##
## router/hook.gd
##
## A base class for route lifecycle hooks that can intercept and modify navigation
## behavior. Hooks can block navigation, redirect to different routes, or execute
## side effects at various points in the navigation lifecycle.
##

class_name StdRouteHook
extends Resource

# -- DEFINITIONS --------------------------------------------------------------------- #


## Result is the result of a hook execution, containing the action to take and optional
## redirect information.
class Result:
	extends RefCounted

	## Action is an enumeration of actions that a hook can take during navigation.
	enum Action {  # gdlint:ignore=class-definitions-order
		ACTION_CONTINUE,  ## Allow navigation to proceed normally.
		ACTION_BLOCK,  ## Prevent the navigation from occurring.
		ACTION_REDIRECT,  ## Redirect to a different route.
	}

	const ACTION_CONTINUE := Action.ACTION_CONTINUE
	const ACTION_BLOCK := Action.ACTION_BLOCK
	const ACTION_REDIRECT := Action.ACTION_REDIRECT

	## action is the action the router should take based on this hook's execution.
	var action: Action = Action.ACTION_CONTINUE

	## redirect_to is the handle of the route to redirect to (only used when action
	## is REDIRECT). This remains a StdRouteHandle (not StdRoute) for cross-scene
	## compatibility — handles are resources that can be referenced anywhere.
	var redirect_to: StdRouteHandle = null

	## redirect_params are parameters for a redirect action.
	var redirect_params: StdRouteParams = null


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## before_enter is called before entering a route. Return a `Result` to control the
## navigation behavior.
func before_enter(context: StdRouterContext) -> Result:
	# NOTE: 'from_route' may be null on initial navigation.
	assert(context.to_route, "invalid state; missing 'to' route.")
	return _before_enter(context)


## after_enter is called after successfully entering a route.
func after_enter(context: StdRouterContext) -> void:
	# NOTE: from_route may be null on initial navigation.
	assert(context.to_route, "invalid state; missing 'to' route.")
	_after_enter(context)


## before_exit is called before exiting a route. Return a `Result` to control the
## navigation behavior.
func before_exit(context: StdRouterContext) -> Result:
	assert(context.from_route, "invalid state; missing 'from' route.")
	assert(context.to_route, "invalid state; missing 'to' route.")
	return _before_exit(context)


## after_exit is called after successfully exiting a route.
func after_exit(context: StdRouterContext) -> void:
	assert(context.from_route, "invalid state; missing 'from' route.")
	assert(context.to_route, "invalid state; missing 'to' route.")
	_after_exit(context)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _before_enter is a virtual method called before entering a route.
func _before_enter(_context: StdRouterContext) -> Result:
	return Result.new()


## _after_enter is a virtual method called after successfully entering a route.
func _after_enter(_context: StdRouterContext) -> void:
	pass


## _before_exit is a virtual method called before exiting a route.
func _before_exit(_context: StdRouterContext) -> Result:
	return Result.new()


## _after_exit is a virtual method called after successfully exiting a route.
func _after_exit(_context: StdRouterContext) -> void:
	pass
