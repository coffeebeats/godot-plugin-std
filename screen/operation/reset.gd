##
## screen/operation/reset.gd
##
## Implements the reset operation for the screen manager. Tears down all screens and
## pushes a new base.
##

extends "operation.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Reset := preload("reset.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _instance: Node
var _screen: StdScreen
var _transition: StdScreenTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create constructs a reset operation.
static func create(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> RefCounted:
	var op = Reset.new()
	op._screen = screen
	op._instance = instance
	op._transition = transition
	return op


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _execute(manager: StdScreenManager, done: Callable) -> void:
	# Teardown all existing scenes in reverse order.
	for i in range(manager._stack.size() - 1, -1, -1):
		var s: StdScreen = manager._stack[i]
		var sc: Node = manager._scenes.get(s)
		if sc and is_instance_valid(sc):
			s.exiting.emit(sc)
			manager.screen_exiting.emit(s, sc)
			manager._teardown_scene(s, sc)

	manager._stack.clear()
	manager._scenes.clear()
	manager._focus.clear()
	manager._overlays.clear()
	manager._preloads.clear()

	manager._resolve_scene(
		_screen,
		_instance,
		func(scene: Node) -> void:
			manager._resolve_preloads(
				_screen,
				func() -> void: _do_reset(manager, scene, done),
			),
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _do_reset(manager: StdScreenManager, scene: Node, done: Callable) -> void:
	var transition := manager._resolve_transition(_screen, _transition, &"push")

	if transition == null:
		# Instant reset (no transition).
		manager._mount_scene(_screen, scene)
		_screen.entered.emit(scene)
		manager.screen_entered.emit(_screen, scene)
		manager._restore_focus(scene)
		done.call()
		return

	# Transition reset — uses push transition since reset is "clear + push."
	var tx := transition.duplicate()
	var tx_ctx := StdScreenTransitionContext.new(manager)
	tx_ctx.current_scene = null
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
			done.call(),
		CONNECT_ONE_SHOT,
	)

	if transition.block_input:
		manager._block_input()

	manager._active_transition = tx
	manager._active_context = tx_ctx

	tx.push(tx_ctx)
