##
## screen/context.gd
##
## StdScreenTransitionContext is a mediator between the screen manager and transitions.
## It restricts what transitions can do with the manager and is created per-transition
## invocation.
##

class_name StdScreenTransitionContext
extends RefCounted

# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: Node

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(manager: Node) -> void:
	_manager = manager


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## allow_input re-enables input processing on the topmost scene overlay.
func allow_input() -> void:
	_manager._allow_scene_input()


## block_input disables input processing on the topmost scene overlay.
func block_input() -> void:
	_manager._block_scene_input()


## create_tween creates a new Tween via the scene tree.
func create_tween() -> Tween:
	return _manager.get_tree().create_tween()


## get_manager_meta returns the manager's metadata for the given key.
func get_manager_meta(
	key: StringName,
	default: Variant = null,
) -> Variant:
	return _manager.get_meta(key, default)


## has_manager_meta checks whether the manager has the given metadata key.
func has_manager_meta(key: StringName) -> bool:
	return _manager.has_meta(key)

## pop_node removes a node from the manager without freeing it.
func pop_node(node: Node) -> void:
	if node.is_inside_tree() and node.get_parent() == _manager:
		_manager.remove_child(node)


## push_node adds a node as an internal-back child of the manager, rendering it on top
## of all regular (scene overlay) children.
func push_node(node: Node) -> void:
	_manager.add_child(node, false, Node.INTERNAL_MODE_BACK)


## remove_manager_meta removes metadata from the manager node.
func remove_manager_meta(key: StringName) -> void:
	_manager.remove_meta(key)

## set_manager_meta sets metadata on the manager node.
func set_manager_meta(key: StringName, value: Variant) -> void:
	_manager.set_meta(key, value)
