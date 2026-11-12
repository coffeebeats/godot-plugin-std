# gdlint:ignore=max-public-methods
##
## screen/manager/manager_teardown_test.gd
##
## Tests pertaining to how `StdScreenManager` tears down, from `tear_down` or leaving
## the tree, how it drops calls made during teardown, and how a close request keeps its
## stack and defers later calls to the end of the frame.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const LoadingTests := preload("manager_loading_test.gd")
const TransitionTests := preload("../../transition/transition_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const MockTransition := TransitionTests.MockTransition  # gdlint:ignore=constant-name

const _PATH_NEXT := "res://screen/manager/_test_next.tscn"
const _PATH_SLOW := "res://screen/manager/_test_slow.tscn"
const _WARNING := "Ignored; manager is tearing down."
const _WARNING_NO_SCREEN := "Ignored; no screen to act on until the end of the frame."


## CloseRequestScene is a scene which calls `on_close_request` when a close request
## reaches it.
class CloseRequestScene:
	extends Control

	var on_close_request: Callable

	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_CLOSE_REQUEST and on_close_request.is_valid():
			on_close_request.call()


# -- INITIALIZATION ------------------------------------------------------------------ #

var _engine_loader: LoadingTests.FakeEngineLoader = null
var _holder: Node = null
var _manager: StdScreenManager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_tear_down_during_wait_tears_down_without_errors():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load, with input blocked.
	_manager.push(_create_screen(_PATH_SLOW))
	var blocker := _manager._input_blocker
	assert_true(blocker.is_inside_tree())

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The manager tore down without engine errors and settled.
	assert_engine_error_count(0)
	assert_eq(_manager.get_depth(), 0)
	assert_true(_manager.is_settled())

	# Then: The blocker is freed by the end of the frame.
	await wait_idle_frames(1)
	assert_freed(blocker, "input blocker")


func test_tear_down_during_blocking_transition_tears_down_without_errors():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen entering through a transition that blocks input.
	_manager.push(_create_screen("", MockTransition.new()), Control.new())
	await wait_idle_frames(1)
	var active: MockTransition = _manager._active_transition
	var blocker := _manager._input_blocker
	assert_true(blocker.is_inside_tree())

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The transition was stopped without engine errors.
	assert_engine_error_count(0)
	assert_true(active.stopped)
	assert_eq(_manager.get_depth(), 0)

	# Then: The blocker is freed by the end of the frame.
	await wait_idle_frames(1)
	assert_freed(blocker, "input blocker")


func test_tear_down_emits_settled_last_with_the_stack_empty():
	# Given: A screen on the stack.
	var base := await _push_base()

	# Given: A screen waiting for its scene to load.
	_manager.push(_create_screen(_PATH_SLOW))

	# Given: Handlers recording the order of teardown's signals and the stack's state.
	var order: Array[StringName] = []
	var seen := {}
	base.exited.connect(func(_scene: Node) -> void: order.append(&"exited"))
	base.popped.connect(func(_result: Variant) -> void: order.append(&"popped"))
	_manager.settled.connect(
		func() -> void:
			order.append(&"settled")
			seen[&"depth"] = _manager.get_depth()
			seen[&"is_current"] = _manager.is_current(base)
	)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: `settled` was emitted last, once the stack was empty.
	assert_eq(order, [&"exited", &"popped", &"settled"] as Array[StringName])
	assert_eq(seen.get(&"depth"), 0)
	assert_eq(seen.get(&"is_current"), false)


func test_tear_down_drops_a_push_from_a_settled_handler():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load.
	_manager.push(_create_screen(_PATH_SLOW))

	# Given: A `settled` handler pushing a screen whose scene isn't loaded.
	var next := _create_screen(_PATH_NEXT)
	_manager.settled.connect(func() -> void: _manager.push(next), CONNECT_ONE_SHOT)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The push was dropped with a warning, leaving nothing waiting.
	assert_push_warning(_WARNING)
	assert_engine_error_count(0)
	assert_null(_manager._waiting_op)
	assert_true(_manager.is_settled())

	# When: The dropped screen's scene finishes loading.
	StdLoader._step()
	_engine_loader.finish(_PATH_NEXT, _pack(Control.new()))
	StdLoader._step()
	await wait_idle_frames(2)

	# Then: Nothing was mounted.
	assert_eq(_manager.get_depth(), 0)


func test_tear_down_drops_a_push_from_a_popped_handler_and_frees_its_instance():
	# Given: A screen on the stack.
	var base := await _push_base()

	# Given: Its `popped` handler pushes a new scene.
	var instance := Control.new()
	base.popped.connect(
		func(_result: Variant) -> void: _manager.push(_create_screen(), instance)
	)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The push was dropped with a warning and its scene freed.
	assert_push_warning(_WARNING)
	assert_engine_error_count(0)
	assert_freed(instance, "dropped instance")
	assert_eq(_manager.get_depth(), 0)
	assert_true(_manager.is_settled())


func test_tear_down_drops_every_operation_from_an_exited_handler():
	# Given: Two screens on the stack.
	var base := await _push_base()
	var top := _create_screen()
	_manager.push(top, Control.new())
	await wait_idle_frames(1)

	# Given: An `exited` handler calling every operation, handing over new scenes.
	var instances: Array[Node] = [Control.new(), Control.new(), Control.new()]
	top.exited.connect(
		func(_scene: Node) -> void:
			_manager.pop()
			_manager.pop_to(base)
			_manager.push(_create_screen(), instances[0])
			_manager.replace(_create_screen(), instances[1])
			_manager.reset(_create_screen(), instances[2]),
		CONNECT_ONE_SHOT,
	)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: Each operation was dropped with a warning, without engine errors.
	assert_push_warning_count(5)
	assert_engine_error_count(0)
	assert_eq(_manager.get_depth(), 0)
	assert_true(_manager.is_settled())

	# Then: Each scene handed over was freed.
	for instance in instances:
		assert_freed(instance, "dropped instance")


func test_tear_down_drop_keeps_an_instance_with_a_parent():
	# Given: A screen on the stack.
	var base := await _push_base()

	# Given: Its `popped` handler pushes a node in the tree.
	var instance := Control.new()
	add_child_autofree(instance)
	base.popped.connect(
		func(_result: Variant) -> void: _manager.push(_create_screen(), instance)
	)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The push was dropped, leaving the node with its parent.
	assert_push_warning(_WARNING)
	assert_not_freed(instance, "owned instance")
	assert_eq(instance.get_parent(), self)


func test_tear_down_from_a_teardown_handler_is_ignored():
	# Given: Two screens on the stack.
	var base := await _push_base()
	var base_scene := _manager.get_scene()
	var top := _create_screen()
	_manager.push(top, Control.new())
	await wait_idle_frames(1)

	# Given: The top screen's `popped` handler tears the manager down again.
	top.popped.connect(func(_result: Variant) -> void: _manager.tear_down())
	watch_signals(base)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The screen beneath was still torn down, once.
	assert_signal_emit_count(base, "exited", 1)
	assert_signal_emit_count(base, "popped", 1)
	assert_true(base_scene.is_queued_for_deletion())


func test_tear_down_then_exit_tree_emits_settled_once():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load.
	_manager.push(_create_screen(_PATH_SLOW))

	# Given: A `settled` handler pushing a screen whose scene isn't loaded.
	var next := _create_screen(_PATH_NEXT)
	_manager.settled.connect(func() -> void: _manager.push(next))
	watch_signals(_manager)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: `settled` was emitted once.
	assert_signal_emit_count(_manager, "settled", 1)

	# When: The manager then leaves the tree.
	_holder.remove_child(_manager)

	# Then: `settled` wasn't emitted again.
	assert_signal_emit_count(_manager, "settled", 1)
	assert_true(_manager.is_settled())


func test_exit_tree_drops_a_push_from_a_settled_handler():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load, with input blocked.
	_manager.push(_create_screen(_PATH_SLOW))
	var blocker := _manager._input_blocker

	# Given: A `settled` handler pushing a new scene.
	var instance := Control.new()
	_manager.settled.connect(
		func() -> void: _manager.push(_create_screen(), instance), CONNECT_ONE_SHOT
	)

	# When: The manager leaves the tree.
	_holder.remove_child(_manager)

	# Then: The push was dropped with a warning, mounting nothing.
	assert_push_warning(_WARNING)
	assert_engine_error_count(0)
	assert_freed(instance, "dropped instance")
	assert_eq(_manager.get_depth(), 0)
	assert_true(_manager.is_settled())

	# Then: The blocker is freed by the end of the frame.
	await wait_idle_frames(2)
	assert_freed(blocker, "input blocker")
	assert_eq(_manager.get_depth(), 0)


func test_exit_tree_then_reenter_tree_navigates_normally():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load.
	_manager.push(_create_screen(_PATH_SLOW))

	# Given: A `settled` handler pushing a new scene.
	_manager.settled.connect(
		func() -> void: _manager.push(_create_screen(), Control.new()), CONNECT_ONE_SHOT
	)

	# Given: The manager left the tree.
	_holder.remove_child(_manager)
	await wait_idle_frames(1)

	# When: The manager re-enters the tree and a screen is pushed.
	_holder.add_child(_manager)
	var screen := _create_screen()
	_manager.push(screen, Control.new())
	await wait_idle_frames(1)

	# Then: The screen is the only one on the stack, and the manager settled.
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(screen))
	assert_true(_manager.is_settled())


