##
## std/screen/context.gd
##
## StdScreenTransitionContext is the transition context for operations on the screen
## stack. Mounting resolves a scene and adds it under the manager, input blocking covers
## the whole viewport, and a tween is bound to the manager rather than a scene.
##

class_name StdScreenTransitionContext
extends StdTransitionContext

# -- INITIALIZATION ------------------------------------------------------------------ #

## current_scene is the scene on top before this operation (null if stack is empty). A
## push leaves it mounted, so it's distinct from `exiting`.
var current_scene: Node = null

## manager is the screen manager node that owns this transition context.
var manager: StdScreenManager

var _mount_fn: Callable = Callable()
var _resolver: Callable = Callable()
var _unmount_fn: Callable = Callable()

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## mount_overlay adds a node over the manager's scenes, such as a curtain.
func mount_overlay(overlay: Node) -> void:
	manager.add_child(overlay, false, Node.INTERNAL_MODE_BACK)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(node: StdScreenManager) -> void:
	assert(node is StdScreenManager, "invalid argument; missing manager")
	super(node)
	manager = node


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _block_input covers the viewport through the manager's blocker.
func _block_input() -> void:
	manager._block_input()


## _mount adds the entering scene to the scene tree. This is a no-op if no mount
## function is set. If a resolver is set, it is called first to resolve the scene: a
## kept or passed instance, or one instantiated from a scene the operation loaded
## before it started, so mounting never loads. The mount function then builds each
## screen kept in the tree that the entering screen depends on, so all building happens
## in this one call.
##
## NOTE: If the resolver returns `null` (failed instantiation), the mount is skipped,
## unmount is suppressed (to preserve the existing scene), and `done()` is called to
## abort the operation gracefully.
func _mount() -> void:
	if not _mount_fn.is_valid():
		return

	if _resolver.is_valid():
		entering = _resolver.call()
		if entering == null:
			_did_unmount = true
			done()
			return

	_mount_fn.call(entering)


## _unblock_input removes the manager's blocker.
func _unblock_input() -> void:
	manager._unblock_input()


## _unmount removes the exiting scene from the scene tree. This is a no-op if no unmount
## function is set.
func _unmount() -> void:
	if _unmount_fn.is_valid():
		_unmount_fn.call()
