# gdlint:ignore=max-public-methods
# gdlint:disable=max-file-lines

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

## screen_uncovered is emitted when a covering screen is popped.
signal screen_uncovered(screen: StdScreen, scene: Node)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../../event/signal.gd")
const OperationQueue := preload("queue.gd")
const Controller := preload("controller.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _META_PROCESS_MODE is the metadata key used to save a scene's process mode before the
## manager disables it.
const _META_PROCESS_MODE := &"addons_std_screen_manager_process_mode"

# -- CONFIGURATION ------------------------------------------------------------------- #

## initial is the screen pushed onto the stack.
@export var initial: StdScreen

# -- INITIALIZATION ------------------------------------------------------------------ #

## NOTIFICATION_SCREEN_COVERED is propagated to a scene's subtree when the screen is
## covered by another. This value can be overridden to avoid collisions if needed.
static var NOTIFICATION_SCREEN_COVERED: int = (1 << 24) + 1  # gdlint:ignore=class-definitions-order,class-variable-name,max-line-length

## NOTIFICATION_SCREEN_UNCOVERED is propagated to a scene's subtree when a covering
## screen is popped. This value can be overridden to avoid collisions if needed.
static var NOTIFICATION_SCREEN_UNCOVERED: int = (1 << 24) + 2  # gdlint:ignore=class-definitions-order,class-variable-name,max-line-length

## _logger is the logger instance for this class.
static var _logger := StdLogger.create(&"std/screen/manager")  # gdlint:ignore=class-definitions-order,max-line-length

## _cache maps `StdScreen` resources to their cached scene instances. Scenes are cached
## when `screen.cache_instance` is true and the screen is popped from the stack.
var _cache: Dictionary[StdScreen, Node] = {}

## _cursor is the input cursor singleton used for focus management.
var _cursor: StdInputCursor = null

## _focus maps scene nodes to their last-focused control.
var _focus: Dictionary[Node, Control] = {}

## _loader is the background scene loader.
var _loader: StdScreenLoader = null

## _overlays maps each `StdScreen` to its `StdScreenOverlay`.
var _overlays: Dictionary[StdScreen, StdScreenOverlay] = {}

## _preloads holds preload dependency results for each active screen, keeping loaded
## resources alive via reference counting for the screen's stack lifetime.
var _preloads: Dictionary[StdScreen, Dictionary] = {}

## _retained_nodes holds nodes registered by transitions for cleanup on shutdown or
## reset. These are keyed by a transition-defined identifier.
var _retained_nodes: Dictionary[StringName, Node] = {}

## _queue is the reentrancy-safe operation queue.
var _queue: OperationQueue = null

## _scenes maps each `StdScreen` to its instantiated scene node.
var _scenes: Dictionary[StdScreen, Node] = {}

## _stack is the screen stack. Index `0` is the bottom (base scene).
var _stack: Array[StdScreen] = []

## _transitions manages transition lifecycle.
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


## load_screen starts loading the screen's scene and, optionally, all of its declared
## preload dependencies. Returns a dictionary of results keyed by resource path.
func load_screen(
	screen: StdScreen,
	include_dependencies: bool = true,
) -> Dictionary:
	var paths := PackedStringArray()
	if screen.scene_path:
		paths.append(screen.scene_path)
	if include_dependencies:
		paths.append_array(screen.preload_scenes)
	return _loader.load_all_scenes(paths)


## pop removes the topmost screen from the stack and returns focus to the new top. When
## force is false (default), emits close_requested on the top screen first; any handler
## can cancel.call() to abort.
func pop(
	force: bool = false,
	transition: StdScreenTransition = null,
) -> void:
	assert(_stack.size() > 1, "cannot pop the last screen")

	if not force:
		var screen: StdScreen = _stack.back()
		assert(screen is StdScreen, "invalid state; missing screen")

		if screen:
			var state := [false]
			screen.close_requested.emit(
				null,
				func() -> void: state[0] = true,
			)
			if state[0]:
				return

	_queue.enqueue_or_run(
		func(): _do_pop(transition),
	)


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
func push(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> void:
	assert(screen != null, "invalid argument: missing screen")

	var instances: Array[Node] = []
	if instance:
		instances.append(instance)

	push_all([screen] as Array[StdScreen], false, instances, transition)


## push_all pushes multiple screens in sequence. When animate_intermediate is false
## (default), only the last screen's enter transition plays. Set to true to animate all.
## If instances are provided, they are used instead of loading from scene_path.
func push_all(
	screens: Array[StdScreen],
	animate_intermediate: bool = false,
	instances: Array[Node] = [],
	transition: StdScreenTransition = null,
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
				transition,
			),
	)


## replace swaps the topmost screen for a new one.
func replace(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> void:
	assert(screen != null, "invalid argument: missing screen")
	assert(_stack.size() > 0, "cannot replace on empty stack")

	_queue.enqueue_or_run(
		func(): _do_replace(screen, instance, transition),
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


func _exit_tree() -> void:
	_teardown()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_teardown()


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


## _free_retained_nodes frees all nodes registered by transitions and clears the
## registry.
func _free_retained_nodes() -> void:
	for node in _retained_nodes.values():
		if is_instance_valid(node):
			node.free.call_deferred()
	_retained_nodes.clear()


## _resolve_transition returns the transition to use for an operation. Resolution order:
## explicit parameter > screen's transition property > null (instant).
func _resolve_transition(
	screen: StdScreen,
	explicit: StdScreenTransition,
) -> StdScreenTransition:
	if explicit:
		return explicit
	return screen.transition


## _teardown frees all retained transition nodes and stops in-flight transitions.
func _teardown() -> void:
	_transitions.stop_all(true)
	_queue.clear()
	_free_retained_nodes()

	# Clear scene cache on teardown.
	for node in _cache.values():
		if is_instance_valid(node):
			node.free.call_deferred()
	_cache.clear()


# Operations


## _do_pop is the operation body for a single pop.
func _do_pop(transition: StdScreenTransition) -> void:
	_transitions.stop_all()
	_pop_impl(false, transition, _queue.complete)


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
	transition: StdScreenTransition,
) -> void:
	_transitions.stop_all()

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

	_push_all_at(screens, 0, animate_intermediate, instances, transition)


## _do_replace is the operation body for replace.
func _do_replace(
	screen: StdScreen,
	instance: Node,
	transition: StdScreenTransition,
) -> void:
	_transitions.stop_all()

	if screen in _stack and not is_current(screen):
		(
			_logger
			. warn(
				"Duplicate replace ignored;" + " screen already in stack.",
			)
		)
		_queue.complete()
		return

	_replace_impl(screen, instance, transition, _queue.complete)


## _do_reset is the operation body for reset.
func _do_reset(
	screen: StdScreen,
	instance: Node,
) -> void:
	_transitions.stop_all(true)
	_reset_impl(screen, instance, _queue.complete)


# Lifecycle


# TODO(#351): Replace asserts with runtime error handling.
func _await_all_loaded(
	results: Dictionary,
	on_done: Callable,
) -> void:
	for result in results.values():
		if result.is_done():
			assert(result.get_error() == OK, "failed to load dependency")
			continue

		Signals.connect_safe(
			result.done,
			func() -> void:
				assert(result.get_error() == OK, "failed to load dependency")
				_await_all_loaded(results, on_done),
			CONNECT_ONE_SHOT,
		)
		return

	on_done.call()


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


## _mount_scene adds a scene to the tree, registers it in the stack, and emits the
## entering signal.
func _mount_scene(
	screen: StdScreen,
	scene: Node,
	reuse_overlay: StdScreenOverlay = null,
) -> void:
	var overlay: StdScreenOverlay
	if is_instance_valid(reuse_overlay) and screen.block_input_below:
		overlay = reuse_overlay
	else:
		overlay = _get_or_create_overlay(screen.block_input_below)
	overlay.add_child(scene)

	_stack.append(screen)
	_scenes[screen] = scene
	_overlays[screen] = overlay

	_update_stack_state()

	screen.entering.emit(scene)
	screen_entering.emit(screen, scene)


## _pop_impl performs pop logic with the unified transition model.
func _pop_impl(
	skip_exit: bool,
	transition_override: StdScreenTransition,
	on_complete: Callable,
) -> void:
	var screen: StdScreen = _stack[-1]
	var scene: Node = _scenes[screen]

	screen.exiting.emit(scene)
	screen_exiting.emit(screen, scene)

	var transition := _resolve_transition(screen, transition_override)

	if skip_exit or transition == null:
		# Instant pop: unmount, emit signals, complete.
		_unmount_and_finish_pop(screen, scene)
		screen_popped.emit(screen)
		on_complete.call()
		return

	# Set up the context for the exit transition.
	var ctx := StdScreenTransitionContext.new(self)
	ctx.current_scene = scene

	# Unmount function: remove from stack, teardown, emit signals.
	ctx._unmount_fn = func() -> void: _unmount_and_finish_pop(screen, scene)

	# Cancel cleanup: if the transition is interrupted before unmount, perform it.
	var cancel_cleanup := func() -> void:
		if not ctx._did_unmount:
			_unmount_and_finish_pop(screen, scene)
		screen_popped.emit(screen)

	# After done(): emit popped, complete the operation.
	ctx._on_done = func() -> void:
		_transitions.clear()
		screen_popped.emit(screen)
		on_complete.call()

	# Auto-block input if configured.
	if transition.block_input_exit:
		ctx.block_input()

	_transitions.run(transition, ctx, false, cancel_cleanup)


## _unmount_and_finish_pop handles the stack/signal work for a pop.
func _unmount_and_finish_pop(
	screen: StdScreen,
	scene: Node,
) -> void:
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
		new_top_scene.propagate_notification(NOTIFICATION_SCREEN_UNCOVERED)

	_restore_focus(new_top_scene)

	_teardown_scene(screen, scene)
	if _cursor.get_is_visible():
		_force_hover_recalculation()


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
		null,
		func() -> void: _pop_to_depth_at(depth, animate_intermediate),
	)


## _push_all_at recursively pushes screens starting at index. For intermediate
## screens with `animate_intermediate`, transitions are started then immediately
## interrupted so cancel_cleanup mounts the screen synchronously.
func _push_all_at(
	screens: Array[StdScreen],
	index: int,
	animate_intermediate: bool,
	instances: Array[Node],
	transition: StdScreenTransition,
) -> void:
	# For intermediate screens with animate_intermediate, push and immediately
	# interrupt. This mounts each screen synchronously via cancel_cleanup.
	while index < screens.size() - 1 and animate_intermediate:
		@warning_ignore("CONFUSABLE_LOCAL_DECLARATION")
		var instance: Node = instances[index] if instances.size() > index else null
		var screen_trans := _resolve_transition(
			screens[index],
			null,
		)
		if screen_trans == null or instance == null:
			break

		_push_impl(screens[index], instance, false, null, Callable())
		_transitions.stop_all()
		index += 1

	if index >= screens.size():
		_queue.complete()
		return

	var is_last := index == screens.size() - 1
	var skip := not is_last and not animate_intermediate
	var instance: Node = instances[index] if instances.size() > index else null
	var tx: StdScreenTransition = transition if is_last else null

	_push_impl(
		screens[index],
		instance,
		skip,
		tx,
		func() -> void:
			_push_all_at(
				screens,
				index + 1,
				animate_intermediate,
				instances,
				transition,
			),
	)


## _push_impl performs push logic with the unified transition model.
func _push_impl(
	screen: StdScreen,
	instance: Node,
	skip_enter: bool,
	transition_override: StdScreenTransition,
	on_complete: Callable,
) -> void:
	var previous := _current_scene()
	var transition := _resolve_transition(screen, transition_override)

	if skip_enter or transition == null:
		# Instant push: load scene, then mount and emit signals.
		_resolve_scene_then(
			screen,
			instance,
			func(resolved: Node) -> void:
				_save_focus(previous)
				_mount_scene(screen, resolved)

				screen.entered.emit(resolved)
				screen_entered.emit(screen, resolved)
				_restore_focus(resolved)

				_emit_covered(previous)
				screen_pushed.emit(screen)
				on_complete.call(),
		)
		return

	# Push with transition: start transition immediately, overlapping with scene
	# loading if the scene is not immediately available.
	_save_focus(previous)

	# Resolve entering scene eagerly (check instance, then cache).
	var scene: Node = null
	if instance:
		scene = instance
	else:
		var cached: Node = _cache.get(screen)
		if cached and is_instance_valid(cached):
			_cache.erase(screen)
			scene = cached
		else:
			_cache.erase(screen)

	# Set up the context for the enter transition.
	var ctx := StdScreenTransitionContext.new(self)
	ctx.current_scene = previous
	if scene:
		ctx.entering_scene = scene

	# Start preload dependencies (non-blocking, kept alive via reference).
	if scene and screen.preload_scenes.size() > 0:
		var dep_results := (
			_loader
			. load_all_scenes(
				screen.preload_scenes,
			)
		)
		if not dep_results.is_empty():
			_preloads[screen] = dep_results

	# Mount function references ctx.entering_scene (set later if loading).
	ctx._mount_fn = func() -> void: _mount_scene(screen, ctx.entering_scene)

	# Cancel cleanup: ensure stack reaches a consistent state.
	var cancel_cleanup := func() -> void:
		if ctx.entering_scene:
			if not ctx._did_mount:
				_mount_scene(screen, ctx.entering_scene)

			screen.entered.emit(ctx.entering_scene)
			screen_entered.emit(screen, ctx.entering_scene)
			_restore_focus(ctx.entering_scene)
			_emit_covered(previous)
			screen_pushed.emit(screen)
		else:
			# Scene not loaded yet; invalidate mount to prevent deferred mount.
			ctx._mount_fn = Callable()

	# After done(): emit entered, covered, pushed, complete.
	ctx._on_done = func() -> void:
		_transitions.clear()

		screen.entered.emit(ctx.entering_scene)
		screen_entered.emit(screen, ctx.entering_scene)
		_restore_focus(ctx.entering_scene)
		_emit_covered(previous)
		screen_pushed.emit(screen)
		on_complete.call()

	# Auto-block input if configured.
	if transition.block_input_enter:
		ctx.block_input()

	_transitions.run(transition, ctx, true, cancel_cleanup)

	# If scene wasn't immediately available, load in background.
	if not scene:
		_resolve_scene_then(
			screen,
			null,
			func(loaded_scene: Node) -> void:
				if not ctx._mount_fn.is_valid():
					# Push was abandoned; free the orphan scene.
					if is_instance_valid(loaded_scene):
						loaded_scene.queue_free()
					return

				ctx.entering_scene = loaded_scene
				ctx.scene_loaded.emit(),
		)


## _replace_enter_phase runs the enter phase of a two-phase replace after the exit
## phase has completed.
func _replace_enter_phase(
	screen: StdScreen,
	screen_prev: StdScreen,
	scene: Node,
	overlay_prev: StdScreenOverlay,
	enter_transition: StdScreenTransition,
	on_complete: Callable,
) -> void:
	if enter_transition == null:
		# Instant enter: mount scene directly, emit signals, complete.
		_mount_scene(screen, scene, overlay_prev)

		# Free unused overlay.
		if is_instance_valid(overlay_prev) and overlay_prev not in _overlays.values():
			overlay_prev.queue_free()

		screen.entered.emit(scene)
		screen_entered.emit(screen, scene)
		_restore_focus(scene)
		screen_replaced.emit(screen_prev, screen)
		on_complete.call()
		return

	# Enter with transition.
	var ctx := StdScreenTransitionContext.new(self)
	ctx.current_scene = null  # Old scene already gone.
	ctx.entering_scene = scene
	ctx.is_replace = true

	# Mount function: mount new scene, reusing the previous overlay.
	ctx._mount_fn = func() -> void: _mount_scene(screen, scene, overlay_prev)

	# Nothing to unmount in the enter phase.
	ctx._unmount_fn = Callable()

	# Cancel cleanup: mount if needed, emit signals.
	var cancel_cleanup := func() -> void:
		if not ctx._did_mount:
			_mount_scene(screen, scene, overlay_prev)

		# Free unused overlay.
		if is_instance_valid(overlay_prev) and overlay_prev not in _overlays.values():
			overlay_prev.queue_free()

		screen.entered.emit(scene)
		screen_entered.emit(screen, scene)
		_restore_focus(scene)
		screen_replaced.emit(screen_prev, screen)

	# After done(): free unused overlay, emit signals, complete.
	ctx._on_done = func() -> void:
		_transitions.clear()

		# Free unused overlay.
		if is_instance_valid(overlay_prev) and overlay_prev not in _overlays.values():
			overlay_prev.queue_free()

		screen.entered.emit(scene)
		screen_entered.emit(screen, scene)
		_restore_focus(scene)
		screen_replaced.emit(screen_prev, screen)
		on_complete.call()

	# Auto-block input if configured.
	if enter_transition.block_input_enter:
		ctx.block_input()

	_transitions.run(enter_transition, ctx, true, cancel_cleanup)


## _replace_exit_phase runs the exit phase of a two-phase replace. Once the exit
## transition completes, chains to the enter phase (transition or instant).
func _replace_exit_phase(
	screen: StdScreen,
	screen_prev: StdScreen,
	scene: Node,
	scene_prev: Node,
	overlay_prev: StdScreenOverlay,
	exit_transition: StdScreenTransition,
	enter_transition: StdScreenTransition,
	on_complete: Callable,
) -> void:
	var ctx := StdScreenTransitionContext.new(self)
	ctx.current_scene = scene_prev
	ctx.entering_scene = scene
	ctx.is_replace = true

	# Unmount function: pop old from stack, pre-erase overlay mapping to preserve the
	# overlay node for the enter phase, then teardown the scene.
	ctx._unmount_fn = func() -> void:
		_stack.pop_back()
		_scenes.erase(screen_prev)
		_overlays.erase(screen_prev)
		_teardown_scene(screen_prev, scene_prev)

	# Nothing to mount in the exit phase.
	ctx._mount_fn = Callable()

	# Cancel cleanup: ensure old is unmounted and new is mounted with signals emitted.
	var cancel_cleanup := func() -> void:
		if not ctx._did_unmount:
			_stack.pop_back()
			_scenes.erase(screen_prev)
			_overlays.erase(screen_prev)
			_teardown_scene(screen_prev, scene_prev)

		_mount_scene(screen, scene, overlay_prev)

		# Free unused overlay.
		if is_instance_valid(overlay_prev) and overlay_prev not in _overlays.values():
			overlay_prev.queue_free()

		screen.entered.emit(scene)
		screen_entered.emit(screen, scene)
		_restore_focus(scene)
		screen_replaced.emit(screen_prev, screen)

	# After exit done: clear the controller, then chain to the enter phase.
	ctx._on_done = func() -> void:
		_transitions.clear()
		_replace_enter_phase(
			screen,
			screen_prev,
			scene,
			overlay_prev,
			enter_transition,
			on_complete,
		)

	# Auto-block input if configured.
	if exit_transition.block_input_exit:
		ctx.block_input()

	_transitions.run(exit_transition, ctx, false, cancel_cleanup)


## _replace_impl performs replace logic with the unified transition model.
func _replace_impl(
	screen: StdScreen,
	instance: Node,
	transition_override: StdScreenTransition,
	on_complete: Callable,
) -> void:
	var screen_prev: StdScreen = _stack[-1]
	var scene_prev: Node = _scenes[screen_prev]
	var overlay_prev: StdScreenOverlay = _overlays.get(screen_prev)
	var enter_transition := _resolve_transition(screen, transition_override)

	# Resolve the exit transition based on the entering screen's replace_exit mode.
	var exit_transition: StdScreenTransition = null
	if screen.replace_exit == StdScreen.ReplaceExitMode.PREVIOUS:
		exit_transition = screen_prev.transition
	elif screen.replace_exit == StdScreen.ReplaceExitMode.SELF:
		exit_transition = screen.transition

	screen_prev.exiting.emit(scene_prev)
	screen_exiting.emit(screen_prev, scene_prev)

	if exit_transition != null:
		# Two-phase replace: exit phase first, then chain to enter phase.
		_resolve_scene_then(
			screen,
			instance,
			func(scene: Node) -> void:
				_replace_exit_phase(
					screen,
					screen_prev,
					scene,
					scene_prev,
					overlay_prev,
					exit_transition,
					enter_transition,
					on_complete,
				),
		)
		return

	if enter_transition == null:
		# Instant replace: unmount old, mount new, emit signals.
		_stack.pop_back()
		_scenes.erase(screen_prev)
		_overlays.erase(screen_prev)
		_teardown_scene(screen_prev, scene_prev)

		_resolve_scene_then(
			screen,
			instance,
			func(scene: Node) -> void:
				_mount_scene(screen, scene, overlay_prev)

				# Free unused overlay.
				if (
					is_instance_valid(overlay_prev)
					and overlay_prev not in _overlays.values()
				):
					overlay_prev.queue_free()

				screen.entered.emit(scene)
				screen_entered.emit(screen, scene)
				_restore_focus(scene)
				screen_replaced.emit(screen_prev, screen)
				on_complete.call(),
		)
		return

	# Enter-only replace: start loading eagerly.
	_resolve_scene_then(
		screen,
		instance,
		func(scene: Node) -> void:
			# Set up the context for the enter transition (handles full lifecycle).
			var ctx := StdScreenTransitionContext.new(self)
			ctx.current_scene = scene_prev
			ctx.entering_scene = scene

			# Unmount function: pop old from stack, teardown.
			ctx._unmount_fn = func() -> void:
				_stack.pop_back()
				_scenes.erase(screen_prev)
				_overlays.erase(screen_prev)
				_teardown_scene(screen_prev, scene_prev)

			# Mount function: mount new scene.
			ctx._mount_fn = func() -> void: _mount_scene(screen, scene, overlay_prev)

			# Cancel cleanup: ensure both unmount and mount happened.
			var cancel_cleanup := func() -> void:
				if not ctx._did_unmount:
					_stack.pop_back()
					_scenes.erase(screen_prev)
					_overlays.erase(screen_prev)
					_teardown_scene(screen_prev, scene_prev)

				if not ctx._did_mount:
					_mount_scene(screen, scene, overlay_prev)

				# Free unused overlay.
				if (
					is_instance_valid(overlay_prev)
					and overlay_prev not in _overlays.values()
				):
					overlay_prev.queue_free()

				screen.entered.emit(scene)
				screen_entered.emit(screen, scene)
				_restore_focus(scene)
				screen_replaced.emit(screen_prev, screen)

			# After done(): emit entered, replaced, complete.
			ctx._on_done = func() -> void:
				_transitions.clear()

				# Free unused overlay.
				if (
					is_instance_valid(overlay_prev)
					and overlay_prev not in _overlays.values()
				):
					overlay_prev.queue_free()

				screen.entered.emit(scene)
				screen_entered.emit(screen, scene)
				_restore_focus(scene)
				screen_replaced.emit(screen_prev, screen)
				on_complete.call()

			# Auto-block input if configured.
			if enter_transition.block_input_enter:
				ctx.block_input()

			_transitions.run(enter_transition, ctx, true, cancel_cleanup),
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
			screen_popped.emit(s)

	_stack.clear()
	_scenes.clear()
	_focus.clear()
	_overlays.clear()
	_preloads.clear()
	_free_retained_nodes()

	_resolve_scene_then(
		screen,
		instance,
		func(scene: Node) -> void:
			_mount_scene(screen, scene)

			screen.entered.emit(scene)
			screen_entered.emit(screen, scene)
			_restore_focus(scene)

			screen_pushed.emit(screen)
			on_complete.call(),
	)


## _resolve_scene_then resolves the screen's scene and loads its preload dependencies,
## then calls `on_done` with the instantiated scene once everything is ready.
##
## NOTE: The callback is always invoked deferred, never synchronously within the calling
## frame. Preload results are stored in `_preloads` to keep resources alive on the stack.
func _resolve_scene_then(
	screen: StdScreen,
	instance: Node,
	on_done: Callable,
) -> void:
	var dep_results: Dictionary = {}
	if screen.preload_scenes.size() > 0:
		dep_results = _loader.load_all_scenes(screen.preload_scenes)

	var with_deps := func(scene_instance: Node) -> void:
		_await_all_loaded(
			dep_results,
			func() -> void:
				if not dep_results.is_empty():
					_preloads[screen] = dep_results
				on_done.call(scene_instance),
		)

	if instance:
		with_deps.call_deferred(instance)
		return

	# Check the cache for a previously stored instance.
	var cached: Node = _cache.get(screen)
	if cached and is_instance_valid(cached):
		_cache.erase(screen)
		with_deps.call_deferred(cached)
		return

	_cache.erase(screen)

	assert(screen.scene_path != "", "missing scene_path and no instance")

	# TODO(#351): Replace asserts with runtime error handling.
	var result := _loader.load_scene(screen.scene_path)
	Signals.connect_safe(
		result.done,
		func() -> void:
			assert(result.get_error() == OK, "failed to load scene")
			assert(result.scene != null, "loaded scene was null")
			with_deps.call(result.scene.instantiate()),
		CONNECT_ONE_SHOT,
	)


## _teardown_scene disconnects signal handlers, emits the `exited` signal, and frees the
## scene node. The overlay mapping for this screen should be erased before calling this
## method if the overlay is being reused (e.g. during replace).
func _teardown_scene(
	screen: StdScreen,
	scene: Node,
) -> void:
	screen.disconnect_signal_handlers(scene)
	screen.exited.emit(scene)
	screen_exited.emit(screen, scene)
	_focus.erase(scene)

	_preloads.erase(screen)

	var overlay: StdScreenOverlay = _overlays.get(screen)
	_overlays.erase(screen)

	# If the screen opts in, detach the scene and store it instead of freeing it.
	# Otherwise, free the scene normally.
	var should_cache := screen.cache_instance and is_instance_valid(scene)
	if should_cache:
		if scene.get_parent():
			scene.get_parent().remove_child(scene)

		_cache[screen] = scene
	elif is_instance_valid(scene):
		scene.queue_free()

	# Free the overlay if it is no longer used by any screen in the stack.
	if overlay and not _overlays.values().has(overlay) and is_instance_valid(overlay):
		if overlay.is_inside_tree():
			overlay.get_parent().remove_child(overlay)

		overlay.queue_free()

	# If caching was toggled off while there's a stale entry, clean it up.
	if not screen.cache_instance and screen in _cache:
		var cached: Node = _cache[screen]
		_cache.erase(screen)
		if is_instance_valid(cached):
			cached.queue_free()


# State


## _current_scene returns the scene node for the topmost screen.
func _current_scene() -> Node:
	var screen := get_current_screen()
	return _scenes.get(screen) if screen else null


## _emit_covered emits the covered signal and notification for the previous scene.
func _emit_covered(previous: Node) -> void:
	if not previous:
		return

	assert(
		_stack.size() >= 2,
		"invalid state; expected at least two screens on the stack",
	)

	var prev_screen: StdScreen = _stack[_stack.size() - 2]
	prev_screen.covered.emit(previous)
	screen_covered.emit(prev_screen, previous)
	previous.propagate_notification(NOTIFICATION_SCREEN_COVERED)


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


## _update_overlay_config recalculates the click-to-close mask for the topmost overlay.
func _update_overlay_config() -> void:
	var overlay := _get_current_overlay()
	if not is_instance_valid(overlay):
		return

	var mask := 0
	for screen in _get_overlay_screens(overlay):
		mask |= screen.overlay_click_to_close

	overlay.click_to_close = mask


## _update_process_modes sets process modes for all scenes in the stack. The top scene's
## process mode is restored from metadata (if the manager previously disabled it);
## covered scenes are optionally disabled. Process mode is saved/restored via metadata
## to avoid overwriting user-set modes like `PROCESS_MODE_ALWAYS`.
func _update_process_modes() -> void:
	for i in range(_stack.size()):
		var screen: StdScreen = _stack[i]
		var scene: Node = _scenes.get(screen)
		if not is_instance_valid(scene):
			continue

		if i == _stack.size() - 1:
			if scene.has_meta(_META_PROCESS_MODE):
				scene.process_mode = (
					scene
					. get_meta(
						_META_PROCESS_MODE,
					)
				)

				scene.remove_meta(_META_PROCESS_MODE)
		elif screen.pause_when_covered:
			if not scene.has_meta(_META_PROCESS_MODE):
				(
					scene
					. set_meta(
						_META_PROCESS_MODE,
						scene.process_mode,
					)
				)

			scene.process_mode = Node.PROCESS_MODE_DISABLED


## _update_stack_state recalculates process modes and overlay configuration for the
## current stack.
func _update_stack_state() -> void:
	_update_process_modes()
	_update_overlay_config()


# Focus / Input


## _force_hover_recalculation dispatches a synthetic mouse motion event at the current
## cursor position to force Godot to re-evaluate hover state after a screen pop.
##
## NOTE: The overlay must already be removed from the tree for this to work.
func _force_hover_recalculation() -> void:
	var viewport := get_viewport()
	var event := InputEventMouseMotion.new()
	event.position = viewport.get_mouse_position()
	event.relative = Vector2.ZERO
	viewport.push_input(event)


## _restore_focus restores saved focus for a scene, falling back to the `StdInputCursor`
## to select an appropriate control.
func _restore_focus(scene: Node) -> void:
	if not is_instance_valid(scene) or not scene is Control:
		return

	if not is_instance_valid(_cursor):
		return

	var overlay := _get_current_overlay()
	var root: Control = overlay if overlay else scene as Control
	if not root or not root.is_visible_in_tree():
		return

	var saved: Control = _focus.get(scene)
	if saved and is_instance_valid(saved) and saved.is_visible_in_tree():
		# Defer grab_focus via one-shot to run AFTER focus handlers
		# restore focus_mode (they process focus_root_changed first).
		Signals.connect_safe(
			_cursor.focus_root_changed,
			func(_root: Control) -> void:
				if (
					is_instance_valid(saved)
					and saved.is_visible_in_tree()
					and saved.focus_mode != Control.FOCUS_NONE
				):
					saved.grab_focus(),
			CONNECT_ONE_SHOT,
		)

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