func test_exit_tree_then_reenter_tree_in_one_frame_navigates_at_once():
	# Given: A screen on the stack.
	await _push_base()

	# Given: The manager left the tree and re-entered it in one frame, as a reparent does.
	_holder.remove_child(_manager)
	_holder.add_child(_manager)

	# When: A screen is pushed in the same frame.
	var screen := _create_screen()
	_manager.push(screen, Control.new())

	# Then: The screen is on the stack at once.
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(screen))
	assert_engine_error_count(0)


func test_exit_tree_frees_an_instance_queued_behind_a_wait():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load, with a push queued behind it.
	_manager.push(_create_screen(_PATH_SLOW))
	var instance := Control.new()
	_manager.push(_create_screen(), instance)

	# When: The manager leaves the tree.
	_holder.remove_child(_manager)

	# Then: The queued push's instance was freed.
	assert_false(is_instance_valid(instance))


func test_tear_down_frees_an_instance_queued_behind_a_wait():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load, with a push queued behind it.
	_manager.push(_create_screen(_PATH_SLOW))
	var instance := Control.new()
	_manager.push(_create_screen(), instance)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The queued push's instance was freed, without engine errors.
	assert_false(is_instance_valid(instance))
	assert_engine_error_count(0)


func test_tear_down_frees_the_instances_of_a_queued_replace_and_reset():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load.
	_manager.push(_create_screen(_PATH_SLOW))

	# Given: A replace and a reset queued behind it.
	var replaced := Control.new()
	_manager.replace(_create_screen(), replaced)
	var reset := Control.new()
	_manager.reset(_create_screen(), reset)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: Both queued instances were freed.
	assert_false(is_instance_valid(replaced))
	assert_false(is_instance_valid(reset))


