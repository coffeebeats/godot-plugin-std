#gdlint:ignore=max-public-methods
##
## screen/manager.gd
##
## StdScreenManager is a pushdown automaton that manages a stack of screens.
## The bottom of the stack is the base scene and everything above is an
## overlay. The topmost screen always has focus.
##

class_name StdScreenManager
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## screen_entering is emitted after a screen's scene is mounted but before the
## enter transition starts.
signal screen_entering(screen: StdScreen, scene: Node)

## screen_entered is emitted after a screen's enter transition completes.
signal screen_entered(screen: StdScreen, scene: Node)

## screen_exiting is emitted before a screen's exit transition starts.
signal screen_exiting(screen: StdScreen, scene: Node)

## screen_exited is emitted after a screen's exit transition completes.
signal screen_exited(screen: StdScreen, scene: Node)

## screen_covered is emitted when another screen is pushed on top.
signal screen_covered(screen: StdScreen, scene: Node)

## screen_uncovered is emitted when a covering screen is popped.
signal screen_uncovered(screen: StdScreen, scene: Node)

## screen_pushed is emitted after a push operation completes.
signal screen_pushed(screen: StdScreen)

## screen_popped is emitted after a pop operation completes.
signal screen_popped(screen: StdScreen)

## screen_replaced is emitted after a replace operation completes.
signal screen_replaced(old: StdScreen, new: StdScreen)

# -- CONFIGURATION ------------------------------------------------------------------- #

## initial is the screen pushed onto the stack during _ready.
@export var initial: StdScreen

# -- INITIALIZATION ------------------------------------------------------------------ #

## _logger is the logger instance for this class.
static var _logger := StdLogger.create(&"std/screen/manager")  # gdlint:ignore=class-definitions-order,max-line-length

## _stack is the screen stack. Index 0 is the bottom (base scene).
var _stack: Array[StdScreen] = []

## _scenes maps each StdScreen to its instantiated scene node.
var _scenes: Dictionary = {}

## _focus maps scene nodes to their last-focused control.
var _focus: Dictionary = {}

## _active_transitions tracks all in-flight transitions so they can be
## cancelled on interruption.
var _active_transitions: Array[StdScreenTransition] = []

## _cancel_cleanup maps in-flight transitions to cleanup callables that
## run when the transition is cancelled (prevents leaking exit scenes).
var _cancel_cleanup: Dictionary = {}

## _is_operating is true while a navigation operation is executing.
var _is_operating: bool = false

## _loader is the background scene loader.
var _loader: StdScreenLoader = null

## _queue holds navigation callables deferred during reentrancy.
var _queue: Array[Callable] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## push adds a screen on top of the stack and gives it focus.
func push(screen: StdScreen, instance: Node = null) -> void:
	assert(screen != null, "invalid argument: missing screen")
	_enqueue_or_run(func(): _do_push(screen, instance))


## pop removes the topmost screen from the stack and returns
## focus to the new top.
func pop() -> void:
	assert(_stack.size() > 1, "cannot pop the last screen")
	_enqueue_or_run(_do_pop)


## replace swaps the topmost screen for a new one.
func replace(screen: StdScreen, instance: Node = null) -> void:
	assert(screen != null, "invalid argument: missing screen")
	assert(_stack.size() > 0, "cannot replace on empty stack")
	_enqueue_or_run(func(): _do_replace(screen, instance))


## reset clears the entire stack and pushes a new base screen.
func reset(screen: StdScreen, instance: Node = null) -> void:
	assert(screen != null, "invalid argument: missing screen")
	_enqueue_or_run(func(): _do_reset(screen, instance))


## pop_to pops screens until the given screen is on top.
## When animate_intermediate is false (default), only the last
## screen's exit transition plays. Set to true to animate all.
func pop_to(
	screen: StdScreen,
	animate_intermediate: bool = false,
) -> void:
	var idx := get_index_of(screen)
	assert(idx >= 0, "screen not in stack")
	_enqueue_or_run(func(): _do_pop_to_depth(idx + 1, animate_intermediate))


