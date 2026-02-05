##
## router/context.gd
##
## StdRouteContext defines information about a navigation event; it's passed to route
## hooks and guards during a route transition (not to be confused with transition
## effects). Navigation information includes details about the source and destination
## routes, their parameters, and how the navigation was initiated.
##

class_name StdRouteContext
extends RefCounted

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config/config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## NavigationEvent enumerates the type of event that triggered navigation.
enum NavigationEvent {
	NAVIGATION_EVENT_INITIAL,  ## The initial route on router startup.
	NAVIGATION_EVENT_POP,  ## Navigating back in the route stack.
	NAVIGATION_EVENT_PUSH,  ## A new route was pushed onto the stack.
	NAVIGATION_EVENT_REDIRECT,  ## A guard or hook triggered a redirect.
	NAVIGATION_EVENT_REPLACE,  ## The current route was replaced.
}

const NAVIGATION_EVENT_INITIAL := NavigationEvent.NAVIGATION_EVENT_INITIAL
const NAVIGATION_EVENT_POP := NavigationEvent.NAVIGATION_EVENT_POP
const NAVIGATION_EVENT_PUSH := NavigationEvent.NAVIGATION_EVENT_PUSH
const NAVIGATION_EVENT_REDIRECT := NavigationEvent.NAVIGATION_EVENT_REDIRECT
const NAVIGATION_EVENT_REPLACE := NavigationEvent.NAVIGATION_EVENT_REPLACE

# -- CONFIGURATION ------------------------------------------------------------------- #

## The router instance handling this navigation.
var router: StdRouter = null

@export_category("Navigation")

## event is the triggering event type for the route navigation.
var event: NavigationEvent = NAVIGATION_EVENT_INITIAL

@export_subgroup("From")

## The current route's definition.
var from_route: StdRoute = null

## from_params are the current route's parameters merged into all of its ancestors'
## route parameters. Note that this includes *all* ancestors, not just up to the least-
## common ancestor with the target route.
var from_params: Config = null

@export_subgroup("To")

## The target route's definition (the route being navigated to).
var to_route: StdRoute = null

## to_params are the target route's parameters merged into all of its ancestors'
## route parameters. Note that this includes *all* ancestors, not just up to the least-
## common ancestor with the current route.
var to_params: StdRouteParams = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## merge_into_from_params merges the provide route params into this context's
## `from_params`. Any values already present will be overridden.
func merge_into_from_params(params: StdRouteParams) -> void:
	if params == null:
		assert(false, "invalid argument; missing route params")
		return

	if from_params == null:
		from_params = Config.new()

	params.store(from_params)


## merge_into_to_params merges the provide route params into this context's `to_params`.
## Any values already present will be overridden.
func merge_into_to_params(params: StdRouteParams) -> void:
	if params == null:
		assert(false, "invalid argument; missing route params")
		return

	if from_params == null:
		from_params = Config.new()

	params.store(from_params)
