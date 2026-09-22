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

# -- INITIALIZATION ------------------------------------------------------------------ #

var _host_count: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## setup initializes the resource, allowing things like signals to be connected. This
## must be called by each node hosting the expression, and paired with `teardown`. A
## resource shared by several nodes initializes on the first call only.
func setup() -> void:
	_host_count += 1
	if _host_count == 1:
		_setup()


## teardown cleans up the resource, allowing things like signals to be disconnected.
## This must be called by each node hosting the expression. A resource shared by several
## nodes cleans up once the last of them calls it.
func teardown() -> void:
	if _host_count == 0:
		assert(false, "invalid state; teardown without setup")
		return

	_host_count -= 1
	if _host_count == 0:
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