func test_tear_down_frees_an_instance_waiting_on_a_dependency():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A push whose instance waits for a dependency to load.
	var screen := _create_screen()
	screen.dependency_scenes = PackedStringArray([_PATH_SLOW])
	var instance := Control.new()
	_manager.push(screen, instance)
	assert_false(_manager.is_settled(), "precondition")

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The waiting push's instance was freed.
	assert_false(is_instance_valid(instance))


func test_tear_down_frees_an_instance_queued_behind_a_transition():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen entering through a running transition.
	_manager.push(_create_screen("", MockTransition.new()), Control.new())
	await wait_idle_frames(1)

	# Given: A push queued behind the transition, due to run at the end of the frame.
	var instance := Control.new()
	_manager.push(_create_screen(), instance)

	# When: The manager is torn down and a close request propagated in the same frame.
	_propagate_close_request()

	# Then: The queued push's instance was freed.
	assert_false(is_instance_valid(instance))


func test_tear_down_keeps_a_queued_instance_with_a_parent():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load.
	_manager.push(_create_screen(_PATH_SLOW))

	# Given: A push queued behind it, handed an instance with a parent.
	var parent := Node.new()
	add_child_autofree(parent)
	var instance := Control.new()
	parent.add_child(instance)
	_manager.push(_create_screen(), instance)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The instance its parent owns was kept.
	assert_true(is_instance_valid(instance))


func test_tear_down_runs_a_push_from_a_scene_torn_down_at_the_end_of_the_frame():
	# Given: A scene on the stack which pushes a screen on a close request.
	var scene := CloseRequestScene.new()
	var screen := _create_screen()
	var instance := Control.new()
	scene.on_close_request = func() -> void: _manager.push(screen, instance)
	await _push_base(scene)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The push waits, without engine errors.
	assert_engine_error_count(0)
	assert_eq(_manager.get_depth(), 0)
	assert_false(_manager.is_settled())

	# Then: The push ran by the end of the frame.
	await wait_idle_frames(1)
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(screen))
	assert_true(instance.is_inside_tree())


