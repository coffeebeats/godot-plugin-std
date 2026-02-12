# gdlint:ignore=max-public-methods

##
## screen/manager/manager.gd
##
## StdScreenManager is a pushdown automaton governing a stack of `StdScreen` resources,
## each backed by an instantiated scene node.
##

class_name StdScreenManager
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## screen_covered is emitted when another screen is pushed on top.
signal screen_covered(screen: StdScreen, scene: Node)

## screen_entered is emitted after a screen's enter transition completes.
signal screen_entered(screen: StdScreen, scene: Node)

## screen_entering is emitted after a screen's scene is mounted but before the enter
## transition starts.
signal screen_entering(screen: StdScreen, scene: Node)

## screen_exited is emitted after a screen's exit transition completes.
signal screen_exited(screen: StdScreen, scene: Node)

## screen_exiting is emitted before a screen's exit transition starts.
signal screen_exiting(screen: StdScreen, scene: Node)

## screen_popped is emitted after a pop operation completes.
signal screen_popped(screen: StdScreen)

## screen_pushed is emitted after a push operation completes.
signal screen_pushed(screen: StdScreen)

## screen_replaced is emitted after a replace operation completes.
signal screen_replaced(old: StdScreen, new: StdScreen)

## screen_uncovered is emitted when a covering screen is popped.
signal screen_uncovered(screen: StdScreen, scene: Node)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../../event/signal.gd")
const OperationQueue := preload("queue.gd")
const Controller := preload("controller.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## initial is the screen pushed onto the stack.
@export var initial: StdScreen

# -- INITIALIZATION ------------------------------------------------------------------ #

## _logger is the logger instance for this class.
static var _logger := StdLogger.create(&"std/screen/manager")  # gdlint:ignore=class-definitions-order,max-line-length

## _close_actions is the list of input actions that will close the topmost overlay.
var _close_actions := PackedStringArray()

## _cursor is the input cursor singleton used for focus management.
var _cursor: StdInputCursor = null

## _focus maps scene nodes to their last-focused control.
var _focus: Dictionary[Node, Control] = {}

## _loader is the background scene loader.
var _loader: StdScreenLoader = null

## _overlays maps each `StdScreen` to its `StdScreenOverlay`.
var _overlays: Dictionary[StdScreen, StdScreenOverlay] = {}

## _queue is the reentrancy-safe operation queue.
var _queue: OperationQueue = null

## _scenes maps each `StdScreen` to its instantiated scene node.
var _scenes: Dictionary[StdScreen, Node] = {}

## _stack is the screen stack. Index `0` is the bottom (base scene).
var _stack: Array[StdScreen] = []

## _transitions manages transition lifecycle and input blocking.
var _transitions: Controller = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_current_screen returns the topmost screen, or null if empty.
func get_current_screen() -> StdScreen:
	return null if _stack.is_empty() else _stack[-1]


## get_at returns the screen at the given index (`0` is the bottom).
func get_at(index: int) -> StdScreen:
	assert(
		index >= 0 and index < _stack.size(),
		"index out of bounds",
	)
	return _stack[index]


## get_depth returns the stack depth.
func get_depth() -> int:
	return _stack.size()


## get_index_of returns the index of the given screen, or `-1` if not found.
func get_index_of(screen: StdScreen) -> int:
	return _stack.find(screen)


## get_scene returns the topmost scene instance, or null if empty.
func get_scene() -> Node:
	return _current_scene()


## is_current returns whether the given screen is the topmost.
func is_current(screen: StdScreen) -> bool:
	return get_current_screen() == screen


## pop removes the topmost screen from the stack and returns focus to the new top.
func pop() -> void:
	assert(_stack.size() > 1, "cannot pop the last screen")
	pop_to_depth(_stack.size() - 1)


## pop_to pops screens until the given screen is on top. When `animate_intermediate` is
## false (default), only the last screen's exit transition plays. Set to true to animate
## all.
func pop_to(
	screen: StdScreen,
	animate_intermediate: bool = false,
) -> void:
	var idx := get_index_of(screen)
	assert(idx >= 0, "screen not in stack")

	_queue.enqueue_or_run(
		func(): _do_pop_to_depth(idx + 1, animate_intermediate),
	)


## pop_to_depth pops screens until the stack reaches the target depth. When
## `animate_intermediate` is false (default), only the last screen's exit transition
## plays.
func pop_to_depth(
	depth: int,
	animate_intermediate: bool = false,
) -> void:
	assert(depth >= 1, "depth must be at least 1")

	if _stack.size() <= depth:
		return

	_queue.enqueue_or_run(
		func(): _do_pop_to_depth(depth, animate_intermediate),
	)


## push adds a screen on top of the stack and gives it focus.
func push(screen: StdScreen, instance: Node = null) -> void:
	assert(screen != null, "invalid argument: missing screen")

	var instances: Array[Node] = []
	if instance:
		instances.append(instance)

	push_all([screen] as Array[StdScreen], false, instances)


## push_all pushes multiple screens in sequence. When animate_intermediate is false
## (default), only the last screen's enter transition plays. Set to true to animate all.
##  If instances are provided, they are used instead of loading from scene_path.
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

	_queue.enqueue_or_run(
		func():
			_do_push_all(
				screens,
				animate_intermediate,
				instances,
			),
	)


## replace swaps the topmost screen for a new one.
func replace(
	screen: StdScreen,
	instance: Node = null,
) -> void:
	assert(screen != null, "invalid argument: missing screen")
	assert(_stack.size() > 0, "cannot replace on empty stack")

	_queue.enqueue_or_run(
		func(): _do_replace(screen, instance),
	)


## reset clears the entire stack and pushes a new base screen.
func reset(
	screen: StdScreen,
	instance: Node = null,
) -> void:
	assert(screen != null, "invalid argument: missing screen")
	_queue.enqueue_or_run(
		func(): _do_reset(screen, instance),
	)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _input(event: InputEvent) -> void:
	if _stack.is_empty() or _queue.is_operating():
		return

	for action in _close_actions:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_request_close_overlay(event)
			break


func _ready() -> void:
	_queue = OperationQueue.new(self)
	_transitions = Controller.new(self)

	_cursor = StdGroup.get_sole_member(StdInputCursor.GROUP_INPUT_CURSOR)
	assert(_cursor is StdInputCursor, "invalid config; missing 'StdInputCursor'")

	_loader = StdScreenLoader.new()
	_loader.name = &"StdScreenLoader"
	add_child(
		_loader,
		Engine.is_editor_hint(),
		INTERNAL_MODE_FRONT,
	)

	if initial:
		push(initial)


# -- PRIVATE METHODS ----------------------------------------------------------------- #

# Operations


## _do_pop_to_depth is the operation body for pop_to/pop_to_depth.
func _do_pop_to_depth(
	depth: int,
	animate_intermediate: bool,
) -> void:
	_transitions.stop_all()
	_pop_to_depth_at(depth, animate_intermediate)


## _do_push_all is the operation body for push_all.
func _do_push_all(
	screens: Array[StdScreen],
	animate_intermediate: bool,
	instances: Array[Node],
) -> void:
	for s in screens:
		if s in _stack:
			(
				_logger
				. warn(
					"Duplicate push ignored;" + " screen already in stack.",
				)
			)
			_queue.complete()
			return

	_transitions.stop_all()
	_push_all_at(screens, 0, animate_intermediate, instances)


## _do_replace is the operation body for replace.
func _do_replace(
	screen: StdScreen,
	instance: Node,
) -> void:
	if screen in _stack and not is_current(screen):
		(
			_logger
			. warn(
				"Duplicate replace ignored;" + " screen already in stack.",
			)
		)
		_queue.complete()
		return
	_transitions.stop_all()
	_replace_impl(screen, instance, _queue.complete)


## _do_reset is the operation body for reset.
func _do_reset(
	screen: StdScreen,
	instance: Node,
) -> void:
	_transitions.stop_all(true)
	_reset_impl(screen, instance, _queue.complete)


# Lifecycle


func _get_or_create_overlay(block_input_below: bool) -> StdScreenOverlay:
	var overlay: StdScreenOverlay = null
	if not block_input_below and not _stack.is_empty():
		overlay = _overlays.get(_stack[-1])

	assert(
		not overlay or overlay.get_parent() == self,
		"invalid state; overlay not child of manager",
	)

	if not is_instance_valid(overlay):
		overlay = StdScreenOverlay.new()
		overlay.background_clicked.connect(_request_close_overlay)

		add_child(overlay)

	return overlay


## _mount_and_enter adds a scene to the tree, registers it in the stack, emits lifecycle
## signals, and runs the enter transition. The optional `post_enter` callable runs after
## the `entered` signal (e.g. to emit operation-specific signals like `screen_pushed`).
func _mount_and_enter(
	screen: StdScreen,
	scene: Node,
	skip_enter: bool,
	on_complete: Callable,
	post_enter: Callable = Callable(),
) -> void:
	var overlay := _get_or_create_overlay(screen.block_input_below)
	overlay.add_child(scene)

	_stack.append(screen)
	_scenes[screen] = scene
	_overlays[screen] = overlay

	_update_stack_state()

	screen.entering.emit(scene)
	screen_entering.emit(screen, scene)

	var after_enter := func() -> void:
		screen.entered.emit(scene)
		screen_entered.emit(screen, scene)

		_restore_focus(scene)

		if screen.preload_scenes.size() > 0:
			# TODO: Provide a way to block on scene loading.
			_loader.load_all(screen.preload_scenes)

		if post_enter.is_valid():
			post_enter.call()

		assert(on_complete.is_valid(), "invalid state; missing 'on_complete' callback")
		on_complete.call()

	if skip_enter:
		after_enter.call()
	else:
		(
			_transitions
			. run_enter(
				screen,
				scene,
				after_enter,
			)
		)


## _pop_impl performs pop logic with callback-driven async.
func _pop_impl(
	skip_exit: bool,
	on_complete: Callable,
) -> void:
	var screen: StdScreen = _stack[-1]
	var scene: Node = _scenes[screen]

	screen.exiting.emit(scene)
	screen_exiting.emit(screen, scene)

	_stack.pop_back()
	_scenes.erase(screen)

	_update_stack_state()

	var new_top_scene := _current_scene()
	if new_top_scene:
		var new_top_screen := get_current_screen()
		new_top_screen.uncovered.emit(new_top_scene)
		(
			screen_uncovered
			. emit(
				new_top_screen,
				new_top_scene,
			)
		)

	_restore_focus(new_top_scene)

	var after_exit := func() -> void:
		screen_popped.emit(screen)

		assert(on_complete.is_valid(), "invalid state; invalid 'on_complete' callback")
		on_complete.call()

	if skip_exit:
		_teardown_scene(screen, scene)
		after_exit.call()
	else:
		_transitions.run_exit(
			screen,
			scene,
			func() -> void: _teardown_scene(screen, scene),
			after_exit,
		)


## _pop_to_depth_at recursively pops until target depth.
func _pop_to_depth_at(
	depth: int,
	animate_intermediate: bool,
) -> void:
	if _stack.size() <= depth:
		_queue.complete()
		return

	var is_last := _stack.size() == depth + 1
	var skip := not is_last and not animate_intermediate

	_pop_impl(
		skip,
		func() -> void: _pop_to_depth_at(depth, animate_intermediate),
	)


## _push_all_at recursively pushes screens starting at index.
func _push_all_at(
	screens: Array[StdScreen],
	index: int,
	animate_intermediate: bool,
	instances: Array[Node],
) -> void:
	if index >= screens.size():
		_queue.complete()
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
			_save_focus(previous)

			var post := func() -> void:
				if previous:
					var prev_screen: StdScreen = _stack[_stack.size() - 2]
					prev_screen.covered.emit(previous)
					(
						screen_covered
						. emit(
							prev_screen,
							previous,
						)
					)

				screen_pushed.emit(screen)

			_mount_and_enter(
				screen,
				scene,
				skip_enter,
				on_complete,
				post,
			),
	)


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

	# NOTE: Unlike `_pop_impl`, `_update_stack_state` is intentionally skipped here. The
	## screen below stays covered throughout the replace (old exits then new enters), so
	## its state should not change.

	_transitions.run_exit(
		old_screen,
		old_scene,
		func() -> void: _teardown_scene(old_screen, old_scene),
		func() -> void:
			_resolve_scene_then(
				screen,
				instance,
				func(scene: Node) -> void:
					var post := func() -> void:
						(
							screen_replaced
							. emit(
								old_screen,
								screen,
							)
						)

					_mount_and_enter(
						screen,
						scene,
						false,
						on_complete,
						post,
					),
			),
	)


