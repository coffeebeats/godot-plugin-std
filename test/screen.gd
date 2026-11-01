##
## std/test/screen.gd
##
## StdTestScreen holds a `StdScreenManager` in a GUT test, so a scene that reaches the
## stack through its ancestors runs as it does in a game.
##
## A test adds this node to the tree, awaits `push` and reads the stack from `manager`.
## Freeing this node tears the stack down. A `StdInputCursor` already in the tree serves
## the manager; without one, this node adds its own.
##
## NOTE: A headless root stays 64x64 unless `StdTestInput` sizes it, so a test which
## clicks a scene or reads its layout mounts this node with that helper before pushing.
##

class_name StdTestScreen
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

## _TIMEOUT_MSEC bounds the wait for a transition, so one that never finishes fails its
## test instead of hanging the run.
const _TIMEOUT_MSEC := 10000

# -- INITIALIZATION ------------------------------------------------------------------ #

## manager is the stack this node holds, available once this node is in the tree.
var manager: StdScreenManager = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## push pushes `screen` onto `manager`, and returns its scene once its enter transition
## has finished and the scene's layout has settled. The arguments are those of
## `StdScreenManager.push`, so a bare `StdScreenTransition.new()` runs no transition.
##
## NOTE: An empty screen sits under the first one pushed, because a manager won't pop
## its bottom screen, and `manager.get_depth()` counts it.
func push(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> Node:
	assert(is_node_ready(), "invalid state: not in the tree")

	manager.push(screen, instance, transition)

	# NOTE: A failed load never emits `screen_entered`, so wait on the operation. A loop
	# on `process_frame` keeps running for a scene that pauses the tree, unlike GUT's
	# `wait_until`.
	var tree := get_tree()
	var deadline := Time.get_ticks_msec() + _TIMEOUT_MSEC
	while manager._active_op and Time.get_ticks_msec() < deadline:
		await tree.process_frame

	assert(manager._active_op == null, "invalid state: transition didn't finish")

	var scene: Node = manager._scenes.get(screen)
	assert(scene, "invalid state: screen didn't mount")

	await tree.process_frame

	return scene


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	if StdGroup.is_empty(StdInputCursor.GROUP_INPUT_CURSOR):
		add_child(StdInputCursor.new())

	manager = StdScreenManager.new()
	add_child(manager)

	manager.push(StdScreen.new(), Control.new())