func test_tear_down_drops_a_pop_from_a_scene_torn_down():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A scene above it which pops on a close request.
	var scene := CloseRequestScene.new()
	scene.on_close_request = func() -> void: _manager.pop()
	_manager.push(_create_screen(), scene)
	await wait_idle_frames(1)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The pop was dropped with a warning, without engine errors.
	assert_push_warning(_WARNING_NO_SCREEN)
	assert_engine_error_count(0)
	assert_eq(_manager.get_depth(), 0)


func test_tear_down_drops_a_replace_from_a_scene_torn_down_and_frees_its_instance():
	# Given: A scene on the stack which replaces itself on a close request.
	var scene := CloseRequestScene.new()
	var instance := Control.new()
	scene.on_close_request = func() -> void:
		_manager.replace(_create_screen(), instance)
	await _push_base(scene)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()

	# Then: The replace was dropped with a warning, and its instance freed.
	assert_push_warning(_WARNING_NO_SCREEN)
	assert_engine_error_count(0)
	assert_false(is_instance_valid(instance))


func test_tear_down_runs_a_push_from_a_node_after_the_manager():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A node after the manager which opens a quit confirm on a close request.
	var node := CloseRequestScene.new()
	var confirm := _create_screen()
	node.on_close_request = func() -> void: _manager.push(confirm, Control.new())
	_holder.add_child(node)

	# When: The manager is torn down and a close request propagated.
	_propagate_close_request()
	await wait_idle_frames(1)

	# Then: The confirm screen opened, without engine errors.
	assert_engine_error_count(0)
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(confirm))


func test_tear_down_then_push_navigates_by_the_end_of_the_frame():
	# Given: A screen on the stack.
	await _push_base()

	# Given: The manager was torn down and a close request propagated.
	_propagate_close_request()

	# When: A screen is pushed in the same frame.
	var screen := _create_screen()
	_manager.push(screen, Control.new())
	await wait_idle_frames(1)

	# Then: The screen is on the stack, and the manager settled.
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(screen))
	assert_true(_manager.is_settled())


func test_tear_down_then_push_emits_settled_once_it_runs():
	# Given: A screen on the stack.
	await _push_base()

	# Given: The manager was torn down and a close request propagated.
	_propagate_close_request()
	watch_signals(_manager)

	# When: A screen is pushed in the same frame.
	_manager.push(_create_screen(), Control.new())

	# Then: The manager is not settled until the push runs.
	assert_false(_manager.is_settled())
	assert_signal_not_emitted(_manager, "settled")

	# Then: The manager settled once the push ran.
	await wait_idle_frames(1)
	assert_signal_emit_count(_manager, "settled", 1)
	assert_true(_manager.is_settled())


func test_tear_down_alone_drops_a_pop_made_later_in_the_frame():
	# Given: A screen on the stack.
	await _push_base()

	# Given: The manager was torn down alone, as when a game quits from a button.
	_manager.tear_down()

	# When: A pop is made later in the same frame.
	_manager.pop()

	# Then: The pop was dropped with a warning, without engine errors.
	assert_push_warning(_WARNING_NO_SCREEN)
	assert_engine_error_count(0)


func test_tear_down_then_navigate_while_in_tree_navigates_normally():
	# Given: A screen on the stack.
	await _push_base()

	# Given: The manager was torn down and a close request propagated.
	_propagate_close_request()
	await wait_idle_frames(2)
	assert_eq(_manager.get_depth(), 0)

	# When: A screen is pushed onto the manager, which never left the tree.
	var screen := _create_screen()
	_manager.push(screen, Control.new())
	await wait_idle_frames(1)

	# Then: The screen is the only one on the stack, and the manager settled.
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_current(screen))
	assert_true(_manager.is_settled())

	# Then: Nothing was dropped.
	assert_push_warning_count(0)
	assert_engine_error_count(0)


func test_close_request_keeps_the_stack_and_navigates_normally():
	# Given: Two screens on the stack.
	var base := await _push_base()
	_manager.push(_create_screen(), Control.new())
	await wait_idle_frames(1)

	# When: A close request alone is propagated, as for a quit a game then cancels.
	_holder.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

	# Then: The stack was kept.
	assert_eq(_manager.get_depth(), 2)

	# When: The top screen is popped in the same frame.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The screen beneath is on top, with nothing dropped and no errors.
	assert_true(_manager.is_current(base))
	assert_eq(_manager.get_depth(), 1)
	assert_true(_manager.is_settled())
	assert_push_warning_count(0)
	assert_engine_error_count(0)


