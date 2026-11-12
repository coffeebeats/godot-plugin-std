# gdlint:ignore=max-public-methods

##
## screen/manager/manager_loading_test.gd
##
## Tests pertaining to how `StdScreenManager` waits for a screen's loads, completes an
## operation a later call interrupts, and keeps scenes between uses.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Preparation := preload("preparation.gd")
const TransitionTests := preload("../../transition/transition_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const MockTransition := TransitionTests.MockTransition  # gdlint:ignore=constant-name

const _PATH_HOST := "res://screen/manager/_test_host.tscn"
const _PATH_KEPT := "res://screen/manager/_test_kept.tscn"
const _PATH_LAYERED := "res://screen/manager/_test_layered.tscn"
const _PATH_LAYERING := "res://screen/manager/_test_layering.tscn"
const _PATH_SLOW := "res://screen/manager/_test_slow.tscn"


## Backend scripts the engine's loader for `StdLoader`: a path in `cached` loads at
## once, and any other path loads once a test calls `finish`.
class Backend:
	extends StdLoader.Backend

	var cached: Dictionary = {}
	var resources: Dictionary = {}
	var started: Array[String] = []
	var statuses: Dictionary = {}

	func finish(path: String, resource: Resource) -> void:
		resources[path] = resource
		statuses[path] = (
			ResourceLoader.THREAD_LOAD_LOADED
			if resource
			else ResourceLoader.THREAD_LOAD_FAILED
		)

	func get_cached(path: String) -> Resource:
		return cached.get(path)

	func get_progress(
		path: String, _progress: Array
	) -> ResourceLoader.ThreadLoadStatus:
		return statuses.get(path, ResourceLoader.THREAD_LOAD_IN_PROGRESS)

	func get_threaded(path: String) -> Resource:
		var resource: Resource = resources.get(path)
		if resource:
			cached[path] = resource

		return resource

	func has_cached(path: String) -> bool:
		return path in cached

	func load_blocking(path: String, _type_hint: String) -> Resource:
		return get_threaded(path)

	func start(path: String, _type_hint: String) -> Error:
		started.append(path)
		return OK


## Layering adds a `CanvasLayer` to itself as it readies, after the check made before it
## enters the tree.
class Layering:
	extends Control

	var layer: CanvasLayer = null

	func _ready() -> void:
		layer = CanvasLayer.new()
		add_child(layer)


## Recorder counts the screen notifications its subtree receives.
class Recorder:
	extends Control

	var covered: int = 0
	var readied: int = 0
	var uncovered: int = 0

	func _notification(what: int) -> void:
		if what == StdScreenManager.NOTIFICATION_SCREEN_COVERED:
			covered += 1
		elif what == StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED:
			uncovered += 1

	func _ready() -> void:
		readied += 1


# -- INITIALIZATION ------------------------------------------------------------------ #

var _backend: Backend = null
var _manager: StdScreenManager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_push_unloaded_scene_changes_nothing_until_loaded():
	# Given: A screen on the stack and a screen whose scene isn't loaded.
	await _push_base()
	var screen := _create_screen(_PATH_SLOW)

	# When: The screen is pushed.
	_manager.push(screen)

	# Then: Nothing changed, the manager is busy, and input is blocked.
	assert_eq(_manager.get_depth(), 1)
	assert_false(_manager.is_settled())
	assert_true(_manager._input_blocker.is_inside_tree())

	# When: The loader starts the load, the scene loads and the loader steps.
	StdLoader._step()
	_backend.finish(_PATH_SLOW, _pack(Control.new()))
	StdLoader._step()

	# Then: The screen mounted, input is unblocked and the manager settled.
	assert_true(_manager.is_current(screen))
	assert_false(_manager._input_blocker.is_inside_tree())
	assert_true(_manager.is_settled())


func test_push_unloaded_scene_requests_it_first():
	# Given: A screen whose scene and dependency scene aren't loaded.
	var screen := _create_screen(_PATH_SLOW)
	screen.dependency_scenes = PackedStringArray([_PATH_HOST])

	# When: The screen is pushed and the loader steps.
	_manager.push(screen)
	StdLoader._step()

	# Then: Its own scene was requested first.
	assert_eq(_backend.started, [_PATH_SLOW] as Array[String])


func test_push_during_wait_runs_after_the_waiting_operation():
	# Given: A screen waiting for its scene to load.
	await _push_base()
	var slow := _create_screen(_PATH_SLOW)
	_manager.push(slow)

	# When: Another screen is pushed with an instance meanwhile.
	var other := _create_screen()
	_manager.push(other, Control.new())

	# Then: Nothing ran ahead of the waiting push.
	assert_eq(_manager.get_depth(), 1)

	# When: The loader starts the load, the scene loads and the loader steps.
	StdLoader._step()
	_backend.finish(_PATH_SLOW, _pack(Control.new()))
	StdLoader._step()
	await wait_idle_frames(2)

	# Then: Both ran, in call order.
	assert_eq(_manager.get_depth(), 3)
	assert_eq(_manager.get_at(1), slow)
	assert_true(_manager.is_current(other))
	assert_true(_manager.is_settled())


func test_push_failed_load_leaves_stack_and_reports():
	# Given: A screen on the stack and a screen whose scene fails to load.
	await _push_base()
	var screen := _create_screen(_PATH_SLOW)
	watch_signals(_manager)

	# When: The screen is pushed and its load fails.
	_manager.push(screen)
	StdLoader._step()
	_backend.finish(_PATH_SLOW, null)
	StdLoader._step()

	# Then: The stack is unchanged and the failure was reported.
	assert_eq(_manager.get_depth(), 1)
	assert_signal_emitted_with_parameters(_manager, "screen_load_failed", [screen])
	assert_push_error("Failed to load resource.")
	assert_push_error("Scene load failed.")

	# Then: Input is unblocked and the manager settled.
	assert_false(_manager._input_blocker.is_inside_tree())
	assert_signal_emitted(_manager, "settled")
	assert_true(_manager.is_settled())


func test_push_missing_scene_path_reports_load_failure():
	# Given: A screen on the stack and a screen with neither a scene nor an instance.
	await _push_base()
	var screen := _create_screen()
	watch_signals(_manager)

	# When: The screen is pushed.
	_manager.push(screen)

	# Then: The stack is unchanged and the failure was reported.
	assert_eq(_manager.get_depth(), 1)
	assert_signal_emitted_with_parameters(_manager, "screen_load_failed", [screen])
	assert_push_error("Missing scene_path and no instance.")
	assert_true(_manager.is_settled())


func test_load_screen_held_preparation_lets_push_open_at_once():
	# Given: A screen whose scene is loaded through the manager in the background.
	var screen := _create_screen(_PATH_SLOW)
	var preparation := _manager.load_screen(screen)
	assert_false(preparation.is_done())

	StdLoader._step()
	_backend.finish(_PATH_SLOW, _pack(Control.new()))
	StdLoader._step()
	assert_true(preparation.is_done())

	# When: The screen is pushed.
	_manager.push(screen)

	# Then: It mounted inside the call.
	assert_true(_manager.is_current(screen))


func test_load_screen_without_a_scene_loads_its_dependencies():
	# Given: A screen pushed with an instance, whose attachment isn't loaded.
	var screen := _create_screen()
	screen.attachment_scenes = PackedStringArray([_PATH_SLOW])

	# When: It is loaded through the manager and the load ends.
	var preparation := _manager.load_screen(screen)
	StdLoader._step()
	_backend.finish(_PATH_SLOW, _pack(Control.new()))
	StdLoader._step()

	# Then: The preparation is done, with nothing to report.
	assert_true(preparation.is_done())
	assert_eq(preparation.get_error(), OK)

	# When: The screen is pushed with an instance.
	_manager.push(screen, Control.new())

	# Then: It mounted inside the call, with its attachment.
	assert_true(_manager.is_current(screen))
	assert_eq(_manager._attachments[screen].size(), 1)


func test_preparation_create_mixed_path_forms_one_file_is_done_after_load():
	# Given: A `uid://` for an unloaded scene.
	var id := ResourceUID.create_id()
	ResourceUID.add_id(id, _PATH_SLOW)

	# Given: A preparation naming that scene by `uid://` and by path.
	var preparation: Preparation = Preparation.create(
		ResourceUID.id_to_text(id), PackedStringArray([_PATH_SLOW])
	)
	watch_signals(preparation)

	# When: The scene finishes loading.
	StdLoader._step()
	_backend.finish(_PATH_SLOW, _pack(Control.new()))
	StdLoader._step()

	# Then: The preparation is done and reported it once.
	assert_true(preparation.is_done())
	assert_signal_emit_count(preparation, "done", 1)

	ResourceUID.remove_id(id)


func test_push_during_transition_completes_the_interrupted_push():
	# Given: A screen on the stack and a screen whose transition hasn't mounted it.
	await _push_base()
	var transition := MockTransition.new()
	var first := _create_screen(_PATH_HOST, transition)
	_backend.cached[_PATH_HOST] = _pack(Control.new())
	watch_signals(first)
	_manager.push(first)

	# When: Another screen is pushed before that transition ends.
	var second := _create_screen()
	_manager.push(second, Control.new())
	await wait_idle_frames(2)

	# Then: The first push completed, with its signals, under the second.
	assert_signal_emitted(first, "entering")
	assert_signal_emitted(first, "entered")
	assert_eq(_manager.get_at(1), first)
	assert_true(_manager.is_current(second))
	assert_true(_manager.is_settled())


func test_pop_during_transition_completes_the_interrupted_pop():
	# Given: Two screens, the top one popping through a transition that hasn't ended.
	await _push_base()
	var top := _create_screen()
	top.transition_pop = MockTransition.new()
	_manager.push(top, Control.new())
	watch_signals(top)
	_manager.pop()

	# When: Another screen is pushed before that transition ends.
	var other := _create_screen()
	_manager.push(other, Control.new())
	await wait_idle_frames(2)

	# Then: The pop completed, with its signals, before the push ran.
	assert_signal_emitted(top, "exited")
	assert_signal_emitted(top, "popped")
	assert_eq(_manager.get_depth(), 2)
	assert_true(_manager.is_current(other))


func test_pop_during_push_transition_leaves_the_pushed_screen():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A second screen above it.
	var middle := _create_screen()
	_manager.push(middle, Control.new())

	# Given: A third screen whose push transition hasn't mounted it.
	var top := _create_screen()
	top.transition_push = MockTransition.new()
	_manager.push(top, Control.new())
	watch_signals(middle)

	# When: A pop is called before that transition ends.
	_manager.pop()
	await wait_idle_frames(2)

	# Then: The pop asked the screen beneath, which wasn't on top once the push ran.
	assert_signal_emitted(middle, "close_requested")

	# Then: The push completed and the pop did nothing.
	assert_signal_not_emitted(middle, "popped")
	assert_eq(_manager.get_depth(), 3)
	assert_true(_manager.is_current(top))
	assert_true(_manager.is_settled())


func test_pop_during_push_wait_leaves_the_pushed_screen():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A second screen above it.
	var middle := _create_screen()
	_manager.push(middle, Control.new())

	# Given: A third screen waiting for its scene to load.
	var top := _create_screen(_PATH_SLOW)
	_manager.push(top)
	watch_signals(middle)

	# When: A pop is called while it waits.
	_manager.pop()

	# When: The third screen's scene finishes loading.
	StdLoader._step()
	_backend.finish(_PATH_SLOW, _pack(Control.new()))
	StdLoader._step()
	await wait_idle_frames(2)

	# Then: The pop asked the screen beneath, which wasn't on top once the push ran.
	assert_signal_emitted(middle, "close_requested")

	# Then: The push completed and the pop did nothing.
	assert_signal_not_emitted(middle, "popped")
	assert_eq(_manager.get_depth(), 3)
	assert_true(_manager.is_current(top))
	assert_true(_manager.is_settled())


func test_pop_to_during_push_wait_pops_to_the_target():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A second screen above it.
	var middle := _create_screen()
	_manager.push(middle, Control.new())

	# Given: A third screen waiting for its scene to load.
	_manager.push(_create_screen(_PATH_SLOW))

	# When: A pop to the second screen is called while it waits.
	_manager.pop_to(middle)

	# When: The third screen's scene finishes loading.
	StdLoader._step()
	_backend.finish(_PATH_SLOW, _pack(Control.new()))
	StdLoader._step()
	await wait_idle_frames(2)

	# Then: The push completed and the pop removed it, leaving the target on top.
	assert_eq(_manager.get_depth(), 2)
	assert_true(_manager.is_current(middle))
	assert_true(_manager.is_settled())


func test_pop_to_during_replace_wait_leaves_the_pushed_screen():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A second screen above it.
	var middle := _create_screen()
	_manager.push(middle, Control.new())

	# Given: A replacement of the second screen waiting for its scene to load.
	_manager.replace(_create_screen(_PATH_SLOW))

	# Given: A screen pushed with an instance behind it.
	var top := _create_screen()
	_manager.push(top, Control.new())

	# When: A pop to the second screen is called while the replacement waits.
	_manager.pop_to(middle)

	# When: The replacement's scene finishes loading.
	StdLoader._step()
	_backend.finish(_PATH_SLOW, _pack(Control.new()))
	StdLoader._step()
	await wait_idle_frames(2)

	# Then: The replace and push completed, and the pop found its target gone.
	assert_eq(_manager.get_depth(), 3)
	assert_true(_manager.is_current(top))
	assert_true(_manager.is_settled())


func test_close_during_push_transition_leaves_the_pushed_screen():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A second screen above it.
	var middle := _create_screen()
	_manager.push(middle, Control.new())

	# Given: A third screen whose non-blocking push hasn't mounted it.
	var transition := MockTransition.new()
	transition.block_input = false
	var top := _create_screen()
	top.transition_push = transition
	_manager.push(top, Control.new())
	watch_signals(middle)

	# When: A close of the top screen is requested before that transition ends.
	_manager._request_close_top(InputEventAction.new())
	await wait_idle_frames(2)

	# Then: The close asked the screen beneath, which wasn't on top once the push ran.
	assert_signal_emitted(middle, "close_requested")

	# Then: The push completed and the close did nothing.
	assert_signal_not_emitted(middle, "popped")
	assert_eq(_manager.get_depth(), 3)
	assert_true(_manager.is_current(top))
	assert_true(_manager.is_settled())


func test_pop_twice_during_pop_transition_pops_only_the_top_screen():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A second screen above it.
	var middle := _create_screen()
	_manager.push(middle, Control.new())

	# Given: A third screen leaving through a non-blocking transition.
	var transition := MockTransition.new()
	transition.block_input = false
	var top := _create_screen()
	top.transition_pop = transition
	_manager.push(top, Control.new())
	watch_signals(middle)
	watch_signals(top)
	_manager.pop()

	# When: A second pop is called before that transition ends.
	_manager.pop()
	await wait_idle_frames(2)

	# Then: The top screen was popped once.
	assert_signal_emit_count(top, "popped", 1)

	# Then: The screen beneath was neither asked nor popped.
	assert_signal_not_emitted(middle, "close_requested")
	assert_signal_not_emitted(middle, "popped")
	assert_eq(_manager.get_depth(), 2)
	assert_true(_manager.is_current(middle))
	assert_true(_manager.is_settled())


func test_close_twice_during_pop_transition_pops_only_the_top_screen():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A second screen above it.
	var middle := _create_screen()
	_manager.push(middle, Control.new())

	# Given: A third screen that pops through a non-blocking transition.
	var transition := MockTransition.new()
	transition.block_input = false
	var top := _create_screen()
	top.transition_pop = transition
	_manager.push(top, Control.new())
	watch_signals(middle)
	watch_signals(top)

	# When: A close of the top screen is requested, which starts its pop.
	_manager._request_close_top(InputEventAction.new())

	# When: A second close is requested before that transition ends.
	_manager._request_close_top(InputEventAction.new())
	await wait_idle_frames(2)

	# Then: The top screen was popped once.
	assert_signal_emit_count(top, "popped", 1)

	# Then: The screen beneath was neither asked nor popped.
	assert_signal_not_emitted(middle, "close_requested")
	assert_signal_not_emitted(middle, "popped")
	assert_eq(_manager.get_depth(), 2)
	assert_true(_manager.is_current(middle))
	assert_true(_manager.is_settled())


func test_teardown_during_wait_releases_input_and_settles():
	# Given: A screen waiting for its scene to load.
	await _push_base()
	_manager.push(_create_screen(_PATH_SLOW))
	watch_signals(_manager)

	# When: The manager leaves the tree.
	_manager._teardown()

	# Then: Input is unblocked and the manager settled.
	assert_null(_manager._input_blocker)
	assert_signal_emitted(_manager, "settled")
	assert_true(_manager.is_settled())


func test_in_tree_dependency_is_built_parked_at_host_mount():
	# Given: A host listing a screen kept in the tree as a dependency.
	var kept := _create_kept()
	var host := _create_screen(_PATH_HOST)
	host.dependency_screens = [kept]
	_backend.cached[_PATH_HOST] = _pack(Control.new())
	watch_signals(kept)

	# When: The host is pushed.
	_manager.push(host)

	# Then: The kept scene was built in the tree, hidden, disabled and covered.
	var scene: Recorder = _manager._cache.get_entry(kept).scene
	assert_true(scene.is_inside_tree())
	assert_false(scene.is_visible_in_tree())
	assert_eq(scene.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(scene.readied, 1)
	assert_eq(scene.covered, 1)

	# Then: It isn't on the stack and no lifecycle signal fired for it.
	assert_true(_manager.is_current(host))
	assert_eq(_manager.get_depth(), 1)
	assert_signal_not_emitted(kept, "entering")


func test_in_tree_open_shows_the_parked_scene():
	# Given: A host whose dependency, kept in the tree, is parked.
	var kept := _create_kept()
	await _push_host(kept)
	var scene: Recorder = _manager._cache.get_entry(kept).scene
	var overlay := scene.get_parent()

	# When: The kept screen is pushed.
	_manager.push(kept)

	# Then: The parked scene opened, shown on top, running and uncovered.
	assert_eq(_manager.get_scene(), scene)
	assert_true(scene.is_visible_in_tree())
	assert_eq(overlay.get_index(), _manager.get_child_count() - 1)
	assert_eq(scene.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(scene.uncovered, 1)
	assert_eq(scene.readied, 1)


func test_in_tree_close_parks_the_scene_and_keeps_handlers():
	# Given: An open screen kept in the tree, with a handler bound to its scene.
	var kept := _create_kept()
	await _push_host(kept)
	_manager.push(kept)
	var scene: Recorder = _manager.get_scene()
	kept.entering.connect(scene.set_meta.bind(&"opened", true).unbind(1))

	# When: The kept screen is popped.
	_manager.pop(null, true)

	# Then: The scene stays in the tree, parked again and covered.
	assert_true(is_instance_valid(scene))
	assert_true(scene.is_inside_tree())
	assert_false(scene.is_visible_in_tree())
	assert_eq(scene.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(scene.covered, 2)

	# Then: Its overlay takes no input while parked.
	var overlay: StdScreenOverlay = scene.get_parent()
	assert_eq(overlay.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(overlay.consumes_unhandled_input)
	assert_eq(overlay.close_actions, [] as Array[StringName])

	# Then: Its handler is still connected for the next open.
	assert_eq(kept.entering.get_connections().size(), 1)


func test_in_tree_reopen_moves_the_overlay_above_newer_screens():
	# Given: A parked screen kept in the tree, and a screen pushed after it was built.
	var kept := _create_kept()
	await _push_host(kept)
	var overlay: Node = _manager._cache.get_entry(kept).overlay
	_manager.push(_create_screen(), Control.new())

	# When: The kept screen is pushed.
	_manager.push(kept)

	# Then: Its overlay is the manager's topmost.
	assert_eq(overlay.get_index(), _manager.get_child_count() - 1)
	assert_eq(_manager.get_depth(), 3)


func test_in_tree_scene_that_cannot_park_is_kept_detached():
	# Given: A screen kept in the tree whose scene holds a `CanvasLayer`.
	var root := Control.new()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.owner = root
	var kept := _create_screen(_PATH_LAYERED)
	kept.cache_mode = StdScreen.CacheMode.IN_TREE
	_backend.cached[_PATH_LAYERED] = _pack(root)

	# When: A host listing it is pushed.
	await _push_host(kept)

	# Then: The scene was reported and kept out of the tree.
	assert_push_error("Scene can't be kept in the tree; keeping it detached.")
	var entry = _manager._cache.get_entry(kept)
	assert_null(entry.overlay)
	assert_false(entry.scene.is_inside_tree())


func test_in_tree_dependency_adding_a_layer_when_ready_is_kept_detached():
	# Given: A screen kept in the tree whose scene adds a `CanvasLayer` as it readies.
	var kept := _create_layering()

	# When: A host listing it is pushed.
	await _push_host(kept)

	# Then: The scene was reported and kept out of the tree, with its layer.
	assert_push_error("Scene can't be kept in the tree; keeping it detached.")
	var entry = _manager._cache.get_entry(kept)
	assert_null(entry.overlay)
	assert_false(entry.scene.is_inside_tree())
	assert_false(entry.scene.layer.is_inside_tree())


func test_in_tree_first_push_adding_a_layer_when_ready_detaches_on_pop():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen kept in the tree whose scene adds a `CanvasLayer` as it readies.
	var kept := _create_layering()

	# When: The kept screen is pushed.
	_manager.push(kept)
	var scene: Layering = _manager.get_scene()
	var overlay: Node = scene.get_parent()

	# When: It is popped.
	_manager.pop(null, true)

	# Then: The scene was reported and kept out of the tree, with its layer.
	assert_push_error("Scene can't be kept in the tree; keeping it detached.")
	var entry = _manager._cache.get_entry(kept)
	assert_null(entry.overlay)
	assert_eq(entry.scene, scene)
	assert_false(scene.is_inside_tree())
	assert_false(scene.layer.is_inside_tree())

	# Then: The overlay it opened in left the tree.
	assert_false(overlay.is_inside_tree())


func test_in_tree_ignores_block_input_below():
	# Given: A screen kept in the tree with `block_input_below` off.
	var kept := _create_kept()
	kept.block_input_below = false

	# When: A host listing it is pushed.
	await _push_host(kept)

	# Then: The setting was reported, and the kept scene has its own overlay.
	assert_push_warning("Ignored 'block_input_below'")
	assert_not_null(_manager._cache.get_entry(kept).overlay)


func test_teardown_frees_parked_scenes():
	# Given: A parked screen kept in the tree.
	var kept := _create_kept()
	await _push_host(kept)
	var scene: Node = _manager._cache.get_entry(kept).scene

	# When: The manager is removed from the tree.
	_manager.get_parent().remove_child(_manager)
	await wait_idle_frames(2)

	# Then: The parked scene was freed.
	assert_freed(scene, "parked scene")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	StdLoader._reset()


func before_each() -> void:
	StdLoader._reset()
	_backend = Backend.new()
	StdLoader._set_backend(_backend)

	add_child_autofree(StdInputCursor.new())

	_manager = StdScreenManager.new()
	add_child_autofree(_manager)
	await wait_idle_frames(1)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_kept() -> StdScreen:
	var screen := _create_screen(_PATH_KEPT)
	screen.cache_mode = StdScreen.CacheMode.IN_TREE
	_backend.cached[_PATH_KEPT] = _pack(Recorder.new())
	return screen


func _create_layering() -> StdScreen:
	var screen := _create_screen(_PATH_LAYERING)
	screen.cache_mode = StdScreen.CacheMode.IN_TREE
	_backend.cached[_PATH_LAYERING] = _pack(Layering.new())
	return screen


func _create_screen(path: String = "", transition: StdTransition = null) -> StdScreen:
	var screen := StdScreen.new()
	screen.scene_path = path
	screen.transition = transition
	return screen


## _pack returns a scene packed from `root`, which it frees.
func _pack(root: Node) -> PackedScene:
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _push_base() -> void:
	_manager.push(_create_screen(), Control.new())
	await wait_idle_frames(1)


func _push_host(kept: StdScreen) -> void:
	var host := _create_screen(_PATH_HOST)
	host.dependency_screens = [kept]
	_backend.cached[_PATH_HOST] = _pack(Control.new())
	_manager.push(host)
	await wait_idle_frames(1)
