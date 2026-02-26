##
## screen/operation/reset_test.gd
##
## Tests pertaining to the reset screen operation.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Manager := preload("../manager/manager.gd")
const Screen := preload("../screen.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: Manager = null

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
