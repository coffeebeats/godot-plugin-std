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
static var NOTIFICATION_SCREEN_COVERED: int = (1 << 24) + 1 # gdlint:ignore=class-definitions-order,class-variable-name,max-line-length

## NOTIFICATION_SCREEN_UNCOVERED is propagated to a scene's subtree when a covering
## screen is popped.
static var NOTIFICATION_SCREEN_UNCOVERED: int = (1 << 24) + 2 # gdlint:ignore=class-definitions-order,class-variable-name,max-line-length

static var _logger := StdLogger.create(&"std/screen/manager") # gdlint:ignore=class-definitions-order,max-line-length

var _active_context: StdScreenTransitionContext = null
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


## get_scene returns the topmost scene instance, or null if empty.
func get_scene() -> Node:
	return _current_scene()


## load_screen starts loading the screen's scene and its preload dependencies.
func load_screen(screen: StdScreen, include_dependencies: bool = true) -> Dictionary:
	var paths := PackedStringArray()
	if screen.scene_path:
		paths.append(screen.scene_path)
	if include_dependencies:
		paths.append_array(screen.preload_scenes)
	return _loader.load_all_scenes(paths)


## pop removes the topmost screen from the stack. When force is false (default), emits
## close_requested first; any handler can cancel.
func pop(force: bool = false, transition: StdScreenTransition = null) -> void:
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
	var op := Pop.create(depth, transition)
	_queue.enqueue_or_run(
		func(): op._execute(self , _queue.complete),
	)


## pop_to pops screens until the given screen is on top.
func pop_to(screen: StdScreen) -> void:
	var idx := _stack.find(screen)
	assert(idx >= 0, "screen not in stack")

	var depth := idx + 1
	var op := Pop.create(depth)
	_queue.enqueue_or_run(
		func(): op._execute(self , _queue.complete),
	)


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
	_queue.enqueue_or_run(
		func(): op._execute(self , _queue.complete),
	)


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
	_queue.enqueue_or_run(
		func(): op._execute(self , _queue.complete),
	)


## reset clears the entire stack and pushes a new base screen.
func reset(screen: StdScreen, instance: Node = null) -> void:
	assert(screen != null, "invalid argument: missing screen")

	var op := Reset.create(screen, instance)
	_queue.enqueue_or_run(func(): op._execute(self , _queue.complete))


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	_teardown()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_teardown()


func _ready() -> void:
	_queue = OperationQueue.new(self )

	_cursor = (
		StdGroup
		.get_sole_member(
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

	_overlays = Overlays.new(self )

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


## _current_scene returns the scene node for the topmost screen.
func _current_scene() -> Node:
	var screen := _current_screen()
	return _scenes.get(screen) if screen else null


## _current_screen returns the topmost screen, or null if empty.
func _current_screen() -> StdScreen:
	return null if _stack.is_empty() else _stack[-1]


## _do_pop_to_depth is called by the close overlay handler. Wraps a pop operation for
## enqueuing.
func _do_pop_to_depth(depth: int) -> void:
	var op := Pop.create(depth)
	op._execute(self , _queue.complete)


## _force_hover_recalculation dispatches a synthetic mouse motion event to force Godot
## to re-evaluate hover state after a screen pop.
func _force_hover_recalculation() -> void:
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

	# Free entering scenes that were never mounted to prevent orphaned nodes. The scene
	# is not in the tree and would otherwise leak.
	if ctx and not ctx._did_mount and is_instance_valid(ctx.entering_scene):
		ctx.entering_scene.queue_free()

	if ctx:
		ctx._did_finish = true


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
			.get_or_create(
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


## _resolve_preloads loads preload dependencies for a screen and stores them.
func _resolve_preloads(screen: StdScreen) -> void:
	if screen.preload_scenes.is_empty():
		return

	var dep_results := (
		_loader
		.load_all_scenes(
			screen.preload_scenes,
		)
	)
	if dep_results.is_empty():
		return

	_preloads[screen] = dep_results

	# Wait for all dependencies to finish loading.
	for result in dep_results.values():
		if not result.is_done():
			await result.done
		assert(
			result.get_error() == OK,
			"failed to load dependency",
		)


## _resolve_scene resolves a scene for the given screen: checks instance, then cache,
## then triggers async load. Returns the scene node.
func _resolve_scene(screen: StdScreen, instance: Node = null) -> Node:
	if instance:
		return instance

	# Check cache.
	var cached: Node = _cache.get(screen)
	if cached and is_instance_valid(cached):
		_cache.erase(screen)
		return cached

	_cache.erase(screen)

	assert(screen.scene_path != "", "missing scene_path and no instance")

	var result := _loader.load_scene(screen.scene_path)
	if not result.is_done():
		await result.done

	assert(result.get_error() == OK, "failed to load scene")
	assert(result.scene != null, "loaded scene was null")

	return result.scene.instantiate()


## _resolve_transition returns the transition to use for an operation. Resolution order:
## explicit parameter > screen's transition > null.
func _resolve_transition(
	screen: StdScreen,
	explicit: StdScreenTransition,
) -> StdScreenTransition:
	if explicit:
		return explicit
	return screen.transition


## _restore_focus restores saved focus for a scene, falling back to the `StdInputCursor`
## to select an appropriate control.
func _restore_focus(scene: Node) -> void:
	if not is_instance_valid(scene) or not scene is Control:
		return

	if not is_instance_valid(_cursor):
		return

	var overlay := _overlays.get_current(_stack)
	var root: Control = overlay if overlay else scene as Control
	if not root or not root.is_visible_in_tree():
		return

	var saved: Control = _focus.get(scene)
	if saved and is_instance_valid(saved) and saved.is_visible_in_tree():
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


## _teardown force-stops any active transition and frees all resources.
func _teardown() -> void:
	_force_stop()
	_queue.clear()
	_unblock_input()

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


## _unmount_scene removes a scene from the stack, emits uncovered on the newly exposed
## scene, restores focus, and tears down the old scene.
func _unmount_scene(screen: StdScreen, scene: Node) -> void:
	_stack.pop_back()
	_scenes.erase(screen)

	_update_stack_state()

	var new_top_scene := _current_scene()
	if new_top_scene:
		var new_top_screen := _current_screen()
		new_top_screen.uncovered.emit(new_top_scene)
		(
			screen_uncovered
			.emit(
				new_top_screen,
				new_top_scene,
			)
		)
		(
			new_top_scene
			.propagate_notification(
				NOTIFICATION_SCREEN_UNCOVERED,
			)
		)

	_restore_focus(new_top_scene)

	_teardown_scene(screen, scene)
	if _cursor and _cursor.get_is_visible():
		_force_hover_recalculation()


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
					.get_meta(
						_META_PROCESS_MODE,
					)
				)
				scene.remove_meta(_META_PROCESS_MODE)
		elif screen.pause_when_covered:
			if not scene.has_meta(_META_PROCESS_MODE):
				(
					scene
					.set_meta(
						_META_PROCESS_MODE,
						scene.process_mode,
					)
				)

			scene.process_mode = Node.PROCESS_MODE_DISABLED


## _update_stack_state recalculates process modes and overlay config.
func _update_stack_state() -> void:
	_update_process_modes()
	_overlays.update_config(_stack)