func test_close_request_push_from_a_scene_then_pop_returns_to_the_game():
	# Given: A scene on the stack which pushes a quit-confirm screen on a close request.
	var scene := CloseRequestScene.new()
	var confirm := _create_screen()
	scene.on_close_request = func() -> void: _manager.push(confirm, Control.new())
	var base := await _push_base(scene)

	# When: A close request alone is propagated through the tree.
	_holder.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

	# Then: The push waits for the end of the frame, without engine errors.
	assert_engine_error_count(0)
	assert_eq(_manager.get_depth(), 1)

	# Then: The confirm screen opened by the end of the frame.
	await wait_idle_frames(1)
	assert_true(_manager.is_current(confirm))

	# When: The player declines, popping the confirm screen.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The game's screen is back on top, without engine errors.
	assert_true(_manager.is_current(base))
	assert_eq(_manager.get_depth(), 1)
	assert_engine_error_count(0)


func test_tear_down_then_close_request_then_exit_tree_frees_everything():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen kept detached by the cache.
	var kept := _create_screen()
	kept.cache_mode = StdScreen.CacheMode.DETACHED
	_manager.push(kept, Control.new())
	await wait_idle_frames(1)
	_manager.pop()
	await wait_idle_frames(1)
	var kept_scene: Node = _manager._cache.get_entry(kept).scene
	assert_false(kept_scene.is_inside_tree(), "precondition")

	# Given: An idle input blocker, out of the tree.
	_manager._block_input()
	_manager._unblock_input()
	var blocker := _manager._input_blocker
	assert_false(blocker.is_inside_tree(), "precondition")

	# When: The manager is torn down and a close request then propagated.
	_manager.tear_down()
	_holder.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

	# Then: The detached scene was freed at once, without engine errors.
	assert_freed(kept_scene, "kept scene")
	assert_engine_error_count(0)

	# When: The manager leaves the tree.
	_holder.remove_child(_manager)
	await wait_idle_frames(2)

	# Then: The blocker was freed and the stack is empty, without engine errors.
	assert_freed(blocker, "input blocker")
	assert_eq(_manager.get_depth(), 0)
	assert_engine_error_count(0)


func test_manager_joins_group_in_tree_and_leaves_on_exit():
	var group := StdGroup.with_id(StdScreenManager.GROUP_SCREEN_MANAGER)

	# Then: A manager in the tree is a member of the group.
	assert_true(_manager in group.list_members())

	# When: The manager leaves the tree.
	_holder.remove_child(_manager)

	# Then: It left the group.
	assert_false(_manager in group.list_members())

	# When: The manager re-enters the tree.
	_holder.add_child(_manager)

	# Then: It rejoined the group, once.
	assert_eq(group.list_members().count(_manager), 1)


func test_tear_down_before_ready_does_nothing():
	# Given: A manager which was never added to the tree, so it isn't ready.
	var manager: StdScreenManager = autofree(StdScreenManager.new())

	# When: It is torn down.
	manager.tear_down()

	# Then: Nothing failed.
	assert_engine_error_count(0)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	if is_instance_valid(_manager) and _manager.get_parent() == null:
		_manager.free()

	StdLoader._reset()


func before_each() -> void:
	StdLoader._reset()
	_engine_loader = LoadingTests.FakeEngineLoader.new()
	StdLoader._set_engine_loader(_engine_loader)

	add_child_autofree(StdInputCursor.new())

	_holder = Node.new()
	add_child_autofree(_holder)

	_manager = StdScreenManager.new()
	_holder.add_child(_manager)
	await wait_idle_frames(1)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _create_screen returns a screen with the scene at `path`, if any, and `transition`.
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


## _propagate_close_request tears the manager down and then delivers a close request
## to its subtree, in the order a game's certain shutdown does, which leaves each node
## unable to add or remove children until it returns.
func _propagate_close_request() -> void:
	_manager.tear_down()
	_holder.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)


## _push_base pushes a base screen with `scene`, or an empty control, as its scene.
func _push_base(scene: Node = null) -> StdScreen:
	var base := _create_screen()
	_manager.push(base, scene if scene else Control.new())
	await wait_idle_frames(1)
	return base
