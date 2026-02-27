##
## screen/operation/push_test.gd
##
## Tests pertaining to the push screen operation.
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


func test_push_adds_screen_to_stack():
	# When: A screen is pushed.
	var screen := _create_screen()
	await _do_push(screen)

	# Then: The stack has one screen.
	assert_eq(_manager.get_depth(), 1)
	assert_eq(_manager.get_current_screen(), screen)


func test_push_duplicate_screen_is_dropped():
	# Given: A manager with one screen.
	var screen := _create_screen()
	await _do_push(screen)

	# When: The same screen is pushed again.
	var dup: Control = autofree(Control.new())
	_manager.push(screen, dup)
	await wait_idle_frames(1)

	# Then: The stack depth remains 1.
	assert_eq(_manager.get_depth(), 1)


func test_push_emits_lifecycle_signals_in_order():
	# Given: A manager with one screen and signal tracking.
	var first_screen := _create_screen()
	var first_scene := Control.new()
	await _do_push(first_screen, first_scene)

	var second_screen := _create_screen()
	var second_scene := Control.new()
	var order: Array[String] = []
	_manager.screen_entering.connect(
		func(_s, _sc): order.append("entering"),
	)
	_manager.screen_entered.connect(
		func(_s, _sc): order.append("entered"),
	)
	_manager.screen_covered.connect(
		func(_s, _sc): order.append("covered"),
	)
	watch_signals(_manager)

	# When: A second screen is pushed.
	await _do_push(second_screen, second_scene)

	# Then: Signals fire in the correct order.
	assert_eq(
		order,
		["entering", "entered", "covered"],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_entering",
		[second_screen, second_scene],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_entered",
		[second_screen, second_scene],
	)
	assert_signal_emitted_with_parameters(
		_manager,
		"screen_covered",
		[first_screen, first_scene],
	)


func test_push_emits_screen_level_signals():
	# Given: A base screen and a tracked screen.
	await _do_push()
	var screen := _create_screen()
	watch_signals(screen)

	# When: The screen is pushed.
	await _do_push(screen)

	# Then: Push lifecycle signals were emitted on the screen.
	assert_signal_emitted(screen, "entering")
	assert_signal_emitted(screen, "entered")


func test_push_with_transition_delays_entered():
	# Given: A screen with a push transition.
	var transition := MockTransition.new()
	var screen := _create_screen(transition)
	watch_signals(_manager)

	# When: A screen with transition is pushed.
	await _do_push(screen)

	# Then: The transition has started but entered not yet emitted.
	var active := _get_active_transition()
	assert_true(active.push_started)
	assert_signal_not_emitted(_manager, "screen_entered")

	# When: The transition performs swap and completes.
	active.do_swap()
	active.complete()
	await wait_idle_frames(1)

	# Then: The entered signal is emitted.
	assert_signal_emitted(_manager, "screen_entered")


func test_push_without_transition_emits_entered_immediately():
	# Given: A screen without a transition.
	var screen := _create_screen()
	watch_signals(_manager)

	# When: A screen without transition is pushed.
	await _do_push(screen)

	# Then: The entered signal is emitted immediately.
	assert_signal_emitted(_manager, "screen_entered")


func test_push_with_transition_blocks_input():
	# Given: A screen with a blocking transition.
	var transition := MockTransition.new()
	transition.block_input = true
	var screen := _create_screen(transition)

	# When: The screen is pushed and the transition starts.
	await _do_push(screen)
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
