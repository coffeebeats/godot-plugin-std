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

## force_allow is a convenience setting which forces this conditional node to be
## allowed, regardless of how the associated expressions evaluate. This property can be
## overruled by `force_block`.
@export var force_allow: bool = false

## expressions_allow is a list of expressions which, if *any* are true, allow the
## configured nodes to enter the scene.
@export var expressions_allow: Array[StdConditionExpression] = []

## expressions_allow_require_all changes the default `allow` evaluation behavior to
## require that all "allow" expressions must be enabled for the allow action to occur.
@export var expressions_allow_require_all: bool = false

@export_subgroup("Block ")

## force_block is a convenience setting which forces this conditional node to be
## blocked, regardless of how the associated expressions evaluate. This takes priority
## over `force_allow`.
@export var force_block: bool = false

## expressions_block is a list of expressions which, if *any* are true, block the
## configured nodes to enter the scene.
@export var expressions_block: Array[StdConditionExpression] = []

## expressions_block_require_all changes the default `block` evaluation behavior to
## require that all "block" expressions must be enabled for the block action to occur.
@export var expressions_block_require_all: bool = false

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_currently_allowed: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	for expression in expressions_allow:
		Signals.connect_safe(
			expression.value_changed,
			_on_expression_value_changed,
			CONNECT_REFERENCE_COUNTED
		)
		expression.setup()

	for expression in expressions_block:
		Signals.connect_safe(
			expression.value_changed,
			_on_expression_value_changed,
			CONNECT_REFERENCE_COUNTED
		)
		expression.setup()

	_evaluate()


func _exit_tree() -> void:
	for expression in expressions_allow:
		Signals.disconnect_safe(expression.value_changed, _on_expression_value_changed)
		expression.teardown()

	for expression in expressions_block:
		Signals.disconnect_safe(expression.value_changed, _on_expression_value_changed)
		expression.teardown()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _on_allow() -> void:
	pass


func _on_block() -> void:
	pass


func _should_trigger_allow_action_on_enter() -> bool:
	assert(false, "unimplemented")
	return false


func _should_trigger_block_action_on_enter() -> bool:
	assert(false, "unimplemented")
	return false


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _evaluate(is_entering: bool = true) -> void:
	var is_allowed := false if force_block else (true if force_allow else _is_allowed())

	if (
		is_allowed
		and (
			(not is_entering or _should_trigger_allow_action_on_enter())
			or not _is_currently_allowed
		)
	):
		_is_currently_allowed = true
		_on_allow()

	if (
		not is_allowed
		and (
			(not is_entering or _should_trigger_block_action_on_enter())
			or _is_currently_allowed
		)
	):
		_is_currently_allowed = false
		_on_block()


func _is_allowed() -> bool:
	if expressions_block:
		for expression in expressions_block:
			var allowed := expression.is_allowed()

			if not allowed and not expressions_block_require_all:
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