## pop_to_depth pops screens until the stack reaches the target
## depth. When animate_intermediate is false (default), only the
## last screen's exit transition plays.
func pop_to_depth(depth: int, animate_intermediate: bool = false) -> void:
	assert(depth >= 1, "depth must be at least 1")
	assert(depth <= _stack.size(), "depth exceeds stack size")
	if _stack.size() <= depth:
		return
	_enqueue_or_run(func(): _do_pop_to_depth(depth, animate_intermediate))


## push_all pushes multiple screens in sequence.
## When animate_intermediate is false (default), only the last
## screen's enter transition plays. Set to true to animate all.
## If instances are provided, they are used instead of loading
## from scene_path.
func push_all(
	screens: Array[StdScreen],
	animate_intermediate: bool = false,
	instances: Array[Node] = [],
) -> void:
	assert(
		screens.size() > 0,
		"invalid argument: empty screens",
	)
	assert(
		instances.is_empty() or instances.size() == screens.size(),
		"instances must match screens length",
	)
	_enqueue_or_run(func(): _do_push_all(screens, animate_intermediate, instances))


## get_current returns the topmost screen, or null if empty.
func get_current() -> StdScreen:
	if _stack.is_empty():
		return null
	return _stack[-1]


## get_scene returns the topmost scene instance, or null if empty.
func get_scene() -> Node:
	return _current_scene()


## get_depth returns the stack depth.
func get_depth() -> int:
	return _stack.size()


## get_at returns the screen at the given index (0 = bottom).
func get_at(index: int) -> StdScreen:
	assert(
		index >= 0 and index < _stack.size(),
		"index out of bounds",
	)
	return _stack[index]


## get_index_of returns the index of the given screen, or -1 if not found.
func get_index_of(screen: StdScreen) -> int:
	return _stack.find(screen)


## is_current returns whether the given screen is the topmost.
func is_current(screen: StdScreen) -> bool:
	return not _stack.is_empty() and _stack[-1] == screen


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_loader = StdScreenLoader.new()
	_loader.name = &"Loader"
	add_child(_loader)

	if initial:
		push(initial)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _enqueue_or_run queues an operation for deferred execution
## when called reentrantly (from a lifecycle signal handler),
## or runs it immediately when idle.
func _enqueue_or_run(operation: Callable) -> void:
	if _is_operating:
		_queue.append(operation)
		return
	_is_operating = true
	operation.call()
	_is_operating = false
	_drain_queue()


## _finish_operation is the completion callback passed to
## _push_impl/_pop_impl. It drains queued operations.
func _finish_operation() -> void:
	_is_operating = false
	_drain_queue()


## _drain_queue runs the next queued operation via a deferred
## call to avoid reentrancy.
func _drain_queue() -> void:
	if _queue.is_empty():
		return
	var next: Callable = _queue.pop_front()
	_run_deferred.call_deferred(next)


## _run_deferred wraps a deferred operation call with the
## reentrancy guard so signal handlers are properly queued.
func _run_deferred(operation: Callable) -> void:
	_is_operating = true
	operation.call()
	_is_operating = false
	_drain_queue()


## _do_push is the operation body for push.
func _do_push(screen: StdScreen, instance: Node) -> void:
	if screen in _stack:
		_logger.warn("Duplicate push ignored; screen already in stack.")
		_finish_operation()
		return
	_cancel_active_transitions()
	_push_impl(screen, instance, false, _finish_operation)


## _do_pop is the operation body for pop.
func _do_pop() -> void:
	_cancel_active_transitions()
	_pop_impl(false, _finish_operation)


## _do_replace is the operation body for replace.
func _do_replace(screen: StdScreen, instance: Node) -> void:
	if screen in _stack and not is_current(screen):
		_logger.warn("Duplicate replace ignored; screen already in stack.")
		_finish_operation()
		return
	_cancel_active_transitions()
	_replace_impl(screen, instance, _finish_operation)


## _do_reset is the operation body for reset.
func _do_reset(screen: StdScreen, instance: Node) -> void:
	_cancel_active_transitions()
	_reset_impl(screen, instance, _finish_operation)


## _do_pop_to_depth is the operation body for pop_to/pop_to_depth.
func _do_pop_to_depth(depth: int, animate_intermediate: bool) -> void:
	_cancel_active_transitions()
	_pop_to_depth_at(depth, animate_intermediate)


