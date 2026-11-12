##
## screen/manager/manager_teardown_test.gd
##
## Tests pertaining to how `StdScreenManager` tears down when it leaves the tree or gets
## a close request propagated through the tree, as a game's shutdown sends it, and how
## it drops calls made during teardown.
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

# -- INITIALIZATION ------------------------------------------------------------------ #

var _engine_loader: LoadingTests.FakeEngineLoader = null
var _holder: Node = null
var _manager: StdScreenManager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_close_request_during_wait_tears_down_without_errors():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load, with input blocked.
	_manager.push(_create_screen(_PATH_SLOW))
	var blocker := _manager._input_blocker
	assert_true(blocker.is_inside_tree())

	# When: A close request is propagated through the tree.
	_propagate_close_request()

	# Then: The manager tore down without engine errors and settled.
	assert_engine_error_count(0)
	assert_eq(_manager.get_depth(), 0)
	assert_true(_manager.is_settled())

	# Then: The blocker is freed by the end of the frame.
	await wait_idle_frames(1)
	assert_freed(blocker, "input blocker")


func test_close_request_during_blocking_transition_tears_down_without_errors():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen entering through a transition that blocks input.
	_manager.push(_create_screen("", MockTransition.new()), Control.new())
	await wait_idle_frames(1)
	var active: MockTransition = _manager._active_transition
	var blocker := _manager._input_blocker
	assert_true(blocker.is_inside_tree())

	# When: A close request is propagated through the tree.
	_propagate_close_request()

	# Then: The transition was stopped without engine errors.
	assert_engine_error_count(0)
	assert_true(active.stopped)
	assert_eq(_manager.get_depth(), 0)

	# Then: The blocker is freed by the end of the frame.
	await wait_idle_frames(1)
	assert_freed(blocker, "input blocker")


func test_close_request_emits_settled_last_with_the_stack_empty():
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

	# When: A close request is propagated through the tree.
	_propagate_close_request()

	# Then: `settled` was emitted last, once the stack was empty.
	assert_eq(order, [&"exited", &"popped", &"settled"] as Array[StringName])
	assert_eq(seen.get(&"depth"), 0)
	assert_eq(seen.get(&"is_current"), false)


func test_close_request_drops_a_push_from_a_settled_handler():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load.
	_manager.push(_create_screen(_PATH_SLOW))

	# Given: A `settled` handler pushing a screen whose scene isn't loaded.
	var next := _create_screen(_PATH_NEXT)
	_manager.settled.connect(func() -> void: _manager.push(next), CONNECT_ONE_SHOT)

	# When: A close request is propagated through the tree.
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


func test_close_request_drops_a_push_from_a_popped_handler_and_frees_its_instance():
	# Given: A screen on the stack, whose `popped` handler pushes a new scene.
	var base := await _push_base()
	var instance := Control.new()
	base.popped.connect(
		func(_result: Variant) -> void: _manager.push(_create_screen(), instance)
	)

	# When: A close request is propagated through the tree.
	_propagate_close_request()

	# Then: The push was dropped with a warning and its scene freed.
	assert_push_warning(_WARNING)
	assert_engine_error_count(0)
	assert_freed(instance, "dropped instance")
	assert_eq(_manager.get_depth(), 0)
	assert_true(_manager.is_settled())


func test_close_request_drops_every_operation_from_an_exited_handler():
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

	# When: A close request is propagated through the tree.
	_propagate_close_request()

	# Then: Each operation was dropped with a warning, without engine errors.
	assert_push_warning_count(5)
	assert_engine_error_count(0)
	assert_eq(_manager.get_depth(), 0)
	assert_true(_manager.is_settled())

	# Then: Each scene handed over was freed.
	for instance in instances:
		assert_freed(instance, "dropped instance")


func test_close_request_drop_keeps_an_instance_with_a_parent():
	# Given: A screen on the stack, whose `popped` handler pushes a node in the tree.
	var base := await _push_base()
	var instance := Control.new()
	add_child_autofree(instance)
	base.popped.connect(
		func(_result: Variant) -> void: _manager.push(_create_screen(), instance)
	)

	# When: A close request is propagated through the tree.
	_propagate_close_request()

	# Then: The push was dropped, leaving the node with its parent.
	assert_push_warning(_WARNING)
	assert_not_freed(instance, "owned instance")
	assert_eq(instance.get_parent(), self)


func test_close_request_from_a_teardown_handler_is_ignored():
	# Given: Two screens on the stack, the top one's `popped` handler requesting a close.
	var base := await _push_base()
	var base_scene := _manager.get_scene()
	var top := _create_screen()
	_manager.push(top, Control.new())
	await wait_idle_frames(1)
	top.popped.connect(
		func(_result: Variant) -> void:
			_manager.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	)
	watch_signals(base)

	# When: A close request is propagated through the tree.
	_propagate_close_request()

	# Then: The screen beneath was still torn down, once.
	assert_signal_emit_count(base, "exited", 1)
	assert_signal_emit_count(base, "popped", 1)
	assert_true(base_scene.is_queued_for_deletion())


func test_close_request_then_exit_tree_emits_settled_once():
	# Given: A screen on the stack.
	await _push_base()

	# Given: A screen waiting for its scene to load.
	_manager.push(_create_screen(_PATH_SLOW))

	# Given: A `settled` handler pushing a screen whose scene isn't loaded.
	var next := _create_screen(_PATH_NEXT)
	_manager.settled.connect(func() -> void: _manager.push(next))
	watch_signals(_manager)

	# When: A close request is propagated through the tree.
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


## _propagate_close_request delivers a close request to the manager's subtree as a
## game's shutdown does, which leaves each node unable to add or remove children until
## it returns.
func _propagate_close_request() -> void:
	_holder.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)


func _push_base() -> StdScreen:
	var base := _create_screen()
	_manager.push(base, Control.new())
	await wait_idle_frames(1)
	return base
