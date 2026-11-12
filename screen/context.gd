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


## _mount resolves the entering scene, if a resolver is set, and adds it to the scene
## tree through the mount function, which also builds each screen kept in the tree that
## the entering screen depends on. It does nothing without a mount function, and never
## loads.
##
## NOTE: A resolver returning `null` skips the mount and suppresses the unmount, keeping
## the existing scene, then calls `done()` to abort the operation.
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
