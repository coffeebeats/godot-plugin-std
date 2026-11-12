##
## screen/manager/manager.gd
##
## StdScreenManager is a pushdown automaton governing a stack of StdScreen resources,
## each backed by an instantiated scene node. This is a thin orchestrator that delegates
## to operation objects for navigation logic.
##
## Operations run one at a time, in call order. One opening a screen whose scenes aren't
## loaded changes nothing until `StdLoader` has loaded them, with input blocked and
## later calls queued behind it, so mounting never loads. `is_settled` and `settled`
## report when every call has run, and `screen_load_failed` when a screen couldn't open.
##
## Freeing a node deletes its children immediately. Stack operations often run from
## inside an input handler, so deleting a node while its handler is still running will
## crash the engine. To avoid that, every node here is detached from its parent before
## being queue-freed, and nothing is freed outright while it still has children.
##
## NOTE: A scene run on its own, by F6 or in a test, has no manager among its ancestors,
## so it has no stack to push onto. A test gets one from `StdTestScreenManager`.
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

## screen_load_failed is emitted when an operation couldn't open `screen` because its
## scene failed to load, or it has none. The stack is left as it was.
signal screen_load_failed(screen: StdScreen)

## screen_uncovered is emitted when a covering screen is popped.
signal screen_uncovered(screen: StdScreen, scene: Node)

## settled is emitted whenever no operation is left running, waiting or queued. A game
## checks `is_settled` before awaiting it, then reads `is_current` for the outcome.
signal settled

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Cache := preload("cache.gd")
const Operation := preload("../operation/operation.gd")
const OperationQueue := preload("queue.gd")
const Overlays := preload("overlays.gd")
const Pop := preload("../operation/pop.gd")
const Preparation := preload("preparation.gd")
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

## NOTIFICATION_SCREEN_COVERED is propagated to a scene's subtree, and to its
## attachments, when the screen is covered by another.
static var NOTIFICATION_SCREEN_COVERED: int = (1 << 24) + 1  # gdlint:ignore=class-definitions-order,class-variable-name,max-line-length

## NOTIFICATION_SCREEN_UNCOVERED is propagated to a scene's subtree, and to its
## attachments, when a covering screen is popped.
static var NOTIFICATION_SCREEN_UNCOVERED: int = (1 << 24) + 2  # gdlint:ignore=class-definitions-order,class-variable-name,max-line-length

static var _logger := StdLogger.create(&"std/screen/manager")  # gdlint:ignore=class-definitions-order,max-line-length

var _active_context: StdScreenTransitionContext = null
var _active_op: Operation = null
var _active_transition: StdTransition = null
var _attachments: Dictionary[StdScreen, Array] = {}
var _cache: Cache = null
var _cursor: StdInputCursor = null
var _input_blocker: Control = null
var _overlays: Overlays = null
var _preparations: Dictionary[StdScreen, Preparation] = {}
var _queue: OperationQueue = null
var _scenes: Dictionary[StdScreen, Node] = {}
var _sound_player: StdSoundEventPlayer = null
var _stack: Array[StdScreen] = []

## _waiting_op is the operation waiting for its preparation, or null.
var _waiting_op: Operation = null

## _waiting_preparation is the preparation `_waiting_op` waits for, or null.
var _waiting_preparation: Preparation = null

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


## is_settled returns whether no operation is running, waiting for its loads, or queued.
func is_settled() -> bool:
	return _queue.is_settled() if _queue else true


## get_scene returns the topmost scene instance, or null if empty.
func get_scene() -> Node:
	return _current_scene()


## load_screen starts loading, in the background, what opening `screen` needs: its
## scene, if it has one, and every scene it depends on, to any depth. Holding the
## returned preparation keeps them loaded, so a later operation opening the screen,
## with or without an instance, doesn't wait.
func load_screen(screen: StdScreen) -> Preparation:
	assert(screen != null, "invalid argument: missing screen")

	var entry := _cache.get_entry(screen)
	if entry and entry.preparation and is_instance_valid(entry.scene):
		return entry.preparation

	return Preparation.create(screen.scene_path, screen.get_dependency_paths())


