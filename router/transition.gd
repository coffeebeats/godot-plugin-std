##
## router/transition.gd
##
## StdRouteTransition is a base class for visual transition effects during route
## changes. This class should be extended to provide custom transition behavior.
##

class_name StdRouteTransition
extends Resource

# -- SIGNALS ------------------------------------------------------------------------- #

## completed is emitted when the route transition effect has finished executing.
signal completed

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## start begins the route transition effect on the given scene. The `is_entering`
## parameter indicates whether the scene is entering (true) or exiting (false) view.
func start(scene: Node, is_entering: bool) -> void:
	_start(scene, is_entering)


## cancel stops the transition without emitting completed. Used by the router to
## interrupt in-flight transitions.
func cancel() -> void:
	_cancel()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _start is a virtual method that begins the route transition effect on the given scene.
## Subclasses MUST call _done() when the transition completes (immediately or deferred).
##
## NOTE: Override this method to implement custom transition behavior.
func _start(_scene: Node, _is_entering: bool) -> void:
	_done()


## _cancel is a virtual method for stopping the transition effect.
##
## NOTE: Override this method to implement custom transition behavior.
func _cancel() -> void:
	pass


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _done signals that the transition has finished. Subclasses MUST call this when done.
func _done() -> void:
	completed.emit()
