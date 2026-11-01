##
## std/test/screen_manager.gd
##
## StdTestScreenManager is a `StdScreenManager` for a GUT test, so a scene that reaches
## the stack through its ancestors runs as it does in a game.
##
## A test adds a `StdInputCursor` to the tree, as any manager requires, then this node,
## and awaits `push_and_wait`.
##
## NOTE: A headless root stays 64x64 unless `StdTestInput` sizes it, so a test which
## clicks a scene or reads its layout mounts this node with that helper before pushing.
##

class_name StdTestScreenManager
extends StdScreenManager

# -- DEFINITIONS --------------------------------------------------------------------- #

## _TIMEOUT_MSEC bounds the wait for a transition, so one that never finishes fails its
## test instead of hanging the run.
const _TIMEOUT_MSEC := 10000

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## push_and_wait pushes `screen`, and returns its scene once its enter transition has
## finished and the scene's layout has settled. The arguments are those of `push`, so a
## bare `StdScreenTransition.new()` runs no transition.
##
## NOTE: An empty screen sits under the first one pushed, because a manager won't pop
## its bottom screen, and `get_depth()` counts it.
func push_and_wait(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> Node:
	assert(is_node_ready(), "invalid state: not in the tree")

	push(screen, instance, transition)

	# NOTE: A failed load never emits `screen_entered`, so wait on the operation. A loop
	# on `process_frame` keeps running for a scene that pauses the tree, unlike GUT's
	# `wait_until`.
	var tree := get_tree()
	var deadline := Time.get_ticks_msec() + _TIMEOUT_MSEC
	while _active_op and Time.get_ticks_msec() < deadline:
		await tree.process_frame

	assert(_active_op == null, "invalid state: transition didn't finish")

	var scene: Node = _scenes.get(screen)
	assert(scene, "invalid state: screen didn't mount")

	await tree.process_frame

	return scene


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(not initial, "invalid config: initial would sit under the empty screen")

	super()

	push(StdScreen.new(), Control.new())
