##
## std/feature/condition.gd
##
## StdCondition is an abstract base class for nodes which conditionally place target
## nodes within the scene.
##

class_name StdCondition
extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Expressions")

@export_subgroup("Allow ")

## expressions_allow is a list of expressions which, if *any* are true, allow the
## configured nodes to enter the scene.
@export var expressions_allow: Array[StdConditionExpression] = []

## expressions_allow_require_all changes the default `allow` evaluation behavior to
## require that all "allow" expressions must be enabled for the allow action to occur.
@export var expressions_allow_require_all: bool = false

@export_subgroup("Block ")

## expressions_block is a list of expressions which, if *any* are true, block the
## configured nodes to enter the scene.
@export var expressions_block: Array[StdConditionExpression] = []

## expressions_block_require_all changes the default `block` evaluation behavior to
## require that all "block" expressions must be enabled for the block action to occur.
@export var expressions_block_require_all: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	for expression in expressions_allow:
		Signals.connect_safe(expression.value_changed, _on_expression_value_changed)
		expression.setup()

	for expression in expressions_block:
		Signals.disconnect_safe(expression.value_changed, _on_expression_value_changed)
		expression.setup()

	_evaluate()


func _exit_tree() -> void:
	for expression in expressions_allow:
		expression.teardown()

	for expression in expressions_block:
		expression.teardown()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _on_allow() -> void:
	pass


func _on_block() -> void:
	pass


func _should_trigger_allow_action_on_enter() -> bool:
	assert(false, "unimplemented")
	return false


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _evaluate(is_entering: bool = true) -> void:
	if not _is_allowed():
		_on_block()
	elif not is_entering or _should_trigger_allow_action_on_enter():
		_on_allow()


func _is_allowed() -> bool:
	if expressions_block:
		for expression in expressions_block:
			var allowed := expression.is_allowed()

			if allowed and not expressions_block_require_all:
				return false

			if not allowed and expressions_block_require_all:
				break

	if expressions_allow:
		var all_allowed := true

		for expression in expressions_allow:
			var allowed := expression.is_allowed()
			all_allowed = all_allowed and allowed

			if allowed and not expressions_allow_require_all:
				return true

			if expressions_allow_require_all and not all_allowed:
				return false

		return all_allowed

	return false


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_expression_value_changed(_enabled: bool) -> void:
	_evaluate(false)
