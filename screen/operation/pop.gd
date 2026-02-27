##
## screen/operation/pop.gd
##
## Implements the pop, pop_to, and pop_to_depth operations for the screen manager.
##

extends "operation.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Pop := preload("res://screen/operation/pop.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _depth: int
var _transition: StdScreenTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create constructs a pop operation to the given target depth.
static func create(depth: int, transition: StdScreenTransition = null) -> RefCounted:
	var op = Pop.new()
	op._depth = depth
	op._transition = transition
	return op


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _execute(manager: StdScreenManager, done: Callable) -> void:
	# Pop intermediate screens instantly (no transition - industry standard approach).
	while manager._stack.size() > _depth + 1:
		@warning_ignore("confusable_local_declaration")
		var screen: StdScreen = manager._stack[-1]
		@warning_ignore("confusable_local_declaration")
		var scene: Node = manager._scenes[screen]

		screen.exiting.emit(scene)
		manager.screen_exiting.emit(screen, scene)
		manager._unmount_scene(screen, scene)

	if manager._stack.size() <= _depth:
		done.call()
		return

	# Pop the last screen with optional transition.
	var screen: StdScreen = manager._stack[-1]
	var scene: Node = manager._scenes[screen]

	screen.exiting.emit(scene)
	manager.screen_exiting.emit(screen, scene)

	var transition := manager._resolve_transition(screen, _transition, &"pop")

	if transition == null:
		manager._unmount_scene(screen, scene)
		done.call()
		return

	# Transition pop — one-shot handler, no coroutine await.
	var tx := transition.duplicate()
	var tx_ctx := StdScreenTransitionContext.new(manager)
	tx_ctx.current_scene = scene

	tx_ctx._unmount_fn = (func() -> void: manager._unmount_scene(screen, scene))

	tx_ctx.finished.connect(
		func() -> void:
			manager._active_transition = null
			manager._active_context = null

			if transition.block_input:
				manager._unblock_input()

			done.call(),
		CONNECT_ONE_SHOT,
	)

	if transition.block_input:
		manager._block_input()

	manager._active_transition = tx
	manager._active_context = tx_ctx

	tx.pop(tx_ctx)
