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


## execute runs the route transition effect on the given scene. The `is_entering`
## parameter indicates whether the scene is entering (true) or exiting (false) view.
func execute(scene: Node, is_entering: bool) -> void:
	_execute(scene, is_entering)
	completed.emit()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _execute is a virtual method that runs the route transition effect on the given
## scene.
##
## NOTE: This method should be overridden to customize behavior.
func _execute(_scene: Node, _is_entering: bool) -> void:
	assert(false, "unimplemented; this method should be overridden.")
