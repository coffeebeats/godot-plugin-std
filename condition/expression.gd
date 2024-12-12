##
## std/condition/expression.gd
##
## StdConditionExpression is an abstract base class for a resource which defines a
## boolean expression to evaluate. The result of evaluation will be used by an
## `StdCondition`-dervice node to determine whether certain nodes may enter the scene.
##

class_name StdConditionExpression
extends Resource

# -- SIGNALS ------------------------------------------------------------------------- #

## value_changed is emitted when the expression's value has changed.
@warning_ignore("UNUSED_SIGNAL")
signal value_changed(is_allowed: bool)

# -- PUBLIC METHODS ------------------------------------------------------------------ #

## setup initializes the resource, allowing things like signals to be connected. This
## must be called by the node hosting the expression.
func setup() -> void:
	_setup()

	value_changed.emit(is_allowed())

## teardown cleans up the resource, allowing things like signals to be disconnected.
## This must be called by the node hosting the expression.
func teardown() -> void:
	_teardown()

## is_allowed returns whether the condition expression evaluates successfully,
## determining whether the associated nodes should be allowed to enter the scene tree.
func is_allowed() -> bool:
	return _is_allowed()

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _is_allowed() -> bool:
	assert(false, "unimplemented")
	return false

func _setup() -> void:
	pass

func _teardown() -> void:
	pass