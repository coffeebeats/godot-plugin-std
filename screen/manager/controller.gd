##
## screen/manager/controller.gd
##
## Manages transition lifecycle and input blocking for the screen manager. Input blocking
## uses reference counting; the controller directly toggles the topmost overlay's process
## mode, bypassing the manager's signal handlers.
##

extends RefCounted

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../../event/signal.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

## _active_transitions tracks all in-flight transitions so they can be stopped on
## interruption.
var _active_transitions: Array[StdScreenTransition] = []

## _cancel_cleanup maps in-flight transitions to cleanup callables that run when the
## transition is stopped (prevents leaking exit scenes).
var _cancel_cleanup: Dictionary[StdScreenTransition, Callable] = {}

## _input_block_count tracks how many transitions are currently blocking scene input.
## Input is only re-enabled when the count reaches zero, preventing a race where an
## earlier-completing transition unblocks input while another is still running.
var _input_block_count: int = 0

## _manager is the Node used to create StdScreenTransitionContext instances.
var _manager: Node

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(manager: Node) -> void:
	_manager = manager


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## allow_input decrements the input block reference count. When the count reaches zero,
## the topmost overlay is re-enabled.
func allow_input() -> void:
	_input_block_count = maxi(0, _input_block_count - 1)
	if _input_block_count == 0:
		_unblock_overlay()


## block_input increments the input block reference count. On the 0-to-1 transition, the
## topmost overlay is disabled.
func block_input() -> void:
	_input_block_count += 1
	if _input_block_count != 1:
		return

	var overlay: Node = _manager._get_current_overlay()
	if overlay:
		overlay.process_mode = Node.PROCESS_MODE_DISABLED


## run_enter starts an enter transition and calls the callback when complete (or
## immediately if non-blocking or no transition).
func run_enter(
	screen: StdScreen,
	scene: Node,
	on_complete: Callable,
) -> void:
	var transition := screen.transition_enter
	if transition == null:
		if on_complete.is_valid():
			on_complete.call()

		return

	_active_transitions.append(transition)

	var cleanup := func() -> void:
		_active_transitions.erase(transition)
		if screen.block_on_enter:
			if on_complete.is_valid():
				on_complete.call()

	var context := StdScreenTransitionContext.new(_manager, self)
	(
		Signals
		. connect_safe(
			transition.completed,
			cleanup,
			CONNECT_ONE_SHOT,
		)
	)

	transition.start(context, scene, true)

	if not screen.block_on_enter:
		if on_complete.is_valid():
			on_complete.call()


## run_exit handles an exit transition and scene cleanup. The teardown callable is
## called on completion (or on interruption via stop_all).
func run_exit(
	screen: StdScreen,
	scene: Node,
	teardown: Callable,
	on_complete: Callable,
) -> void:
	var transition: StdScreenTransition = screen.transition_exit

	if transition == null:
		teardown.call()

		if on_complete.is_valid():
			on_complete.call()

		return

	_active_transitions.append(transition)

	_cancel_cleanup[transition] = teardown

	var cleanup := func() -> void:
		_active_transitions.erase(transition)
		_cancel_cleanup.erase(transition)
		teardown.call()

		if screen.block_on_exit:
			if on_complete.is_valid():
				on_complete.call()

	var context := StdScreenTransitionContext.new(_manager, self)
	(
		Signals
		. connect_safe(
			transition.completed,
			cleanup,
			CONNECT_ONE_SHOT,
		)
	)

	transition.start(context, scene, false)

	if not screen.block_on_exit:
		if on_complete.is_valid():
			on_complete.call()


## stop_all stops all in-flight transitions. Transitions with `reset_on_interrupt`
## restore their visual state; others freeze for handoff. When `force_reset` is true,
## all transitions are reset regardless of their `reset_on_interrupt` setting, and
## `cancel_cleanup` callbacks are skipped (the caller handles all teardowns itself).
func stop_all(force_reset: bool = false) -> void:
	for transition in _active_transitions.duplicate():
		for connection in transition.completed.get_connections():
			(
				Signals
				. disconnect_safe(
					transition.completed,
					connection["callable"],
				)
			)

		if force_reset or transition.reset_on_interrupt:
			transition.reset()
		else:
			transition.stop()

		# Skip `cancel_cleanup` when force-resetting — the caller (`_reset_impl`)
		# handles all teardowns itself, avoiding double lifecycle signals.
		if not force_reset and transition in _cancel_cleanup:
			_cancel_cleanup[transition].call()

	_active_transitions.clear()
	_cancel_cleanup.clear()
	_input_block_count = 0
	_unblock_overlay()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _unblock_overlay re-enables the topmost overlay and notifies the manager that
## transitions have settled.
func _unblock_overlay() -> void:
	var overlay: Node = _manager._get_current_overlay()
	if overlay:
		overlay.process_mode = Node.PROCESS_MODE_INHERIT

	_manager._on_transitions_settled()
