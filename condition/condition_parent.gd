##
## std/feature/condition_parent.gd
##
## StdConditionParent is an implementation of `StdCondition` which conditionally allows
## its children to enter the scene tree based on the configured expressions.
##

class_name StdConditionParent
extends StdCondition

# -- CONFIGURATION ------------------------------------------------------------------- #

## include_internal determines whether to remove internal nodes from the scene tree when
## conditions are not met.
@export var include_internal: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

var _children: Array[Node] = []

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	_logger = _logger.named(&"std/condition/target")

	_children = get_children()
	super._enter_tree()


func _exit_tree() -> void:
	_free_removed_children()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_free_removed_children()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _on_allow() -> void:
	for child in _children:
		if not is_ancestor_of(child):
			(
				_logger
				. debug(
					"Adding child to scene.",
					{&"parent": get_parent().get_path(), &"node": child.name},
				)
			)

			add_child(child, false)


func _on_block() -> void:
	for child in get_children(include_internal):
		assert(child in _children, "invalid state; found unknown child node")

		if is_ancestor_of(child):
			(
				_logger
				. debug(
					"Removing child from scene.",
					{&"parent": get_parent().get_path(), &"node": child.name},
				)
			)

			remove_child(child)


func _should_trigger_allow_action_on_enter() -> bool:
	return false  # No need to add nodes which will already enter the scene.


func _should_trigger_block_action_on_enter() -> bool:
	return true


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _free_removed_children frees children that were removed from the tree by `_on_block`.
func _free_removed_children() -> void:
	for child in _children:
		if child and not is_ancestor_of(child) and not child.is_queued_for_deletion():
			child.free()

	_children.clear()
