##
## std/test/screen.gd
##
## StdTestScreen mounts a screen under a `StdScreenManager` in a GUT test, so a scene
## that reaches the stack through its ancestors runs as it does in a game.
##
## A GUT test awaits `mount`, drives the scene through `input` and reads the stack from
## `manager`. GUT frees this node after the test, which tears the stack down.
##
## NOTE: This mounts through `StdTestInput.mount`, so it requires `--headless`, and a
## test calls one or the other, once.
##

class_name StdTestScreen
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

## _TIMEOUT_MSEC bounds the wait for a transition, so one that never finishes fails its
## test instead of hanging the run.
const _TIMEOUT_MSEC := 10000

# -- INITIALIZATION ------------------------------------------------------------------ #

## input sends events to the mounted scene and to whatever it pushes.
var input: StdTestInput = null

## manager is the stack holding the mounted scene.
var manager: StdScreenManager = null

## scene is the mounted scene.
var scene: Node = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## mount pushes `screen` onto a new manager, and returns once its enter transition has
## finished and the scene's layout has settled. `test` is the calling `GutTest`, which
## frees the returned node when the test ends. `instance` and `transition` are those of
## `StdScreenManager.push`, so a bare `StdScreenTransition.new()` runs no transition.
##
## NOTE: An empty screen sits under `screen`, because a manager won't pop its bottom
## screen, and `manager.get_depth()` counts it.
##
## NOTE: A `StdInputCursor` already in the tree serves the manager. Without one, this
## adds its own.
static func mount(
	test: Node,
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> StdTestScreen:
	var mounted := StdTestScreen.new()

	if StdGroup.is_empty(StdInputCursor.GROUP_INPUT_CURSOR):
		mounted.add_child(StdInputCursor.new())

	mounted.manager = StdScreenManager.new()
	mounted.add_child(mounted.manager)

	mounted.input = await StdTestInput.mount(test, mounted)

	mounted.manager.push(StdScreen.new(), Control.new())
	mounted.manager.push(screen, instance, transition)

	# NOTE: A failed load never emits `screen_entered`, so wait on the operation. A loop
	# on `process_frame` keeps running for a scene that pauses the tree, unlike GUT's
	# `wait_until`.
	var tree := test.get_tree()
	var deadline := Time.get_ticks_msec() + _TIMEOUT_MSEC
	while mounted.manager._active_op and Time.get_ticks_msec() < deadline:
		await tree.process_frame

	assert(
		mounted.manager._active_op == null, "invalid state: transition didn't finish"
	)

	mounted.scene = mounted.manager._scenes.get(screen)
	assert(mounted.scene, "invalid state: screen didn't mount")

	await tree.process_frame

	return mounted