## _do_push_all is the operation body for push_all.
func _do_push_all(
	screens: Array[StdScreen],
	animate_intermediate: bool,
	instances: Array[Node],
) -> void:
	for s in screens:
		if s in _stack:
			_logger.warn("Duplicate push_all ignored; screen already in stack.")
			_finish_operation()
			return
	_cancel_active_transitions()
	_push_all_at(screens, 0, animate_intermediate, instances)


## _push_impl performs push logic with callback-driven async.
func _push_impl(
	screen: StdScreen,
	instance: Node,
	skip_enter: bool,
	on_complete: Callable,
) -> void:
	var previous := _current_scene()

	_resolve_scene_then(
		screen,
		instance,
		func(scene: Node) -> void:
			scene.set_meta(&"std_screen", screen)
			add_child(scene)

			_save_focus(previous)

			_stack.append(screen)
			_scenes[screen] = scene

			_update_process_modes()

			screen.entering.emit(scene)
			screen_entering.emit(screen, scene)

			var after_enter := func() -> void:
				screen.entered.emit(scene)
				screen_entered.emit(screen, scene)

				if previous:
					var prev_screen: StdScreen = _stack[_stack.size() - 2]
					prev_screen.covered.emit(previous)
					screen_covered.emit(prev_screen, previous)

				_restore_focus(scene)

				if screen.preload_scenes.size() > 0:
					_loader.load_all(screen.preload_scenes)

				screen_pushed.emit(screen)

				if on_complete.is_valid():
					on_complete.call()

			if skip_enter:
				after_enter.call()
			else:
				_run_enter_transition(screen, scene, after_enter)
	)


## _pop_impl performs pop logic with callback-driven async.
func _pop_impl(skip_exit: bool, on_complete: Callable) -> void:
	var screen: StdScreen = _stack[-1]
	var scene: Node = _scenes[screen]

	screen.exiting.emit(scene)
	screen_exiting.emit(screen, scene)

	_stack.pop_back()
	_scenes.erase(screen)
	_update_process_modes()

	var new_top_scene := _current_scene()
	if new_top_scene:
		var new_top_screen: StdScreen = _stack[-1]
		new_top_screen.uncovered.emit(new_top_scene)
		screen_uncovered.emit(new_top_screen, new_top_scene)

	_restore_focus(new_top_scene)

	var after_exit := func() -> void:
		screen_popped.emit(screen)

		if on_complete.is_valid():
			on_complete.call()

	if skip_exit:
		_disconnect_lifecycle(screen, scene)
		screen.exited.emit(scene)
		screen_exited.emit(screen, scene)
		scene.queue_free()
		after_exit.call()
	else:
		_run_exit_transition(screen, scene, after_exit)


## _replace_impl performs replace logic with callback-driven async.
func _replace_impl(
	screen: StdScreen,
	instance: Node,
	on_complete: Callable,
) -> void:
	var old_screen: StdScreen = _stack[-1]
	var old_scene: Node = _scenes[old_screen]

	old_screen.exiting.emit(old_scene)
	screen_exiting.emit(old_screen, old_scene)

	_stack.pop_back()
	_scenes.erase(old_screen)

	_run_exit_transition(
		old_screen,
		old_scene,
		func() -> void:
			_resolve_scene_then(
				screen,
				instance,
				func(scene: Node) -> void:
					scene.set_meta(&"std_screen", screen)
					add_child(scene)

					_stack.append(screen)
					_scenes[screen] = scene

					_update_process_modes()

					screen.entering.emit(scene)
					screen_entering.emit(screen, scene)

					_run_enter_transition(
						screen,
						scene,
						func() -> void:
							screen.entered.emit(scene)
							screen_entered.emit(screen, scene)

							_restore_focus(scene)

							if screen.preload_scenes.size() > 0:
								_loader.load_all(screen.preload_scenes)

							screen_replaced.emit(old_screen, screen)

							if on_complete.is_valid():
								on_complete.call()
					)
			)
	)