## _reset_impl clears the stack and pushes a new base screen.
func _reset_impl(
	screen: StdScreen,
	instance: Node,
	on_complete: Callable,
) -> void:
	# Free all existing scenes with proper lifecycle signals.
	for i in range(_stack.size() - 1, -1, -1):
		var s: StdScreen = _stack[i]
		var sc: Node = _scenes.get(s)
		if sc and is_instance_valid(sc):
			s.exiting.emit(sc)
			screen_exiting.emit(s, sc)
			_teardown_scene(s, sc)

	_stack.clear()
	_scenes.clear()
	_focus.clear()
	_overlays.clear()

	# Remove any INTERNAL_MODE_BACK children left by transitions (e.g. fade overlay).
	## Skip the loader (INTERNAL_MODE_FRONT) and regular children.
	var regular := get_children(false)
	for child in get_children(true):
		if child == _loader or child in regular:
			continue

		child.queue_free()

	_resolve_scene_then(
		screen,
		instance,
		func(scene: Node) -> void:
			_mount_and_enter(
				screen,
				scene,
				false,
				on_complete,
			),
	)


## _resolve_scene_then calls the callback with the resolved scene.
func _resolve_scene_then(
	screen: StdScreen,
	instance: Node,
	on_done: Callable,
) -> void:
	if instance:
		on_done.call(instance)
		return

	assert(
		screen.scene_path != "",
		"missing scene_path and no instance",
	)

	var result: StdScreenLoader.Result = (
		_loader
		. load(
			screen.scene_path,
		)
	)
	if result.is_done():
		assert(
			result.get_error() == OK,
			"failed to load scene",
		)
		assert(
			result.scene != null,
			"loaded scene was null",
		)
		on_done.call(result.scene.instantiate())
	else:
		Signals.connect_safe(
			result.done,
			func() -> void:
				assert(
					result.get_error() == OK,
					"failed to load scene",
				)
				assert(
					result.scene != null,
					"loaded scene was null",
				)
				on_done.call(result.scene.instantiate()),
			CONNECT_ONE_SHOT,
		)


