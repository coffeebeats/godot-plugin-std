##
## screen/operation/reset_test.gd
##
## Tests pertaining to the reset screen operation.
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


func test_reset_clears_stack_and_pushes_new_base():
	# Given: A manager with three screens.
	await _do_push()
	await _do_push()
	await _do_push()

	# When: The stack is reset with a new screen.
	var new_base := _create_screen()
	_manager.reset(new_base, Control.new())
	await wait_idle_frames(1)

	# Then: Only the new base remains.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), new_base)


func test_reset_teardown_in_reverse_order():
	# Given: A manager with three screens.
	var screens: Array[Screen] = [
		_create_screen(),
		_create_screen(),
		_create_screen(),
	]
	for s in screens:
		await _do_push(s)

	var exiting_screens: Array[Screen] = []
	_manager.screen_exiting.connect(
		func(s, _sc): exiting_screens.append(s),
	)

	# When: The stack is reset.
	_manager.reset(_create_screen(), Control.new())
	await wait_idle_frames(1)

	# Then: All three received exiting in reverse order.
	assert_eq(
		exiting_screens,
		[screens[2], screens[1], screens[0]],
	)


func test_reset_emits_entered_on_new_base():
	# Given: A manager with two screens.
	await _do_push()
	await _do_push()
	watch_signals(_manager)

	# When: The stack is reset with a new screen.
	var new_base := _create_screen()
	var new_scene := Control.new()
	_manager.reset(new_base, new_scene)
	await wait_idle_frames(1)

	# Then: The new base screen received entered.
	assert_signal_emitted(_manager, "screen_entered")
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_entered",
		[new_base, new_scene],
	)


func test_reset_single_screen_stack():
	# Given: A manager with one screen.
	await _do_push()

	# When: The stack is reset with a new screen.
	var new_base := _create_screen()
	_manager.reset(new_base, Control.new())
	await wait_idle_frames(1)

	# Then: Only the new base remains.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), new_base)


func test_reset_with_transition_delays_entered():
	# Given: A manager with two screens.
	await _do_push()
	await _do_push()

	var transition := MockTransition.new()
	var new_base := _create_screen(transition)
	watch_signals(_manager)

	# When: The stack is reset with a transition.
	_manager.reset(new_base, Control.new())
	await wait_idle_frames(1)

	# Then: The transition started but entered not yet emitted.
	var active := _get_active_transition()
	assert_true(active.push_started)
	assert_signal_not_emitted(
		_manager,
		"screen_entered",
	)

	# When: The transition performs swap and completes.
	active.do_swap()
	active.complete()
	await wait_idle_frames(1)

	# Then: The entered signal is emitted.
	assert_signal_emitted(_manager, "screen_entered")
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_entered",
		[new_base, _manager.get_scene()],
	)


func test_reset_without_transition_emits_entered_immediately():
	# Given: A manager with two screens.
	await _do_push()
	await _do_push()
	watch_signals(_manager)

	# When: The stack is reset without a transition.
	var new_base := _create_screen()
	_manager.reset(new_base, Control.new())
	await wait_idle_frames(1)

	# Then: The entered signal is emitted immediately.
	assert_signal_emitted(_manager, "screen_entered")


func test_reset_with_transition_blocks_input():
	# Given: A manager with one screen.
	await _do_push()

	var transition := MockTransition.new()
	transition.block_input = true
	var new_base := _create_screen(transition)

	# When: The stack is reset and the transition starts.
	_manager.reset(new_base, Control.new())
	await wait_idle_frames(1)
	var active := _get_active_transition()
	assert_true(active.push_started)

	# Then: An input blocker is present.
	var blocker := (
		_manager
		. get_node_or_null(
			"TransitionInputBlocker",
		)
	)
	assert_not_null(blocker)

	# When: The transition completes.
	active.do_swap()
	active.complete()
	await wait_idle_frames(1)

	# Then: The input blocker is removed from the tree.
	assert_false(blocker.is_inside_tree())


func test_reset_emits_popped_null_for_all_screens():
	# Given: A manager with three screens.
	var screens: Array[Screen] = [
		_create_screen(),
		_create_screen(),
		_create_screen(),
	]
	for s in screens:
		await _do_push(s)

	var popped_screens: Array[Screen] = []
	for s in screens:
		s.popped.connect(
			func(_r, screen = s): popped_screens.append(screen),
		)

	var results: Array = []
	for s in screens:
		s.popped.connect(func(r): results.append(r))

	# When: The stack is reset.
	_manager.reset(_create_screen(), Control.new())
	await wait_idle_frames(1)

	# Then: All three screens received popped(null).
	assert_eq(popped_screens.size(), 3)
	for s in screens:
		assert_true(popped_screens.has(s))
	assert_eq(results, [null, null, null])


func test_reset_does_not_play_exit_sound():
	# Given: A screen with an exit sound.
	var screen := _create_screen()
	screen.sound_exit = StdSoundEvent.new()
	await _do_push(screen)

	# When: The stack is reset.
	_manager.reset(_create_screen(), Control.new())
	await wait_idle_frames(1)

	# Then: The exit sound was not played for the torn-down screen.
	assert_not_called(_sound_player, "play")


func test_reset_plays_enter_sound_for_new_base():
	# Given: A manager with one screen.
	await _do_push()

	# When: The stack is reset with a screen that has an enter sound.
	var new_base := _create_screen()
	var sound := StdSoundEvent.new()
	new_base.sound_enter = sound
	_manager.reset(new_base, Control.new())
	await wait_idle_frames(1)

	# Then: The new base's enter sound was played.
	assert_called(_sound_player, "play")
	var params = get_call_parameters(_sound_player, "play")
	assert_eq(params[0], sound)


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