## _reset_impl clears the stack and pushes a new base screen.
func _reset_impl(
	screen: StdScreen,
	instance: Node,
	on_complete: Callable,
) -> void:
	# Free all existing scenes instantly with proper lifecycle signals.
	for i in range(_stack.size() - 1, -1, -1):
		var s: StdScreen = _stack[i]
		var sc: Node = _scenes.get(s)
		if sc and is_instance_valid(sc):
			s.exiting.emit(sc)
			screen_exiting.emit(s, sc)
			_disconnect_lifecycle(s, sc)
			s.exited.emit(sc)
			screen_exited.emit(s, sc)
			sc.queue_free()

	_stack.clear()
	_scenes.clear()
	_focus.clear()

	_resolve_scene_then(
		screen,
		instance,
		func(scene: Node) -> void:
			scene.set_meta(&"std_screen", screen)
			add_child(scene)

			_stack.append(screen)
			_scenes[screen] = scene

			_update_process_modes()

			screen.entering.emit(scene)
			screen_entering.emit(screen, scene)

			_run_enter_transition(
				screen,
				scene,
				func() -> void:
					screen.entered.emit(scene)
					screen_entered.emit(screen, scene)

					_restore_focus(scene)

					if screen.preload_scenes.size() > 0:
						_loader.load_all(screen.preload_scenes)

					if on_complete.is_valid():
						on_complete.call()
			)
	)


## _push_all_at recursively pushes screens starting at index.
func _push_all_at(
	screens: Array[StdScreen],
	index: int,
	animate_intermediate: bool,
	instances: Array[Node],
) -> void:
	if index >= screens.size():
		_finish_operation()
		return

	var is_last := index == screens.size() - 1
	var skip := not is_last and not animate_intermediate
	var inst: Node = instances[index] if instances.size() > index else null

	_push_impl(
		screens[index],
		inst,
		skip,
		func() -> void:
			_push_all_at(
				screens,
				index + 1,
				animate_intermediate,
				instances,
			),
	)


## _pop_to_depth_at recursively pops until target depth.
func _pop_to_depth_at(depth: int, animate_intermediate: bool) -> void:
	if _stack.size() <= depth:
		_finish_operation()
		return

	var is_last := _stack.size() == depth + 1
	var skip := not is_last and not animate_intermediate

	_pop_impl(
		skip,
		func() -> void: _pop_to_depth_at(depth, animate_intermediate),
	)


## _resolve_scene_then calls the callback with the resolved scene node.
func _resolve_scene_then(
	screen: StdScreen,
	instance: Node,
	on_done: Callable,
) -> void:
	if instance:
		on_done.call(instance)
		return

	assert(screen.scene_path != "", "missing scene_path and no instance")

	var result: StdScreenLoader.Result = _loader.load(screen.scene_path)
	if result.is_done():
		assert(result.get_error() == OK, "failed to load scene")
		assert(result.scene != null, "loaded scene was null")
		on_done.call(result.scene.instantiate())
	else:
		result.done.connect(
			func() -> void:
				assert(result.get_error() == OK, "failed to load scene")
				assert(result.scene != null, "loaded scene was null")
				on_done.call(result.scene.instantiate()),
			CONNECT_ONE_SHOT,
		)


## _run_enter_transition starts an enter transition and calls the callback
## when complete (or immediately if non-blocking or no transition).
func _run_enter_transition(
	screen: StdScreen,
	scene: Node,
	on_complete: Callable,
) -> void:
	var transition := screen.enter_transition

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

	transition.completed.connect(cleanup, CONNECT_ONE_SHOT)
	transition.start(scene, true)

	if not screen.block_on_enter:
		if on_complete.is_valid():
			on_complete.call()


