##
## std/feature/condition_target2d.gd
##
## StdConditionTarget2D is an implementation of `StdCondition` which conditionally
## makes a set of target 2D nodes visible in the scene based on the configured
## expressions.
##

class_name StdConditionTarget2D
extends StdCondition

# -- CONFIGURATION ------------------------------------------------------------------- #

## targets is a list of target `CanvasItem` nodes which the configured expressions
## apply to.
@export var targets: Array[CanvasItem] = []

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	_logger = _logger.named(&"std/condition/target")
	super._enter_tree()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _on_allow() -> void:
	for target in targets:
		(
			_logger
			. debug(
				"Making node visible.",
				{&"parent": get_parent().get_path(), &"target": target},
			)
		)

		target.visible = true


func _on_block() -> void:
	for target in targets:
		(
			_logger
			. debug(
				"Hiding node.",
				{&"parent": get_parent().get_path(), &"target": target},
			)
		)

		target.visible = false


func _should_trigger_allow_action_on_enter() -> bool:
	return true


func _should_trigger_block_action_on_enter() -> bool:
	return true
