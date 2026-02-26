##
## screen/operation/pop_test.gd
##
## Tests pertaining to the pop screen operation.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const TransitionTests := preload("../transition_test.gd")
const Manager := preload("../manager/manager.gd")
const Screen := preload("../screen.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const MockTransition := TransitionTests.MockTransition  # gdlint:ignore=constant-name

# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: Manager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_pop_removes_top_screen():
	# Given: A manager with two screens.
	var first := _create_screen()
	await _do_push(first)
	await _do_push()

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Only the first remains.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), first)


func test_pop_emits_lifecycle_signals_in_order():
	# Given: A manager with two screens.
	var first := _create_screen()
	var first_scene := Control.new()
	await _do_push(first, first_scene)
	var second := _create_screen()
	var second_scene := Control.new()
	await _do_push(second, second_scene)

	var order: Array[String] = []
	_manager.screen_exiting.connect(
		func(_s, _sc): order.append("exiting"),
	)
	_manager.screen_uncovered.connect(
		func(_s, _sc): order.append("uncovered"),
	)
	_manager.screen_exited.connect(
		func(_s, _sc): order.append("exited"),
	)
	watch_signals(_manager)

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Signals fire in the correct order.
	assert_eq(
		order,
		["exiting", "uncovered", "exited"],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_exiting",
		[second, second_scene],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_exited",
		[second, second_scene],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_uncovered",
		[first, first_scene],
	)


func test_pop_to_target_screen():
	# Given: A manager with three screens.
	var first := _create_screen()
	await _do_push(first)
	await _do_push()
	await _do_push()

	# When: pop_to is called with the first screen.
	_manager.pop_to(first)
	await wait_idle_frames(1)

	# Then: Only the first screen remains.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), first)


func test_pop_to_skips_intermediate_transitions():
	# Given: Three screens; transitions set after push.
	var screens: Array[Screen] = []
	for i in range(3):
		screens.append(_create_screen())
	for s in screens:
		await _do_push(s)
	for s in screens:
		s.transition = MockTransition.new()

	# When: pop_to is called to the first screen.
	_manager.pop_to(screens[0])
	await wait_idle_frames(1)

	# Then: Only the last pop's exit transition is active.
	assert_not_null(_manager._active_transition)
	assert_true(_get_active_transition().pop_started)


func test_pop_intermediate_emits_exiting_for_each():
	# Given: A manager with three screens.
	var first := _create_screen()
	await _do_push(first)
	var second := _create_screen()
	await _do_push(second)
	var third := _create_screen()
	await _do_push(third)

	var exiting_screens: Array[Screen] = []
	_manager.screen_exiting.connect(
		func(s, _sc): exiting_screens.append(s),
	)

	# When: pop_to is called to the first screen.
	_manager.pop_to(first)
	await wait_idle_frames(1)

	# Then: Each intermediate screen received an exiting signal.
	assert_true(exiting_screens.has(third))
	assert_true(exiting_screens.has(second))


func test_pop_at_target_depth_completes_immediately():
	# Given: A manager with one screen (already at depth 1).
	var screen := _create_screen()
	await _do_push(screen)
	watch_signals(_manager)

	# When: pop_to is called targeting the current screen.
	_manager.pop_to(screen)
	await wait_idle_frames(1)

	# Then: The stack is unchanged (no-op).
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), screen)
	assert_signal_not_emitted(_manager, "screen_exiting")


func test_pop_emits_screen_level_signals():
	# Given: A base screen and a tracked screen.
	await _do_push()
	var screen := _create_screen()
	watch_signals(screen)
	await _do_push(screen)

	# When: The screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Pop lifecycle signals were emitted on the screen.
	assert_signal_emitted(screen, "exiting")
	assert_signal_emitted(screen, "exited")


func test_pop_with_transition_delays_exited():
	# Given: Two screens; second has a transition set after push.
	await _do_push()
	var second := _create_screen()
	await _do_push(second)
	second.transition = MockTransition.new()
	watch_signals(_manager)

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)
	var active := _get_active_transition()
	assert_true(active.pop_started)
	assert_signal_not_emitted(_manager, "screen_exited")

	# When: The transition unmounts and completes.
	active.do_unmount()
	active.complete()
	await wait_idle_frames(1)

	# Then: The exited signal is emitted.
	assert_signal_emitted(_manager, "screen_exited")


func test_pop_with_transition_blocks_input():
	# Given: Two screens; second has a blocking transition set after push.
	await _do_push()
	var second := _create_screen()
	await _do_push(second)
	var transition := MockTransition.new()
	transition.block_input = true
	second.transition = transition

	# When: The top screen is popped and the transition starts.
	_manager.pop()
	await wait_idle_frames(1)
	var active := _get_active_transition()
	assert_true(active.pop_started)

	# Then: An input blocker is present.
	var blocker := (
		_manager
		. get_node_or_null(
			"TransitionInputBlocker",
		)
	)
	assert_not_null(blocker)

	# When: The transition completes.
	active.do_unmount()
	active.complete()
	await wait_idle_frames(1)

	# Then: The input blocker is removed from the tree.
	assert_false(blocker.is_inside_tree())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each():
	var cursor := StdInputCursor.new()
	add_child_autofree(cursor)

	_manager = Manager.new()
	add_child_autofree(_manager)
	await wait_idle_frames(1)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_screen(
	transition: StdScreenTransition = null,
	block_input_below: bool = true,
) -> Screen:
	var screen := Screen.new()
	screen.transition = transition
	screen.block_input_below = block_input_below
	return screen


func _do_push(
	screen: Screen = null,
	scene: Control = null,
) -> void:
	if not screen:
		screen = _create_screen()
	if not scene:
		scene = Control.new()
	_manager.push(screen, scene)
	await wait_idle_frames(1)


func _get_active_transition() -> MockTransition:
	return _manager._active_transition
