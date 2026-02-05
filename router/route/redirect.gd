##
## router/route/redirect.gd
##
## StdRouteRedirect is a route that immediately redirects to another route; redirects
## are evaluated after the target route's guards pass, allowing conditional redirects
## based on guard logic. The router detects and rejects circular redirects.
##

@tool
class_name StdRouteRedirect
extends StdRoute

# -- CONFIGURATION ------------------------------------------------------------------- #

## redirect_to is the target route handle to redirect to.
@export var redirect_to: StdRoute

## preserve_params defines whether to pass the original navigation params to the
## redirect target. When enabled, the params provided to the original navigation request
## are forwarded to the target route. When false, the target route receives no params.
@export var preserve_params: bool = false