## _teardown_scene disconnects signal handlers, emits the `exited` signal, and frees the
## scene node.
func _teardown_scene(
	screen: StdScreen,
	scene: Node,
) -> void:
	screen.disconnect_signal_handlers(scene)
	screen.exited.emit(scene)
	screen_exited.emit(screen, scene)
	_focus.erase(scene)

	var overlay: StdScreenOverlay = _overlays.get(screen)
	_overlays.erase(screen)

	# Free the scene. If the overlay is still used by another screen, just free the
	## scene only (removing it from the overlay). Otherwise, free the whole overlay.
	var still_used := overlay and _overlays.values().has(overlay)
	if still_used:
		if is_instance_valid(scene):
			scene.queue_free()
	elif overlay and is_instance_valid(overlay):
		overlay.queue_free()
	elif is_instance_valid(scene):
		scene.queue_free()


# State


## _current_scene returns the scene node for the topmost screen.
func _current_scene() -> Node:
	var screen := get_current_screen()
	return _scenes.get(screen) if screen else null


## _get_current_overlay returns the overlay for the topmost screen, or `null` if the
## stack is empty.
func _get_current_overlay() -> StdScreenOverlay:
	var screen := get_current_screen()
	return _overlays.get(screen) if screen else null


## _get_overlay_screens returns all screens in the stack that share the given overlay.
func _get_overlay_screens(overlay: StdScreenOverlay) -> Array[StdScreen]:
	var screens: Array[StdScreen] = []

	for screen in _stack:
		if _overlays.get(screen) == overlay:
			screens.append(screen)

	return screens


