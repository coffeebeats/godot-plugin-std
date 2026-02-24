##
## screen/context.gd
##
## StdScreenTransitionContext is a mediator between the screen manager and transitions.
## It provides lifecycle primitives (mount, unmount, swap), scene access, input blocking,
## and visual helpers. Created per-transition invocation.
##

class_name StdScreenTransitionContext
extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## scene_loaded is emitted when the entering scene finishes loading in the background.
## Only relevant for push-with-transition when the scene was not immediately available.
signal scene_loaded

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Controller := preload("manager/controller.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _BLOCKER_KEY is the retained node key for the shared input blocker.
const _BLOCKER_KEY := &"_std_transition_input_blocker"

# -- INITIALIZATION ------------------------------------------------------------------ #

## current_scene is the scene on top before this operation (null if stack empty).
var current_scene: Node = null

## entering_scene is the entering scene instance. Null for pop operations and before the
## scene finishes loading (when overlapping loading with transitions).
var entering_scene: Node = null

var _did_mount: bool = false
var _did_unmount: bool = false
var _manager: Node
var _on_done: Callable = Callable()

## _mount_fn is called by mount() to add the entering scene to the tree. Set by the
## manager before the transition starts.
var _mount_fn: Callable = Callable()

## _unmount_fn is called by unmount() to remove the exiting scene from the tree. Set by
## the manager before the transition starts.
var _unmount_fn: Callable = Callable()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(manager: Node) -> void:
	_manager = manager


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## allow_input removes the input blocker node, letting input through.
func allow_input() -> void:
	_remove_blocker()


## block_input pushes the input blocker node, swallowing all input. The blocker is
## retained for reuse across transitions and freed on manager teardown/reset.
func block_input() -> void:
	var blocker: Control = get_retained_node(_BLOCKER_KEY)

	if blocker and blocker.is_inside_tree():
		return

	if not blocker:
		blocker = _create_blocker()
		retain_node(_BLOCKER_KEY, blocker)

	_manager.add_child(blocker, false, Node.INTERNAL_MODE_BACK)


## create_tween creates a new Tween via the scene tree.
func create_tween() -> Tween:
	return _manager.get_tree().create_tween()


## done signals that the transition is complete. The manager emits entered, restores
## focus, removes the input blocker, and marks the operation finished.
func done() -> void:
	_remove_blocker()

	var cb := _on_done
	_on_done = Callable() # Clear to prevent double-calling.

	if cb.is_valid():
		cb.call()


## get_retained_node returns a previously retained node by key, or null if not found.
func get_retained_node(key: StringName) -> Node:
	return _manager._retained_nodes.get(key)


## has_retained_node returns whether a node is retained under the given key.
func has_retained_node(key: StringName) -> bool:
	return key in _manager._retained_nodes


## mount adds the entering scene to the scene tree. Noop for pop operations or if
## already mounted. If the entering scene is not yet loaded (overlapped with
## transition), defers until `scene_loaded` fires.
func mount() -> void:
	if _did_mount or not _mount_fn.is_valid():
		return

	if entering_scene == null:
		if not scene_loaded.is_connected(_complete_mount):
			scene_loaded.connect(_complete_mount, CONNECT_ONE_SHOT)
		return

	_did_mount = true
	_mount_fn.call()


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


## swap performs an atomic unmount + mount. For push: equivalent to mount(). For pop:
## equivalent to unmount(). For replace: both in one call.
func swap() -> void:
	unmount()
	mount()


## unmount removes the exiting scene from the scene tree and tears it down. Noop for
## push operations or if already unmounted.
func unmount() -> void:
	if _did_unmount or not _unmount_fn.is_valid():
		return

	_did_unmount = true
	_unmount_fn.call()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _complete_mount retries mount() after scene_loaded fires.
func _complete_mount() -> void:
	mount()


## _create_blocker creates a transparent full-rect `Control` that swallows all input.
func _create_blocker() -> Control:
	var ctrl := _InputBlocker.new()
	ctrl.name = &"TransitionInputBlocker"
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	return ctrl


## _remove_blocker removes the input blocker from the tree if present. The node remains
## retained for reuse by future transitions.
func _remove_blocker() -> void:
	var blocker: Control = get_retained_node(_BLOCKER_KEY)
	if blocker and blocker.is_inside_tree():
		blocker.get_parent().remove_child(blocker)


## _InputBlocker is a `Control` that swallows all input events.
class _InputBlocker:
	extends Control

	func _input(_event: InputEvent) -> void:
		get_viewport().set_input_as_handled()
