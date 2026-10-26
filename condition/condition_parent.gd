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
## conditions are not met. A removed internal node returns with its internal mode,
## except that one removed while no regular child is present returns to the front.
@export var include_internal: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

var _children: Array[Node] = []
var _internal_modes: Dictionary[Node, InternalMode] = {}

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	_logger = _logger.named(&"std/condition/target")

	# NOTE: Children held out of the tree stay in `_children` while the condition is
	# outside it, as in a cached screen, so entering adds them back once allowed.
	for child in get_children(include_internal):
		if child not in _children:
			_children.append(child)

	super._enter_tree()


func _notification(what: int) -> void:
	# NOTE: Children held out of the tree are freed with the condition, and before
	# Godot reports orphans at quit, so none is leaked.
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
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

			var mode: InternalMode = _internal_modes.get(child, INTERNAL_MODE_DISABLED)
			_internal_modes.erase(child)

			add_child(child, false, mode)


func _on_block() -> void:
	# NOTE: Godot exposes no getter for a child's internal mode, so it's inferred from the
	# child's place: `get_children(true)` lists front internal children, then regular
	# ones, then back internal ones. With no regular child present, an internal child is
	# counted as front, which keeps the order the children return in.
	var regular := get_children()
	var is_after_regular := false

	for child in get_children(include_internal):
		assert(child in _children, "invalid state; found unknown child node")

		if child in regular:
			is_after_regular = true
		else:
			_internal_modes[child] = (
				INTERNAL_MODE_BACK if is_after_regular else INTERNAL_MODE_FRONT
			)

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


## _free_removed_children frees children that were removed from the tree by `_on_block`
## and stops tracking them.
func _free_removed_children() -> void:
	var kept: Array[Node] = []

	for child in _children:
		if not is_instance_valid(child):
			continue

		if is_ancestor_of(child):
			kept.append(child)
		elif not child.is_queued_for_deletion():
			child.free()

	_children = kept

	# NOTE: Only held-out children have a recorded mode, and none of them stays tracked.
	_internal_modes.clear()
