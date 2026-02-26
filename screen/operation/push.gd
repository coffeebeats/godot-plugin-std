##
## screen/operation/push.gd
##
## Implements the push operation for the screen manager.
##

extends "operation.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Push := preload("push.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _instance: Node
var _screen: StdScreen
var _transition: StdScreenTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create constructs a push operation for the given screen.
static func create(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> RefCounted:
	var op = Push.new()
	op._screen = screen
	op._instance = instance
	op._transition = transition
	return op


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _execute(manager: StdScreenManager, done: Callable) -> void:
	# Validate: no duplicates in stack.
	if _screen in manager._stack:
		(
			manager
			._logger
			.warn(
				"Duplicate push ignored;" + " screen already in stack.",
			)
		)
		done.call()
		return

	var previous := manager._current_scene()

	# Resolve scene (await if async load needed).
	var scene: Node = await (
		manager
		._resolve_scene(
			_screen,
			_instance,
		)
	)

	# Load preload dependencies.
	await manager._resolve_preloads(_screen)

	manager._save_focus(previous)

	var transition: StdScreenTransition = (
		manager
		._resolve_transition(
			_screen,
			_transition,
		)
	)

	if transition == null:
		# Instant push.
		manager._mount_scene(_screen, scene)

		_screen.entered.emit(scene)
		manager.screen_entered.emit(_screen, scene)
		manager._restore_focus(scene)

		_emit_covered(manager, previous)
		done.call()
		return

	# Transition push — one-shot handler, no coroutine await.
	var tx := transition.duplicate()
	var tx_ctx := StdScreenTransitionContext.new(manager)
	tx_ctx.current_scene = previous
	tx_ctx.entering_scene = scene

	tx_ctx._mount_fn = (func() -> void: manager._mount_scene(_screen, scene))

	tx_ctx.finished.connect(
		func() -> void:
			manager._active_transition = null
			manager._active_context = null

			if transition.block_input:
				manager._unblock_input()

			_screen.entered.emit(scene)
			manager.screen_entered.emit(_screen, scene)
			manager._restore_focus(scene)

			_emit_covered(manager, previous)
			done.call(),
		CONNECT_ONE_SHOT,
	)

	if transition.block_input:
		manager._block_input()

	manager._active_transition = tx
	manager._active_context = tx_ctx

	tx.push(tx_ctx)
