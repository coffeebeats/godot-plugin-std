##
## std/fsm/state.gd
##
## State is a base class for state nodes within a Hierarchical State Machine.
##
## Create new states by inheriting from this script and implementing the interface. Each
## state should be used as a child of a 'StateMachine' node or a parent 'State'. The
## 'StateMachine' node will be responsible for tracking states and delegating behavior.
##
## Example scene tree:
##
## PlayerMovement (StateMachine)
## 	'-> Ground (State - parent)
## 		'-> Idle (State - leaf)
## 		'-> Run (State - leaf)
## 		'-> Jump (State - leaf)
## 	'-> Air (State - parent)
## 		'-> Jump (State - leaf)
## 	'-> Roll (State - leaf)

@icon("../editor/icons/state.svg")
extends Object

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

const StateMachine := preload("state_machine.gd")
const State := preload("state.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

# -- INITIALIZATION ------------------------------------------------------------------ #

## A pointer to the 'State' node which directly parents this 'State'; will be 'null'
## if this 'State' is directly parented by the 'StateMachine'.
var _parent: State

## The path to this 'State' from the root 'StateMachine'.
@warning_ignore("unused_private_class_variable")
var _path: NodePath

## A pointer to the 'StateMachine' node this 'State' is attached to.
var _root: StateMachine

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## Returns whether or not this 'State' is a descendant of the specified 'State'.
##
## @args:
## 	state - the state to check for ancestry with.
func is_substate_of(other: State) -> bool:
	var next: State = self
	while next:
		if next == other:
			return true

		next = next._parent

	return false


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## A virtual method called when this state is entered (after exiting previous state).
##
## NOTE: This method *can* be overridden to customize behavior for the 'State' node.
##
## NOTE: If this 'State' is a derived 'State' node, then this 'enter' method is
## called *after* to the parent 'State' node's 'enter' method.
##
## @args:
## 	previous - the 'State' node being transitioned *from*
func _on_enter(_previous: State) -> void:
	pass


## A virtual method called when leaving this state (prior to entering next state).
##
## NOTE: This method *can* be overridden to customize behavior for the 'State' node.
##
## NOTE: If this 'State' is a derived 'State' node, then this 'exit' method is called
## *prior* to the parent 'State' node's 'exit' method.
##
## @args:
## 	next - the 'State' node being transitioned *to*
func _on_exit(_next: State) -> void:
	pass


## A virtual method called to process 'StateMachine' input for the current frame.
##
## NOTE: This method *can* be overridden to customize behavior for the 'State' node.
##
## NOTE: This method should either return 'null', meaning the input has been
## handled, or a reference to a parent 'State'. Returning a reference delegates
## handling of the input from the current 'State' to the parent 'State'. If
## there is no parent 'State' (i.e. this is a "top" 'State' node) then the
## input is effectively dropped.
##
## @args:
## 	input - the 'StateMachine' input to process
func _on_input(_event) -> State:
	return _parent


## A virtual method called to process a frame/tick, given the frame time 'delta'.
##
## NOTE: This method *can* be overridden to customize behavior for the 'State' node.
##
## NOTE: This method should either return 'null', meaning the frame/tick has been
## handled, or a reference to a parent 'State'. Returning a reference delegates
## handling of the frame/tick from the current 'State' to the parent 'State'. If
## there is no parent 'State' (i.e. this is a "top" 'State' node) then processing
## stops.
##
## @args:
##  delta - the elapsed time since the last update
func _on_update(_delta: float) -> State:
	return _parent


# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


###
# Used to communicate to the StateMachine that a transition should occur.
#
# NOTE: This method should always return 'null' so that child 'State' nodes can
# simply `return _transition_to(next)` within lifecycle methods.
#
# @args:
# 	next [NodePath] - the 'NodePath' (from root) of the next 'State' node.
##
func _transition_to(next: NodePath):
	_root._transition_to(next) # gdlint:ignore=private-method-call
	return null

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