## _on_transitions_settled refreshes process modes and restores focus after all
## transitions complete.
func _on_transitions_settled() -> void:
	_update_process_modes()
	_restore_focus(_current_scene())


## _update_overlay_config recalculates the click-to-close mask for the topmost overlay.
func _update_overlay_config() -> void:
	var overlay := _get_current_overlay()
	if not is_instance_valid(overlay):
		return

	var mask := 0
	for screen in _get_overlay_screens(overlay):
		mask |= screen.overlay_click_to_close

	overlay.click_to_close = mask


## _update_close_actions recalculates the set of input actions that close the topmost
## overlay.
func _update_close_actions() -> void:
	_close_actions = PackedStringArray()

	var overlay := _get_current_overlay()
	if not is_instance_valid(overlay):
		return

	for screen in _get_overlay_screens(overlay):
		if not screen.close_action.is_empty():
			_close_actions.append(screen.close_action)


## _update_process_modes sets process modes for all scenes in the stack. The top scene
## inherits; covered scenes are optionally disabled.
func _update_process_modes() -> void:
	for i in range(_stack.size()):
		var screen: StdScreen = _stack[i]
		var scene: Node = _scenes.get(screen)
		if not is_instance_valid(scene):
			continue

		if i == _stack.size() - 1:
			scene.process_mode = Node.PROCESS_MODE_INHERIT
		elif screen.pause_when_covered:
			scene.process_mode = Node.PROCESS_MODE_DISABLED


