##
## std/scene/state/auto_transition.gd
##
## AutoTransition is a transition state which automatically transitions to the target
## state as soon as it's loaded. This is useful as an initial state which enables the
## state machine to handle its initial transition without nodes being added to the
## scene.
##

extends "transition.gd"

# -- PRIVATE METHODS (OVERRIDES)------------------------------------------------------ #


## A virtual method called to process a frame/tick, given the frame time 'delta'.
func _on_update(_delta: float) -> State:
	if (
		_to_load_result
		and _to_load_result.status != ResourceLoader.THREAD_LOAD_IN_PROGRESS
	):
		return _parent

	var target: BaseState = (self as Object).get_node_or_null(to) as Object
	assert(target, "missing target state node")

	return _transition_to(_root.get_path_to(target as Object))
