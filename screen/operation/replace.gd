##
## screen/operation/replace.gd
##
## Implements the replace operation for the screen manager.
##

extends "operation.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Replace := preload("replace.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _instance: Node
var _screen: StdScreen
var _transition: StdScreenTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create constructs a replace operation.
static func create(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> RefCounted:
	var op = Replace.new()
	op._screen = screen
	op._instance = instance
	op._transition = transition
	return op

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _execute(manager: StdScreenManager, done: Callable) -> void:
	# Reject duplicate (non-self) replace.
	if _screen in manager._stack and manager._stack[-1] != _screen:
		manager._logger.warn("Duplicate replace ignored; screen already in stack.")
		done.call()
		return

	var screen_prev: StdScreen = manager._stack[-1]
	var scene_prev: Node = manager._scenes[screen_prev]

	# Capture the overlay for transfer when both screens own theirs. If
	# the old screen was sharing an overlay, teardown handles cleanup
	# normally so the shared overlay stays with its original owner.
	var overlay_prev: StdScreenOverlay = null
	if screen_prev.block_input_below and _screen.block_input_below:
		overlay_prev = (manager._overlays.get_overlay(screen_prev))

	# Resolve entering scene.
	var scene: Node = await manager._resolve_scene(_screen, _instance)

	# Load preload dependencies.
	await manager._resolve_preloads(_screen)

	screen_prev.exiting.emit(scene_prev)
	manager.screen_exiting.emit(screen_prev, scene_prev)

	var transition := manager._resolve_transition(_screen, _transition)

	if transition == null:
		# Instant replace: teardown old, mount new.
		manager._stack.pop_back()
		manager._scenes.erase(screen_prev)
		if is_instance_valid(overlay_prev):
			manager._overlays.erase(screen_prev)
		manager._teardown_scene(screen_prev, scene_prev)

		if is_instance_valid(overlay_prev):
			manager._overlays.register(_screen, overlay_prev)
		manager._mount_scene(_screen, scene)

		manager._overlays.free_if_unused(overlay_prev)

		_screen.entered.emit(scene)
		manager.screen_entered.emit(_screen, scene)
		manager._restore_focus(scene)
		done.call()
		return

	# Transition replace — one-shot handler, no coroutine await.
	var tx := transition.duplicate()
	var tx_ctx := StdScreenTransitionContext.new(manager)
	tx_ctx.current_scene = scene_prev
	tx_ctx.entering_scene = scene

	tx_ctx._unmount_fn = func() -> void:
		manager._stack.pop_back()
		manager._scenes.erase(screen_prev)
		if is_instance_valid(overlay_prev):
			manager._overlays.erase(screen_prev)
		manager._teardown_scene(screen_prev, scene_prev)

	tx_ctx._mount_fn = func() -> void:
		if is_instance_valid(overlay_prev):
			manager._overlays.register(_screen, overlay_prev)
		manager._mount_scene(_screen, scene)

	tx_ctx.finished.connect(
		func() -> void:
			manager._active_transition = null
			manager._active_context = null

			if transition.block_input:
				manager._unblock_input()

			manager._overlays.free_if_unused(overlay_prev)

			_screen.entered.emit(scene)
			manager.screen_entered.emit(_screen, scene)
			manager._restore_focus(scene)
			done.call(),
		CONNECT_ONE_SHOT,
	)

	if transition.block_input:
		manager._block_input()

	manager._active_transition = tx
	manager._active_context = tx_ctx

	tx.replace(tx_ctx)
