##
## std/fsm/state.gd
##
## A base class for states within a hierarchical state machine (HSM). Create new states
## by extending this script and implementing the virtual methods. States are registered
## with a `StdStateMachine` via `add_state()` during `_setup()`.
##

class_name StdState
extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## Emitted when this state requests a transition to a different state. The owning
## `StdStateMachine` dispatches the request.
signal transition_requested(path: NodePath)

# -- INITIALIZATION ------------------------------------------------------------------ #

## A pointer to the `StdState` which directly parents this state; will be `null` if this
## state is a top-level state within the machine.
var _parent: StdState

## The path to this state from the root 'StdStateMachine'.
@warning_ignore("unused_private_class_variable")
var _path: NodePath

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## Returns whether this state is a descendant of the specified state.
func is_substate_of(other: StdState) -> bool:
	var next: StdState = self
	while next:
		if next == other:
			return true

		next = next._parent

	return false


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## A virtual method called when this state is entered (after exiting the previous
## state). If this state is a derived state, then this method is called *after* the
## parent state's `_on_enter` method.
func _on_enter(_previous: StdState) -> void:
	pass


## A virtual method called when leaving this state (prior to entering the next state).
## If this state is a derived state, then this method is called *prior* to the parent
## state's `_on_exit` method.
func _on_exit(_next: StdState) -> void:
	pass


## A virtual method called to process input for the current frame.
##
## Returns `null` if the input has been handled, or `_parent` to delegate handling to
## the parent state. The `event` parameter is intentionally untyped to support arbitrary
## input types.
func _on_input(_event) -> StdState:
	return _parent


## A virtual method called to process a frame/tick given the elapsed time `delta`.
## Returns `null` if the frame has been handled, or `_parent` to delegate processing to
## the parent state.
func _on_update(_delta: float) -> StdState:
	return _parent


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## Emits `transition_requested` to tell the owning `StdStateMachine` to transition to
## the target state. Returns `null` so that callers can write
## `return _transition_to(path)` in lifecycle methods.
func _transition_to(next: NodePath) -> StdState:
	transition_requested.emit(next)
	return null
