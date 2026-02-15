##
## screen/context.gd
##
## StdScreenTransitionContext is a mediator between the screen manager and transitions.
## It restricts what transitions can do with the manager and is created per-transition
## invocation.
##

class_name StdScreenTransitionContext
extends RefCounted

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Controller := preload("manager/controller.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _controller: Controller
var _manager: Node
var _on_done: Callable = Callable()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(manager: Node, controller: Controller) -> void:
	_controller = controller
	_manager = manager


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## allow_input re-enables input processing on the topmost scene overlay.
func allow_input() -> void:
	_controller.allow_input()


## block_input disables input processing on the topmost scene overlay.
func block_input() -> void:
	_controller.block_input()


## create_tween creates a new Tween via the scene tree.
func create_tween() -> Tween:
	return _manager.get_tree().create_tween()


## done notifies the controller that the transition has finished. Called by transition
## subclasses when their effect completes.
func done() -> void:
	var cb := _on_done
	_on_done = Callable()  # Clear to prevent double-calling.

	if cb.is_valid():
		cb.call()


## get_retained_node returns a previously retained node by key, or null if not found.
func get_retained_node(key: StringName) -> Node:
	return _manager._retained_nodes.get(key)


## has_retained_node returns whether a node is retained under the given key.
func has_retained_node(key: StringName) -> bool:
	return key in _manager._retained_nodes


## pop_node removes a node from the manager without freeing it.
func pop_node(node: Node) -> void:
	if node.is_inside_tree() and node.get_parent() == _manager:
		_manager.remove_child(node)


## pop_retained_node removes a retained node by key and returns it. The caller is
## responsible for freeing the returned node.
func pop_retained_node(key: StringName) -> Node:
	var node: Node = _manager._retained_nodes.get(key)
	_manager._retained_nodes.erase(key)
	return node


## push_node adds a node as an internal-back child of the manager, rendering it on top
## of all regular (scene overlay) children.
func push_node(node: Node) -> void:
	_manager.add_child(node, false, Node.INTERNAL_MODE_BACK)


## retain_node registers a node with the manager for cleanup on shutdown or reset, keyed
## by a transition-defined identifier.
func retain_node(key: StringName, node: Node) -> void:
	_manager._retained_nodes[key] = node