## pop removes the topmost screen from the stack. When force is false (default), emits
## close_requested first; any handler can cancel. The result value is delivered via the
## screen's `popped` signal after removal.
##
## NOTE: The pop removes only the screen on top when it is called, and does nothing if
## that screen has left the top by the time it runs.
func pop(
	result: Variant = null,
	force: bool = false,
	transition: StdTransition = null,
) -> void:
	assert(_stack.size() > 1, "cannot pop the last screen")

	var screen: StdScreen = _stack.back()

	if not force:
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

	var op := Pop.create_top([screen], transition, result)
	_queue.enqueue_or_run(_execute_op.bind(op))


## pop_to pops screens until the given screen is on top.
func pop_to(screen: StdScreen) -> void:
	assert(_stack.has(screen), "screen not in stack")

	var op := Pop.create_to(screen)
	_queue.enqueue_or_run(_execute_op.bind(op))


## push adds a screen on top of the stack.
func push(
	screen: StdScreen,
	instance: Node = null,
	transition: StdTransition = null,
) -> void:
	assert(
		screen != null,
		"invalid argument: missing screen",
	)

	var op := Push.create(screen, instance, transition)
	_queue.enqueue_or_run(_execute_op.bind(op))


## replace swaps the topmost screen for a new one.
func replace(
	screen: StdScreen,
	instance: Node = null,
	transition: StdTransition = null,
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
	_queue.enqueue_or_run(_execute_op.bind(op))


## reset clears the entire stack and pushes a new base screen.
func reset(
	screen: StdScreen,
	instance: Node = null,
	transition: StdTransition = null,
) -> void:
	assert(
		screen != null,
		"invalid argument: missing screen",
	)

	var op := Reset.create(screen, instance, transition)
	_queue.enqueue_or_run(_execute_op.bind(op))


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

	_queue.settled.connect(settled.emit)

	_cache = Cache.new(self)
	_overlays = Overlays.new(self)

	if not StdGroup.is_empty(StdSoundEventPlayer.GROUP_SOUND_PLAYER):
		_sound_player = StdGroup.get_sole_member(StdSoundEventPlayer.GROUP_SOUND_PLAYER)

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


## _complete_active completes, at once, the operation whose transition is running: its
## transition skips to the end and the operation finishes with its signals.
func _complete_active() -> void:
	if _active_transition == null:
		return

	var transition := _active_transition
	var ctx := _active_context

	_active_transition = null
	_active_context = null

	# NOTE: The queue carries on with the operation about to run, so the interrupted
	# operation's completion must not complete the queue.
	_active_op = null

	Operation._finish_transition(transition, ctx)


## _create_blocker creates a transparent full-rect Control that swallows all input.
func _create_blocker() -> Control:
	var ctrl := _InputBlocker.new()
	ctrl.name = &"TransitionInputBlocker"
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	return ctrl


## _create_resolver builds a resolver callable and the scene available at once, if any,
## for opening `screen` from `preparation`. The scene available at once is `instance` or
## a kept scene; otherwise the resolver instantiates the scene `preparation` loaded.
## Neither ever loads. The second element is non-null when a scene is available at once.
func _create_resolver(
	screen: StdScreen, instance: Node, preparation: Preparation
) -> Array:
	var sync_scene: Node = instance
	var entry := _cache.get_entry(screen)

	if sync_scene == null:
		if entry and entry.overlay:
			sync_scene = entry.scene if is_instance_valid(entry.scene) else null
		else:
			sync_scene = _cache.take(screen)
	elif entry and not entry.overlay and entry.scene == instance:
		# NOTE: A detached scene passed back in leaves the cache until it closes again.
		_cache.take(screen)

	var resolver := func() -> Node:
		if sync_scene != null:
			return sync_scene

		var packed: PackedScene = preparation.get_scene() if preparation else null
		if packed == null:
			_logger.error("Scene load failed.", {&"path": screen.scene_path})
			return null

		return packed.instantiate()

	return [resolver, sync_scene]


## _current_scene returns the scene node for the topmost screen.
func _current_scene() -> Node:
	var screen := _current_screen()
	return _scenes.get(screen) if screen else null


## _current_screen returns the topmost screen, or null if empty.
func _current_screen() -> StdScreen:
	return null if _stack.is_empty() else _stack[-1]


## _detach_scene removes the screen's scene and then its attachments from the tree. A
## scene kept in the tree is parked in its overlay instead.
##
## NOTE: They leave in tree order, so that a loader leaving re-syncs only peers whose
## set is already loaded or which leave after it, never one about to leave.
func _detach_scene(screen: StdScreen, scene: Node) -> void:
	var entry := _cache.get_entry(screen)

	if entry and entry.overlay and entry.scene == scene:
		_cache.park(screen)
	elif is_instance_valid(scene) and scene.get_parent():
		scene.get_parent().remove_child(scene)

	for node: Node in _attachments.get(screen, []):
		if is_instance_valid(node) and node.get_parent():
			node.get_parent().remove_child(node)


## _discard_screen removes a broken screen (missing scene) from the top of the stack and
## cleans up all associated state. The overlay is freed only when no other screen shares
## it (`free_if_unused` checks `is_in_use`). Callers should invoke
## `_update_stack_state()` after the final removal in a batch.
func _discard_screen(screen: StdScreen) -> void:
	_logger.error("Discarding screen with missing scene.")

	_stack.pop_back()
	_scenes.erase(screen)
	_preparations.erase(screen)

	_free_attachments(screen)

	var overlay := _overlays.get_overlay(screen)
	_release_focus(screen)
	_overlays.erase(screen)

	if not _cache.owns(overlay):
		_overlays.free_if_unused(overlay)

	screen.popped.emit(null)


## _end_wait ends the wait for an operation's preparation, releasing the queue's hold
## and the input blocker. Every way out of a wait calls it: the preparation finishing,
## failing, or the manager leaving the tree.
func _end_wait() -> void:
	if (
		_waiting_preparation
		and _waiting_preparation.done.is_connected(_on_preparation_done)
	):
		_waiting_preparation.done.disconnect(_on_preparation_done)

	_waiting_op = null
	_waiting_preparation = null

	_queue.release()
	_unblock_input()


## _execute_op runs an operation. A call that arrives while another operation's
## transition runs completes that operation first, skipping the rest of its transition,
## so no operation is dropped. An operation whose preparation isn't done waits for it
## with input blocked and later calls queued; otherwise it presents in the caller's
## stack.
##
## NOTE: `_active_op` holds a strong reference to the operation while it runs. Without
## it the operation, a `RefCounted`, can be freed while it waits, because GDScript
## lambdas and bound-method `Callable`s capture `RefCounted` targets weakly.
func _execute_op(op: Operation) -> void:
	_complete_active()

	_active_op = op

	var preparation := op._prepare(self)
	if preparation and not preparation.is_done():
		_wait(op, preparation)
		return

	_present_op(op)


## _finish_op completes the queue's current operation, unless `op` is one that a later
## call completed early, whose completion the queue no longer awaits.
func _finish_op(op: Operation) -> void:
	if _active_op != op:
		return

	_active_op = null
	_queue.complete()


## _force_hover_recalculation recomputes hover at the mouse's position, so that a
## control under a resting mouse is hovered after a screen operation changes the tree.
func _force_hover_recalculation() -> void:
	if not is_inside_tree():
		return

	get_viewport().update_mouse_cursor_state()


## _force_stop stops the active transition, which ends its context and releases its
## input blocker, without completing its operation. Only teardown does this.
func _force_stop() -> void:
	if _active_transition == null:
		return

	var transition := _active_transition
	var ctx := _active_context

	_active_transition = null
	_active_context = null

	transition.stop()

	# Free entering scenes that were never mounted to prevent orphaned nodes. The scene
	# is not in the tree and would otherwise leak. A scene kept in the tree belongs to
	# the cache, which frees it.
	if (
		ctx
		and not ctx._did_mount
		and is_instance_valid(ctx.entering)
		and not ctx.entering.is_inside_tree()
	):
		ctx.entering.free()


## _free_attachments detaches and queue-frees the given screen's attachment nodes.
##
## NOTE: Detach first. The overlay may be shared and survive this screen, and a queued
## free would leave the node in it, still receiving input, until the end of the frame.
##
## TODO: Attachments are rebuilt on every push, even when `cache_mode` keeps the scene.
## Left alone for now since they are small.
func _free_attachments(screen: StdScreen) -> void:
	if screen not in _attachments:
		return

	for node: Node in _attachments[screen]:
		if is_instance_valid(node):
			if node.get_parent():
				node.get_parent().remove_child(node)

			node.queue_free()

	_attachments.erase(screen)


## _mount_attachments instantiates the screen's attachment scenes into its overlay, from
## the screen's preparation, so mounting never loads.
##
## NOTE: Attachments are added after the mounted scene so that they receive unhandled
## input first; input is dispatched to sibling nodes in reverse tree order.
func _mount_attachments(screen: StdScreen, overlay: StdScreenOverlay) -> void:
	if screen.attachment_scenes.is_empty():
		return

	var nodes: Array = []
	var preparation: Preparation = _preparations.get(screen)

	for path in screen.attachment_scenes:
		var packed: PackedScene = null
		if preparation:
			packed = preparation.get_resource(path) as PackedScene

		if packed == null:
			_logger.error("Failed to load attachment scene.", {&"path": path})
			continue

		var node := packed.instantiate()
		overlay.add_child(node)
		nodes.append(node)

	if nodes:
		_attachments[screen] = nodes


## _mount_entering mounts the scene of the screen an operation opens, then builds each
## screen it depends on that is kept in the tree, so that all building happens within
## the transition's one mount. `preparation` is recorded for the screen as it mounts.
func _mount_entering(screen: StdScreen, scene: Node, preparation: Preparation) -> void:
	var started := Time.get_ticks_usec()

	_mount_scene(screen, scene, preparation)
	_cache.build_dependencies(screen, _stack)

	(
		_logger
		. debug(
			"Mounted screen.",
			{
				&"scene": screen.scene_path,
				&"msec": (Time.get_ticks_usec() - started) / 1000.0,
			},
		)
	)


## _mount_scene adds a scene to the tree, registers it in the stack, and emits the
## entering signal. A parked scene is shown and uncovered rather than added.
##
## NOTE: The screen's `preparation` is recorded here, and not when the operation starts,
## because a screen replacing itself tears down its leaving scene first, and that
## teardown consumes and keeps the screen's recorded preparation.
func _mount_scene(screen: StdScreen, scene: Node, preparation: Preparation) -> void:
	if preparation:
		_preparations[screen] = preparation

	for action in screen.close_actions:
		if not InputMap.has_action(action):
			_logger.warn("Close action not in InputMap.", {&"action": action})
	assert(
		screen.close_actions.all(InputMap.has_action), "invalid config; missing actions"
	)

	var entry := _cache.get_entry(screen)
	var is_parked := entry != null and entry.overlay != null and entry.scene == scene

	var overlay: StdScreenOverlay = null

	if is_parked:
		overlay = _cache.open(screen)
	elif _cache.is_in_tree(screen) and _cache.admit(screen, scene):
		# NOTE: A screen kept in the tree owns one overlay for life. A scene that can't
		# park once ready is never registered, so closing its ordinary overlay keeps it
		# detached.
		overlay = _cache.create_overlay(true)
		overlay.add_child(scene)
		if _cache.confirm(screen, scene):
			_cache.register(screen, scene, _preparations.get(screen), overlay)
	else:
		overlay = _overlays.get_overlay(screen)
		if not is_instance_valid(overlay):
			overlay = (
				_overlays
				. get_or_create(
					_stack,
					screen.block_input_below,
					_request_close_overlay,
					_request_close_top,
				)
			)
		overlay.add_child(scene)

	_stack.append(screen)
	_scenes[screen] = scene
	_overlays.register(screen, overlay)

	# NOTE: The overlay is claimed once per screen, so two screens sharing one each save
	# and restore the focus beneath them.
	if is_instance_valid(_cursor):
		_cursor.claim_focus(overlay)

	_update_stack_state()

	if is_parked:
		scene.propagate_notification(NOTIFICATION_SCREEN_UNCOVERED)

	_mount_attachments(screen, overlay)

	screen.entering.emit(scene)
	screen_entering.emit(screen, scene)

	_play_screen_sound(screen.sound_enter)


## _notify_top_uncovered emits uncovered lifecycle signals for the current top screen.
## Called after a screen above is removed from the stack.
func _notify_top_uncovered() -> void:
	var scene := _current_scene()
	if scene:
		var screen := _current_screen()
		screen.uncovered.emit(scene)
		screen_uncovered.emit(screen, scene)
		scene.propagate_notification(NOTIFICATION_SCREEN_UNCOVERED)
		for node: Node in _attachments.get(screen, []):
			node.propagate_notification(NOTIFICATION_SCREEN_UNCOVERED)


## _play_screen_sound plays a fire-and-forget sound event via the global sound player.
func _play_screen_sound(event: StdSoundEvent) -> void:
	if event and _sound_player:
		_sound_player.play(event)


## _prepare_screen returns the preparation for opening `screen`, with `instance` if one
## was passed: a kept scene's own, or one requesting the scene, unless an instance
## stands in for it, and every scene the screen depends on. A screen with neither a
## scene nor an instance gets a failed preparation.
func _prepare_screen(screen: StdScreen, instance: Node, urgent: bool) -> Preparation:
	if instance == null:
		var entry := _cache.get_entry(screen)
		if entry and entry.preparation and is_instance_valid(entry.scene):
			return entry.preparation

		if not screen.scene_path:
			return Preparation.failed()

	var scene_path := "" if instance else screen.scene_path

	return Preparation.create(scene_path, screen.get_dependency_paths(), urgent)


## _present_op presents an operation whose preparation is done.
##
## NOTE: The operation itself reports a screen that couldn't load, after its own checks,
## and leaves the stack as it was.
func _present_op(op: Operation) -> void:
	op._present(self, _finish_op.bind(op))


## _report_unloaded reports that `screen` couldn't open because its scene failed to load
## or it has none.
func _report_unloaded(screen: StdScreen) -> void:
	if screen.scene_path:
		_logger.error("Scene load failed.", {&"path": screen.scene_path})
	else:
		_logger.error("Missing scene_path and no instance.", {&"screen": str(screen)})

	screen_load_failed.emit(screen)


## _release_focus ends the focus claim the screen's overlay registered at mount, which
## focuses the control saved beneath it. A screen whose overlay was handed to another
## screen has no claim to end.
func _release_focus(screen: StdScreen) -> void:
	var overlay := _overlays.get_overlay(screen)
	if is_instance_valid(overlay) and is_instance_valid(_cursor):
		_cursor.release_focus(overlay)


## _request_close propagates close_requested to the topmost 'count' screens, top first.
## If no handler cancels, it pops those screens, which, as with `pop`, happens only if
## they are still the topmost screens when the pop runs. The bottom screen is never
## popped. The caller has already marked the event handled, so a cancelled close still
## consumes it.
func _request_close(event: InputEvent, count: int) -> void:
	if _queue.is_operating():
		return

	var target := maxi(1, _stack.size() - count)
	if _stack.size() <= target:
		return

	var screens: Array[StdScreen] = _stack.slice(target)

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

	var op := Pop.create_top(screens)
	_queue.enqueue_or_run(_execute_op.bind(op))


## _request_close_overlay requests a close of every screen in the topmost overlay, in
## response to a background click.
func _request_close_overlay(event: InputEvent) -> void:
	var overlay := _overlays.get_current(_stack)
	if not is_instance_valid(overlay):
		return

	# Walk backward from the top to find the overlay boundary.
	var count := 0
	for i in range(_stack.size() - 1, -1, -1):
		if _overlays.get_overlay(_stack[i]) != overlay:
			break
		count += 1

	_request_close(event, count)


## _request_close_top requests a close of the topmost screen only, in response to one of
## its `StdScreen.close_actions`.
func _request_close_top(event: InputEvent) -> void:
	_request_close(event, 1)


## _resolve_transition returns the transition to use for an operation.
func _resolve_transition(
	screen: StdScreen,
	explicit: StdTransition,
	operation: StringName = &"",
) -> StdTransition:
	if explicit:
		return explicit
	if operation == &"push" and screen.transition_push:
		return screen.transition_push
	if operation == &"pop" and screen.transition_pop:
		return screen.transition_pop
	return screen.transition


## _teardown force-stops any active transition, drops any operation waiting or queued,
## and frees all resources.
func _teardown() -> void:
	_force_stop()
	_end_wait()

	_active_op = null
	_queue.reset()

	# Emit lifecycle signals and queue-free active scenes. The stack is moved to a local
	# before iteration to guard against re-entrant calls.
	var stack := _stack
	_stack = []

	for i in range(stack.size() - 1, -1, -1):
		var s: StdScreen = stack[i]
		var sc: Node = _scenes.get(s)
		if sc and is_instance_valid(sc):
			s.exiting.emit(sc)
			screen_exiting.emit(s, sc)
			s.disconnect_signal_handlers(sc)
			s.exited.emit(sc)
			screen_exited.emit(s, sc)
			sc.queue_free()
		s.popped.emit(null)

	for s in stack:
		_free_attachments(s)

	# NOTE: The claims are released once the overlays are queued for deletion, so no
	# focus is restored into a scene on its way out.
	var overlays: Array[StdScreenOverlay] = []
	for s in stack:
		overlays.append(_overlays.get_overlay(s))

	_scenes.clear()
	_attachments.clear()
	_overlays.clear()
	_preparations.clear()

	if is_instance_valid(_cursor):
		for overlay in overlays:
			if is_instance_valid(overlay):
				_cursor.release_focus(overlay)

	# Defer remove + free so they run after notification propagation unwinds
	# (parent blocked) but before `print_orphan_nodes` (queue_free is too late).
	if _input_blocker and is_instance_valid(_input_blocker):
		if _input_blocker.get_parent():
			_input_blocker.get_parent().remove_child.call_deferred(_input_blocker)
		_input_blocker.free.call_deferred()
	_input_blocker = null

	_cache.clear()


## _teardown_scene disconnects signal handlers, emits exited, and frees or keeps the
## scene. The overlay mapping should be erased before calling this if the overlay is
## being reused. A scene kept in the tree is parked, with its handlers still connected,
## and keeps its overlay.
func _teardown_scene(screen: StdScreen, scene: Node) -> void:
	var entry := _cache.get_entry(screen)
	var is_kept_in_tree := (
		entry != null and entry.overlay != null and entry.scene == scene
	)

	if not is_kept_in_tree:
		screen.disconnect_signal_handlers(scene)

	screen.exited.emit(scene)
	screen_exited.emit(screen, scene)

	var preparation: Preparation = _preparations.get(screen)
	_preparations.erase(screen)

	# NOTE: Detach first. The overlay may be shared and survive this screen, and a
	# queued free would leave the scene in it, still receiving input, until the end
	# of the frame.
	_detach_scene(screen, scene)
	_free_attachments(screen)

	var overlay := _overlays.get_overlay(screen)
	_release_focus(screen)
	_overlays.erase(screen)

	if is_kept_in_tree:
		return

	# Keep or free the scene.
	if screen.cache_mode != StdScreen.CacheMode.NONE and is_instance_valid(scene):
		_cache.keep(screen, scene, preparation)
	elif is_instance_valid(scene):
		scene.queue_free()

	if not _cache.owns(overlay):
		_overlays.free_if_unused(overlay)

	# Clean up a stale entry if keeping was turned off.
	if screen.cache_mode == StdScreen.CacheMode.NONE:
		_cache.erase(screen)


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

	# NOTE: Detach before the uncover, while the screen beneath is still covered, so that
	# its loaders sync once, at the uncover, and not again for each node leaving.
	_detach_scene(screen, scene)
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


## _wait holds `op` until `preparation` is done, with input blocked and later calls
## queued behind it, so nothing on the stack changes until its loads have ended.
func _wait(op: Operation, preparation: Preparation) -> void:
	_waiting_op = op
	_waiting_preparation = preparation

	_queue.hold()
	_block_input()

	preparation.done.connect(_on_preparation_done, CONNECT_ONE_SHOT)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


## _on_preparation_done presents the waiting operation, from `StdLoader`'s step, once
## its preparation is done.
func _on_preparation_done() -> void:
	var op := _waiting_op

	_end_wait()

	if op == null:
		return

	_queue.resume(_present_op.bind(op))
