##
## screen/manager/manager.gd
##
## StdScreenManager is a pushdown automaton governing a stack of StdScreen resources,
## each backed by an instantiated scene node. This is a thin orchestrator that delegates
## to operation objects for navigation logic.
##

class_name StdScreenManager
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

@warning_ignore("unused_signal")
## screen_covered is emitted when another screen is pushed on top.
signal screen_covered(screen: StdScreen, scene: Node)

@warning_ignore("unused_signal")
## screen_entered is emitted after a screen's enter transition completes.
signal screen_entered(screen: StdScreen, scene: Node)

## screen_entering is emitted after a screen's scene is mounted but before the enter
## transition starts.
signal screen_entering(screen: StdScreen, scene: Node)

## screen_exited is emitted after a screen's exit transition completes.
signal screen_exited(screen: StdScreen, scene: Node)

@warning_ignore("unused_signal")
## screen_exiting is emitted before a screen's exit transition starts.
signal screen_exiting(screen: StdScreen, scene: Node)

## screen_uncovered is emitted when a covering screen is popped.
signal screen_uncovered(screen: StdScreen, scene: Node)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Operation := preload("../operation/operation.gd")
const OperationQueue := preload("queue.gd")
const Overlays := preload("overlays.gd")
const Pop := preload("../operation/pop.gd")
const Push := preload("../operation/push.gd")
const Replace := preload("../operation/replace.gd")
const Reset := preload("../operation/reset.gd")
const Signals := preload("../../event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _META_PROCESS_MODE is the metadata key used to save a scene's process mode before the
## manager disables it.
const _META_PROCESS_MODE := &"addons_std_screen_manager_process_mode"


## _InputBlocker is a Control that swallows all input events.
class _InputBlocker:
	extends Control

	func _input(_event: InputEvent) -> void:
		get_viewport().set_input_as_handled()


# -- CONFIGURATION ------------------------------------------------------------------- #

## initial is the screen pushed onto the stack.
@export var initial: StdScreen

# -- INITIALIZATION ------------------------------------------------------------------ #

## NOTIFICATION_SCREEN_COVERED is propagated to a scene's subtree when the screen is
## covered by another.
static var NOTIFICATION_SCREEN_COVERED: int = (1 << 24) + 1  # gdlint:ignore=class-definitions-order,class-variable-name,max-line-length

## NOTIFICATION_SCREEN_UNCOVERED is propagated to a scene's subtree when a covering
## screen is popped.
static var NOTIFICATION_SCREEN_UNCOVERED: int = (1 << 24) + 2  # gdlint:ignore=class-definitions-order,class-variable-name,max-line-length

static var _logger := StdLogger.create(&"std/screen/manager")  # gdlint:ignore=class-definitions-order,max-line-length

var _active_context: StdScreenTransitionContext = null
var _active_op: Operation = null
var _active_transition: StdScreenTransition = null
var _cache: Dictionary[StdScreen, Node] = {}
var _cursor: StdInputCursor = null
var _focus: Dictionary[Node, Control] = {}
var _input_blocker: Control = null
var _loader: StdScreenLoader = null
var _overlays: Overlays = null
var _preloads: Dictionary[StdScreen, Dictionary] = {}
var _queue: OperationQueue = null
var _scenes: Dictionary[StdScreen, Node] = {}
var _stack: Array[StdScreen] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_at returns the screen at the given index (0 is the bottom).
func get_at(index: int) -> StdScreen:
	assert(
		index >= 0 and index < _stack.size(),
		"index out of bounds",
	)
	return _stack[index]


## get_current_screen returns the topmost screen, or null if empty.
func get_current_screen() -> StdScreen:
	return _current_screen()


## get_depth returns the stack depth.
func get_depth() -> int:
	return _stack.size()


## is_current returns whether the given screen is the topmost.
func is_current(screen: StdScreen) -> bool:
	return _current_screen() == screen


## get_scene returns the topmost scene instance, or null if empty.
func get_scene() -> Node:
	return _current_scene()


## load_screen starts loading the screen's scene and its dependency scenes.
func load_screen(screen: StdScreen, include_dependencies: bool = true) -> Dictionary:
	var paths := PackedStringArray()
	if screen.scene_path:
		paths.append(screen.scene_path)
	if include_dependencies:
		paths.append_array(screen.get_dependency_paths())
	return _loader.load_all_scenes(paths)


## pop removes the topmost screen from the stack. When force is false (default), emits
## close_requested first; any handler can cancel. The result value is delivered via the
## screen's `popped` signal after removal.
func pop(
	result: Variant = null,
	force: bool = false,
	transition: StdScreenTransition = null,
) -> void:
	assert(_stack.size() > 1, "cannot pop the last screen")

	if not force:
		var screen: StdScreen = _stack.back()
		assert(
			screen is StdScreen,
			"invalid state; missing screen",
		)

		if screen:
			var state := [false]
			screen.close_requested.emit(
				null,
				func() -> void: state[0] = true,
			)
			if state[0]:
				return

	var depth := _stack.size() - 1
	var op := Pop.create(depth, transition, result)
	_queue.enqueue_or_run(func(): _execute_op(op))


## pop_to pops screens until the given screen is on top.
func pop_to(screen: StdScreen) -> void:
	var idx := _stack.find(screen)
	assert(idx >= 0, "screen not in stack")

	var depth := idx + 1
	var op := Pop.create(depth)
	_queue.enqueue_or_run(func(): _execute_op(op))


## push adds a screen on top of the stack.
func push(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> void:
	assert(
		screen != null,
		"invalid argument: missing screen",
	)

	var op := Push.create(screen, instance, transition)
	_queue.enqueue_or_run(func(): _execute_op(op))


## replace swaps the topmost screen for a new one.
func replace(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> void:
	assert(
		screen != null,
		"invalid argument: missing screen",
	)
	assert(
		_stack.size() > 0,
		"cannot replace on empty stack",
	)

	var op := Replace.create(screen, instance, transition)
	_queue.enqueue_or_run(func(): _execute_op(op))


## reset clears the entire stack and pushes a new base screen.
func reset(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> void:
	assert(
		screen != null,
		"invalid argument: missing screen",
	)

	var op := Reset.create(screen, instance, transition)
	_queue.enqueue_or_run(func(): _execute_op(op))


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	_teardown()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_teardown()


func _ready() -> void:
	_queue = OperationQueue.new(self)

	_cursor = (
		StdGroup
		. get_sole_member(
			StdInputCursor.GROUP_INPUT_CURSOR,
		)
	)
	assert(
		_cursor is StdInputCursor,
		"invalid config; missing 'StdInputCursor'",
	)

	_loader = StdScreenLoader.new()
	_loader.name = &"StdScreenLoader"
	add_child(_loader, Engine.is_editor_hint(), INTERNAL_MODE_FRONT)

	_overlays = Overlays.new(self)

	if initial:
		push(initial)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _block_input pushes a full-screen input blocker onto the manager.
func _block_input() -> void:
	if _input_blocker and _input_blocker.is_inside_tree():
		return

	if not _input_blocker:
		_input_blocker = _create_blocker()

	add_child(_input_blocker, false, Node.INTERNAL_MODE_BACK)


## _create_blocker creates a transparent full-rect Control that swallows all input.
func _create_blocker() -> Control:
	var ctrl := _InputBlocker.new()
	ctrl.name = &"TransitionInputBlocker"
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	return ctrl


## _create_resolver builds a resolver callable and an optional sync scene for the given
## screen. The resolver, when called, sync-blocks on any in-progress background loads and
## returns the instantiated scene node. The second element is non-null when the scene is
## immediately available (instance or cache) — operations pass it as `entering_scene` for
## force-stop cleanup.
func _create_resolver(screen: StdScreen, instance: Node) -> Array:
	var sync_scene: Node = null
	var scene_path := ""
	var load_result: StdScreenLoader.Result = null

	if instance:
		sync_scene = instance
	else:
		var cached: Node = _cache.get(screen)
		if cached and is_instance_valid(cached):
			_cache.erase(screen)
			sync_scene = cached
		else:
			_cache.erase(screen)
			if screen.scene_path == "":
				(
					_logger
					. error(
						"Missing scene_path and no instance.",
						{&"screen": str(screen)},
					)
				)
				return [func() -> Node: return null, null]

			scene_path = screen.scene_path
			load_result = _loader.load_scene(scene_path)

	var dep_paths := screen.get_dependency_paths()
	var dep_results: Dictionary[String, StdScreenLoader.Result] = {}
	if not dep_paths.is_empty():
		dep_results = _loader.load_all_scenes(dep_paths)
		_preloads[screen] = dep_results

	var loader := _loader
	var resolver := func() -> Node:
		var scene: Node = sync_scene
		if scene == null:
			if not load_result.is_done():
				loader.load_scene_sync(scene_path)
			if load_result.scene == null:
				(
					_logger
					. error(
						"Scene load failed.",
						{&"path": scene_path},
					)
				)
				return null
			scene = load_result.scene.instantiate()

		for path in dep_paths:
			if ResourceLoader.has_cached(path):
				continue
			var dep: StdScreenLoader.Result = dep_results.get(path)
			if dep and not dep.is_done():
				loader.load_scene_sync(path)

		return scene

	return [resolver, sync_scene]


## _current_scene returns the scene node for the topmost screen.
func _current_scene() -> Node:
	var screen := _current_screen()
	return _scenes.get(screen) if screen else null


## _current_screen returns the topmost screen, or null if empty.
func _current_screen() -> StdScreen:
	return null if _stack.is_empty() else _stack[-1]


## _discard_screen removes a broken screen (missing scene) from the top of the stack and
## cleans up all associated state. The overlay is freed only when no other screen shares
## it (`free_if_unused` checks `is_in_use`). Callers should invoke `_update_stack_state()`
## after the final removal in a batch.
func _discard_screen(screen: StdScreen) -> void:
	_logger.error("Discarding screen with missing scene.")

	_stack.pop_back()
	_scenes.erase(screen)
	_preloads.erase(screen)

	var overlay := _overlays.get_overlay(screen)
	_overlays.erase(screen)
	_overlays.free_if_unused(overlay)

	screen.popped.emit(null)


## _do_pop_to_depth is called by the close overlay handler. Wraps a pop operation for
## enqueuing.
func _do_pop_to_depth(depth: int) -> void:
	var op := Pop.create(depth)
	_execute_op(op)


## _execute_op holds a strong reference to the operation for the duration of its
## execution. Without this, the operation (a `RefCounted` subclass) can be freed during
## async scene loading because GDScript lambdas and bound-method `Callable`s capture
## `RefCounted` targets weakly.
func _execute_op(op: Operation) -> void:
	_active_op = op
	op._execute(
		self,
		func() -> void:
			_active_op = null
			_queue.complete(),
	)


## _force_hover_recalculation dispatches a synthetic mouse motion event to force Godot
## to re-evaluate hover state after a screen operation changes the scene tree.
func _force_hover_recalculation() -> void:
	if not is_inside_tree():
		return

	var viewport := get_viewport()
	var event := InputEventMouseMotion.new()
	event.position = viewport.get_mouse_position()
	event.relative = Vector2.ZERO
	viewport.push_input(event)


## _force_stop stops the active transition and force-finishes the context.
func _force_stop() -> void:
	if _active_transition == null:
		return

	var transition := _active_transition
	var ctx := _active_context

	_active_transition = null
	_active_context = null

	transition.stop()

	if ctx:
		ctx._did_finish = true

	# Free entering scenes that were never mounted to prevent orphaned nodes. The scene
	# is not in the tree and would otherwise leak. For async cases (resolver-based),
	# entering_scene is null until mount() completes — nothing to free.
	if ctx and not ctx._did_mount and is_instance_valid(ctx.entering_scene):
		ctx.entering_scene.free()


## _free_cache frees all cached scene instances.
func _free_cache() -> void:
	for node in _cache.values():
		if is_instance_valid(node):
			node.free.call_deferred()
	_cache.clear()


## _mount_scene adds a scene to the tree, registers it in the stack, and
## emits the entering signal.
func _mount_scene(screen: StdScreen, scene: Node) -> void:
	var overlay := _overlays.get_overlay(screen)
	if not is_instance_valid(overlay):
		overlay = (
			_overlays
			. get_or_create(
				_stack,
				screen.block_input_below,
				_request_close_overlay,
			)
		)
	overlay.add_child(scene)

	_stack.append(screen)
	_scenes[screen] = scene
	_overlays.register(screen, overlay)

	_update_stack_state()

	screen.entering.emit(scene)
	screen_entering.emit(screen, scene)


## _notify_top_uncovered emits uncovered lifecycle signals for the current top screen
## and sets pending focus for resolution. Called after a screen above is removed from
## the stack.
func _notify_top_uncovered() -> void:
	var scene := _current_scene()
	if scene:
		var screen := _current_screen()
		screen.uncovered.emit(scene)
		screen_uncovered.emit(screen, scene)
		scene.propagate_notification(NOTIFICATION_SCREEN_UNCOVERED)
	_set_pending_focus(scene)


## _request_close_overlay propagates close_requested to all screens in the topmost
## overlay. If no handler cancels, pops those screens.
func _request_close_overlay(event: InputEvent) -> void:
	if _queue.is_operating():
		return

	var overlay := _overlays.get_current(_stack)
	if not is_instance_valid(overlay):
		return

	# Walk backward from the top to find the overlay boundary.
	var count := 0
	for i in range(_stack.size() - 1, -1, -1):
		if _overlays.get_overlay(_stack[i]) != overlay:
			break
		count += 1

	var target := maxi(1, _stack.size() - count)
	if _stack.size() <= target:
		return

	# NOTE: Use an array so the lambda captures a reference.
	var state := [false]
	var cancel := func() -> void: state[0] = true
	for i in range(
		_stack.size() - 1,
		_stack.size() - count - 1,
		-1,
	):
		_stack[i].close_requested.emit(event, cancel)
		if state[0]:
			return

	if not get_viewport().is_input_handled():
		get_viewport().set_input_as_handled()

	_queue.enqueue_or_run(
		func(): _do_pop_to_depth(target),
	)


## _resolve_transition returns the transition to use for an operation.
func _resolve_transition(
	screen: StdScreen,
	explicit: StdScreenTransition,
	operation: StringName = &"",
) -> StdScreenTransition:
	if explicit:
		return explicit
	if operation == &"push" and screen.transition_push:
		return screen.transition_push
	if operation == &"pop" and screen.transition_pop:
		return screen.transition_pop
	return screen.transition


## _restore_focus sets the focus root for the given scene, triggering focus resolution.
## The pending focus target (set by _set_pending_focus or consumer calls to
## set_pending_focus) is consumed during resolution.
func _restore_focus(scene: Node) -> void:
	if not is_instance_valid(scene) or not scene is Control:
		return

	if not is_instance_valid(_cursor):
		return

	var overlay := _overlays.get_current(_stack)
	var root: Control = overlay if overlay else scene as Control
	if not root or not root.is_visible_in_tree():
		return

	_cursor.set_focus_root(root)


## _save_focus records the currently focused control for a scene. When no control has
## focus (mouse mode), the cursor's hovered control is used as a fallback — at push
## time, the mouse is still over the clicked button.
func _save_focus(scene: Node) -> void:
	if not is_instance_valid(scene):
		return

	var viewport := get_viewport()
	if not is_instance_valid(viewport):
		return

	var focused := viewport.gui_get_focus_owner()
	if not focused and _cursor:
		focused = _cursor.get_hovered()
	if focused and scene.is_ancestor_of(focused):
		_focus[scene] = focused


## _set_pending_focus loads the previously-saved focus target for the given scene. The
## target is validated and consumed during the next focus resolution triggered by
## _restore_focus.
func _set_pending_focus(scene: Node) -> void:
	if not is_instance_valid(scene):
		return

	if not is_instance_valid(_cursor):
		return

	var saved: Control = _focus.get(scene)
	if saved and is_instance_valid(saved) and saved.is_visible_in_tree():
		_cursor.set_pending_focus(saved)


## _teardown force-stops any active transition and frees all resources.
func _teardown() -> void:
	_force_stop()
	_queue.clear()
	_unblock_input()

	# Emit popped(null) for every screen still on the stack to prevent coroutine leaks.
	# The stack is cleared after emission to guard against double-call (_exit_tree and
	# NOTIFICATION_WM_CLOSE_REQUEST both invoke _teardown).
	var stack := _stack.duplicate()
	_stack.clear()
	for i in range(stack.size() - 1, -1, -1):
		stack[i].popped.emit(null)

	# Free the input blocker node.
	if _input_blocker and is_instance_valid(_input_blocker):
		_input_blocker.free()
		_input_blocker = null

	_free_cache()


## _teardown_scene disconnects signal handlers, emits exited, and frees or caches the
## scene. The overlay mapping should be erased before calling this if the overlay is
## being reused.
func _teardown_scene(screen: StdScreen, scene: Node) -> void:
	screen.disconnect_signal_handlers(scene)
	screen.exited.emit(scene)
	screen_exited.emit(screen, scene)
	_focus.erase(scene)

	_preloads.erase(screen)

	var overlay := _overlays.get_overlay(screen)
	_overlays.erase(screen)

	# Cache or free the scene.
	var should_cache := screen.cache_instance and is_instance_valid(scene)
	if should_cache:
		if scene.get_parent():
			scene.get_parent().remove_child(scene)

		_cache[screen] = scene
	elif is_instance_valid(scene):
		scene.queue_free()

	_overlays.free_if_unused(overlay)

	# Clean up stale cache entry if caching was toggled off.
	if not screen.cache_instance and screen in _cache:
		var stale: Node = _cache[screen]
		_cache.erase(screen)
		if is_instance_valid(stale):
			stale.queue_free()


## _unblock_input removes the input blocker from the tree.
func _unblock_input() -> void:
	if _input_blocker and _input_blocker.is_inside_tree():
		_input_blocker.get_parent().remove_child(_input_blocker)


## _unmount_scene removes a scene from the stack, tears down the old scene, and notifies
## the newly exposed screen.
func _unmount_scene(screen: StdScreen, scene: Node) -> void:
	_stack.pop_back()
	_scenes.erase(screen)

	_update_stack_state()
	_notify_top_uncovered()
	_teardown_scene(screen, scene)


## _update_process_modes sets process modes for all scenes in the stack.
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


## _update_stack_state recalculates process modes and overlay config.
func _update_stack_state() -> void:
	_update_process_modes()
	_overlays.update_config(_stack)
