##
## router/dependencies.gd
##
## A collection of resource paths to preload for a route. Dependencies are loaded when
## the route is entered (via background loading through `StdRouterLoader`) and
## references are held while the route is active, then released on exit.
##

class_name StdRouteDependencies
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## resources is an array of resource paths to preload when this route is entered.
@export_file("*.tscn") var resources: Array[String] = []