## _update_stack_state recalculates process modes, overlay configuration, and close
## actions for the current stack.
func _update_stack_state() -> void:
	_update_process_modes()
	_update_overlay_config()
	_update_close_actions()


# Focus / Input


## _restore_focus restores saved focus for a scene, falling back to the `StdInputCursor`
## to select an appropriate control.
func _restore_focus(scene: Node) -> void:
	if not is_instance_valid(scene) or not scene is Control:
		return

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

	# Delegate to the input cursor with the overlay as focus root.
	var overlay := _get_current_overlay()
	var root: Control = overlay if overlay else scene as Control
	_cursor.set_focus_root(root)


## _request_close_overlay propagates `close_requested` to all screens in the topmost
## overlay in reverse stack order. If no handler cancels, pops those screens down to the
## overlay boundary. Only the topmost overlay is considered; lower overlays are
## unreachable via input due to `MOUSE_FILTER_STOP`.
func _request_close_overlay(event: InputEvent) -> void:
	if _queue.is_operating():
		return

	var overlay := _get_current_overlay()
	if not is_instance_valid(overlay):
		return

	# Walk backward from the top to find the overlay boundary.
	var count := 0
	for i in range(_stack.size() - 1, -1, -1):
		if _overlays.get(_stack[i]) != overlay:
			break
		count += 1

	# Nothing to pop if the overlay contains only the base screen.
	var target := maxi(1, _stack.size() - count)
	if _stack.size() <= target:
		return

	# NOTE: Use an array so the lambda captures a reference, not a copy.
	var state := [false]
	var cancel := func() -> void: state[0] = true
	for i in range(_stack.size() - 1, _stack.size() - count - 1, -1):
		_stack[i].close_requested.emit(event, cancel)
		if state[0]:
			return

	if not get_viewport().is_input_handled():
		get_viewport().set_input_as_handled()

	# Use the bottom-most overlay screen's animate preference (it created the overlay).
	var bottom := _stack[_stack.size() - count]
	var animate_intermediate: bool = bottom.close_animate_intermediate

	_queue.enqueue_or_run(
		func(): _do_pop_to_depth(target, animate_intermediate),
	)


## _save_focus records the currently focused control for a scene.
func _save_focus(scene: Node) -> void:
	if not is_instance_valid(scene):
		return

	var viewport := get_viewport()
	if not is_instance_valid(viewport):
		return

	var focused := viewport.gui_get_focus_owner()
	if focused and scene.is_ancestor_of(focused):
		_focus[scene] = focused