## _run_exit_transition handles exit transition and scene
## cleanup.
func _run_exit_transition(
	screen: StdScreen,
	scene: Node,
	on_complete: Callable,
) -> void:
	var transition: StdScreenTransition = screen.exit_transition

	if transition == null:
		_disconnect_lifecycle(screen, scene)
		screen.exited.emit(scene)
		screen_exited.emit(screen, scene)
		scene.queue_free()
		if on_complete.is_valid():
			on_complete.call()
		return

	_active_transitions.append(transition)

	_cancel_cleanup[transition] = func() -> void:
		_disconnect_lifecycle(screen, scene)
		screen.exited.emit(scene)
		screen_exited.emit(screen, scene)
		if is_instance_valid(scene):
			scene.queue_free()

	transition.start(scene, false)

	var cleanup := func() -> void:
		_active_transitions.erase(transition)
		_cancel_cleanup.erase(transition)
		_disconnect_lifecycle(screen, scene)
		screen.exited.emit(scene)
		screen_exited.emit(screen, scene)
		if is_instance_valid(scene):
			scene.queue_free()
		if screen.block_on_exit:
			if on_complete.is_valid():
				on_complete.call()

	transition.completed.connect(cleanup, CONNECT_ONE_SHOT)

	if not screen.block_on_exit:
		if on_complete.is_valid():
			on_complete.call()


## _cancel_active_transitions cancels all in-flight transitions.
func _cancel_active_transitions() -> void:
	for transition in _active_transitions.duplicate():
		for conn in transition.completed.get_connections():
			transition.completed.disconnect(conn["callable"])
		transition.cancel()
		if transition in _cancel_cleanup:
			_cancel_cleanup[transition].call()
	_active_transitions.clear()
	_cancel_cleanup.clear()


## _update_process_modes sets process modes for all scenes in the stack.
## The top scene inherits; covered scenes are optionally disabled.
func _update_process_modes() -> void:
	for i in range(_stack.size()):
		var screen: StdScreen = _stack[i]
		var scene: Node = _scenes.get(screen)
		if scene == null:
			continue

		if i == _stack.size() - 1:
			scene.process_mode = Node.PROCESS_MODE_INHERIT
		elif screen.pause_when_covered:
			scene.process_mode = Node.PROCESS_MODE_DISABLED


## _current_scene returns the scene node for the topmost screen, or null.
func _current_scene() -> Node:
	if _stack.is_empty():
		return null
	return _scenes.get(_stack[-1])


## _save_focus records the currently focused control for a scene.
func _save_focus(scene: Node) -> void:
	if scene == null:
		return

	var viewport := get_viewport()
	if viewport == null:
		return

	var focused := viewport.gui_get_focus_owner()
	if focused and scene.is_ancestor_of(focused):
		_focus[scene] = focused


## _restore_focus restores saved focus for a scene, falling back to
## StdInputCursor or the first focusable control.
func _restore_focus(scene: Node) -> void:
	if scene == null:
		return

	if not scene is Control:
		return

	var control := scene as Control

	# Try saved focus first.
	var saved: Control = _focus.get(scene)
	if (
		saved
		and is_instance_valid(saved)
		and saved.is_visible_in_tree()
		and saved.focus_mode != Control.FOCUS_NONE
	):
		saved.grab_focus()
		return

	# Try StdInputCursor.
	var cursor := _get_input_cursor()
	if cursor:
		cursor.set_focus_root(control)
		return

	# Fallback: first focusable child.
	var focusable := _find_first_focusable(control)
	if focusable:
		focusable.grab_focus()


## _disconnect_lifecycle disconnects the scene from the screen's lifecycle
## signals. Prevents stale connections if the same StdScreen is reused.
func _disconnect_lifecycle(screen: StdScreen, scene: Node) -> void:
	for s in [
		screen.entering,
		screen.entered,
		screen.exiting,
		screen.exited,
		screen.covered,
		screen.uncovered,
	]:
		for connection in s.get_connections():
			var callable: Callable = connection["callable"]
			if callable.get_object() == scene:
				s.disconnect(callable)


## _get_input_cursor returns the StdInputCursor singleton via StdGroup, or
## null if none is registered.
func _get_input_cursor() -> StdInputCursor:
	var group := StdGroup.with_id(StdInputCursor.GROUP_INPUT_CURSOR)
	var members := group.list_members()
	if members.is_empty():
		return null
	return members[0] as StdInputCursor


## _find_first_focusable recursively finds the first Control that can receive
## focus. Returns null if none exists.
func _find_first_focusable(node: Control) -> Control:
	if node.focus_mode != Control.FOCUS_NONE:
		return node

	for child in node.get_children():
		if child is Control:
			var result := _find_first_focusable(child as Control)
			if result:
				return result

	return null
