##
## router/controller.gd
##
## StdRouterController is a base class for orchestrating route transitions during
## navigation. The controller coordinates when scenes are added/removed and when
## enter/exit transitions run. This class may be extended to custom behavior.
##

class_name StdRouterController
extends Resource

# -- SIGNALS ------------------------------------------------------------------------- #

## completed is emitted when the route navigation sequence is complete.
signal completed

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## execute runs the route navigation sequence.
func execute(
	parent: Node,
	current: Node,
	target: Node,
	transition_exit: StdRouteTransition,
	transition_enter: StdRouteTransition,
) -> void:
	_execute(parent, current, target, transition_exit, transition_enter)
	completed.emit()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _execute is a virtual method defining the route navigation sequence.
##
## NOTE: This method should be overridden to implement the desired transition behavior.
func _execute(
	_parent: Node,
	_current: Node,
	_target: Node,
	_transition_exit: StdRouteTransition,
	_transition_enter: StdRouteTransition,
) -> void:
	assert(false, "unimplemented; this method should be overridden.")
