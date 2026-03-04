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
var _sound_player = null

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


func test_pop_with_result_emits_popped_signal():
	# Given: A manager with two screens.
	await _do_push()
	var top := _create_screen()
	await _do_push(top)

	var received: Array = []
	top.popped.connect(func(r): received.append(r))

	# When: The top screen is popped with a result.
	_manager.pop("confirmed")
	await wait_idle_frames(1)

	# Then: The popped signal fires with the result.
	assert_eq(received.size(), 1)
	assert_eq(received[0], "confirmed")


func test_pop_without_result_emits_popped_null():
	# Given: A manager with two screens.
	await _do_push()
	var top := _create_screen()
	await _do_push(top)

	var received: Array = []
	top.popped.connect(func(r): received.append(r))

	# When: The top screen is popped without a result.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The popped signal fires with null.
	assert_eq(received.size(), 1)
	assert_eq(received[0], null)


func test_pop_to_emits_popped_null_for_each():
	# Given: A manager with three screens.
	var first := _create_screen()
	await _do_push(first)
	var second := _create_screen()
	await _do_push(second)
	var third := _create_screen()
	await _do_push(third)

	var popped_screens: Array[Screen] = []
	second.popped.connect(func(_r): popped_screens.append(second))
	third.popped.connect(func(_r): popped_screens.append(third))

	var results: Array = []
	second.popped.connect(func(r): results.append(r))
	third.popped.connect(func(r): results.append(r))

	# When: pop_to is called to the first screen.
	_manager.pop_to(first)
	await wait_idle_frames(1)

	# Then: Both removed screens received popped(null).
	assert_true(popped_screens.has(second))
	assert_true(popped_screens.has(third))
	assert_eq(results, [null, null])


func test_pop_with_transition_emits_popped_after_exited():
	# Given: Two screens; second has a transition set after push.
	await _do_push()
	var second := _create_screen()
	await _do_push(second)
	second.transition = MockTransition.new()

	var order: Array[String] = []
	second.exited.connect(func(_sc): order.append("exited"))
	second.popped.connect(func(_r): order.append("popped"))

	# When: The top screen is popped.
	_manager.pop("value")
	await wait_idle_frames(1)
	var active := _get_active_transition()
	assert_true(active.pop_started)

	# Then: Neither signal has fired yet.
	assert_eq(order.size(), 0)

	# When: The transition unmounts and completes.
	active.do_unmount()
	active.complete()
	await wait_idle_frames(1)

	# Then: exited fires before popped.
	assert_eq(order, ["exited", "popped"])


func test_pop_discards_screen_with_missing_scene():
	# Given: A manager with two screens.
	var first := _create_screen()
	await _do_push(first)
	var second := _create_screen()
	await _do_push(second)

	var received: Array = []
	second.popped.connect(func(r): received.append(r))

	# When: The top screen's scene is erased and the screen is popped.
	_manager._scenes.erase(second)
	_manager.pop(null, true)
	await wait_idle_frames(1)

	# Then: The expected error was logged.
	assert_push_error("Discarding screen with missing scene.")

	# Then: The broken screen was removed.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), first)

	# Then: The popped signal was emitted with null.
	assert_eq(received, [null])


func test_pop_to_discards_intermediate_with_missing_scene():
	# Given: Three screens; the top screen's scene is missing.
	var first := _create_screen()
	await _do_push(first)
	var second := _create_screen()
	await _do_push(second)
	var third := _create_screen()
	await _do_push(third)

	var popped: Array[Screen] = []
	second.popped.connect(func(_r): popped.append(second))
	third.popped.connect(func(_r): popped.append(third))

	# When: The top screen's scene is erased and pop_to targets
	# the first.
	_manager._scenes.erase(third)
	_manager.pop_to(first)
	await wait_idle_frames(1)

	# Then: The expected error was logged.
	assert_push_error(
		"Discarding screen with missing scene.",
	)

	# Then: Only the first screen remains.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), first)

	# Then: Both removed screens received popped(null).
	assert_true(popped.has(second))
	assert_true(popped.has(third))


func test_pop_plays_exit_sound():
	# Given: Two screens; the top has an exit sound.
	await _do_push()
	var top := _create_screen()
	var sound := StdSoundEvent.new()
	top.sound_exit = sound
	await _do_push(top)

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The exit sound was played.
	assert_called(_sound_player, "play")
	var params = get_call_parameters(_sound_player, "play")
	assert_eq(params[0], sound)


func test_pop_to_skips_exit_sound_for_intermediates():
	# Given: Three screens; second and third have exit sounds.
	var first := _create_screen()
	await _do_push(first)
	var second := _create_screen()
	var second_sound := StdSoundEvent.new()
	second.sound_exit = second_sound
	await _do_push(second)
	var third := _create_screen()
	third.sound_exit = StdSoundEvent.new()
	await _do_push(third)

	# When: pop_to targets the first screen.
	_manager.pop_to(first)
	await wait_idle_frames(1)

	# Then: Only the final pop's exit sound was played.
	assert_call_count(_sound_player, "play", 1)
	var params = get_call_parameters(_sound_player, "play")
	assert_eq(params[0], second_sound)


func test_pop_cancelled_does_not_emit_popped():
	# Given: Two screens; top has a handler that cancels.
	await _do_push()
	var top := _create_screen()
	await _do_push(top)
	top.close_requested.connect(
		func(_event, cancel): cancel.call(),
	)

	var received: Array = []
	top.popped.connect(func(r): received.append(r))

	# When: pop() is called (default force=false).
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The popped signal was not emitted.
	assert_eq(received.size(), 0)
	assert_eq(_manager.get_depth(), 2)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each():
	var cursor := StdInputCursor.new()
	add_child_autofree(cursor)

	_manager = Manager.new()
	add_child_autofree(_manager)
	await wait_idle_frames(1)

	_sound_player = autofree(double(StdSoundEventPlayer).new())
	stub(_sound_player, "play").to_return(null)
	_manager._sound_player = _sound_player


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
