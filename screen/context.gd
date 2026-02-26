##
## screen/context.gd
##
## StdScreenTransitionContext is a mediator between screen operations and transitions.
## It provides lifecycle primitives (mount, unmount, swap), scene access, visual
## helpers, and a completion callback; recreated for each transition invocation.
##

class_name StdScreenTransitionContext
extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## finished is emitted when the transition completes normally. Operations connect a one-
## shot handler to receive completion; force-stop prevents emission by setting
## `_did_finish`.
signal finished

# -- INITIALIZATION ------------------------------------------------------------------ #

## current_scene is the scene on top before this operation (null if stack is empty).
var current_scene: Node = null

## entering_scene is the entering scene instance. Null for pop operations.
var entering_scene: Node = null

var _did_mount: bool = false
var _did_unmount: bool = false
var _did_finish: bool = false
var _manager: Node
var _mount_fn: Callable = Callable()
var _unmount_fn: Callable = Callable()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(manager: Node) -> void:
	_manager = manager


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create_tween creates a new Tween via the scene tree.
func create_tween() -> Tween:
	return _manager.get_tree().create_tween()


## done signals that the transition completed normally. Emits the `finished` signal.
func done() -> void:
	if _did_finish:
		return

	_did_finish = true
	finished.emit()


## mount adds the entering scene to the scene tree. This is a no-op if already mounted
## or if no mount function is set.
func mount() -> void:
	if _did_mount or not _mount_fn.is_valid():
		return

	_did_mount = true
	_mount_fn.call()


## pop_node removes a node from the manager without freeing it.
func pop_node(node: Node) -> void:
	if node.is_inside_tree() and node.get_parent() == _manager:
		_manager.remove_child(node)


## push_node adds a node as an internal-back child of the manager, rendering it on top
## of all regular children.
func push_node(node: Node) -> void:
	_manager.add_child(node, false, Node.INTERNAL_MODE_BACK)


## swap performs an atomic unmount and then mount.
func swap() -> void:
	unmount()
	mount()


## unmount removes the exiting scene from the scene tree. This is a no-op if already
## unmounted or if no unmount function is set.
func unmount() -> void:
	if _did_unmount or not _unmount_fn.is_valid():
		return

	_did_unmount = true
	_unmount_fn.call()
