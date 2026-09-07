##
## screen/manager/manager_input_test.gd
##
## Tests pertaining to how `StdScreenManager` isolates input between overlays.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Overlay := preload("../overlay.gd")
const Screen := preload("../screen.gd")
const Manager := preload("manager.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: Manager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_push_wraps_scene_in_overlay_with_mouse_stop():
	# Given: A screen manager.
	var scene := Control.new()

	# When: A screen is pushed.
	await _do_push(null, scene)

	# Then: The scene's parent is a StdScreenOverlay.
	var overlay := scene.get_parent() as Overlay
	assert_true(overlay is Overlay)
	assert_eq(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_STOP,
	)


func test_push_overlay_sharing_depends_on_block_input():
	# Given: A manager with one screen.
	var first_scene := Control.new()
	await _do_push(null, first_scene)

	# When: A non-blocking screen is pushed.
	var nb := _create_screen(null, false)
	var nb_scene := Control.new()
	await _do_push(nb, nb_scene)

	# Then: Both scenes share the same overlay parent.
	assert_same(first_scene.get_parent(), nb_scene.get_parent())

	# When: A blocking screen is pushed (default).
	var blocking_scene := Control.new()
	await _do_push(null, blocking_scene)

	# Then: The blocking screen has its own overlay.
	assert_ne(first_scene.get_parent(), blocking_scene.get_parent())
	assert_true(blocking_scene.get_parent() is Overlay)


func test_pop_frees_unshared_overlay_preserves_shared():
	# Given: A manager with two blocking screens.
	await _do_push()
	var second_scene := Control.new()
	await _do_push(null, second_scene)
	var unshared := second_scene.get_parent()

	# When: The top screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The unshared overlay is freed.
	assert_freed(unshared, "unshared overlay")

	# Given: A base screen and a non-blocking screen.
	var base_scene := Control.new()
	await _do_push(null, base_scene)
	var nb := _create_screen(null, false)
	await _do_push(nb)
	var shared := base_scene.get_parent()

	# When: The non-blocking screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The shared overlay survives.
	assert_not_freed(shared, "shared overlay")


func test_overlay_config_aggregates_across_screens():
	# Given: A base screen with click_to_close.
	var base := _create_screen()
	base.overlay_click_to_close = 1
	var base_scene := Control.new()
	await _do_push(base, base_scene)

	# When: A non-blocking screen is pushed.
	var second := _create_screen(null, false)
	second.overlay_click_to_close = 2
	await _do_push(second)

	# Then: The overlay mask is the OR of both (3).
	var overlay := base_scene.get_parent() as Overlay
	assert_eq(overlay.click_to_close, 3)


func test_close_requested_propagates_topmost_first():
	# Given: A base and two non-blocking screens.
	var base := _create_screen()
	await _do_push(base)
	var second := _create_screen(null, false)
	await _do_push(second)
	var third := _create_screen(null, false)
	await _do_push(third)

	# Connect close_requested handlers that record order.
	var order: Array[Screen] = []
	base.close_requested.connect(func(_e, _c): order.append(base))
	second.close_requested.connect(func(_e, _c): order.append(second))
	third.close_requested.connect(func(_e, _c): order.append(third))

	# When: A close is requested.
	_manager._request_close_overlay(InputEventKey.new())
	await wait_idle_frames(1)

	# Then: Propagation was topmost-first and screens popped.
	assert_eq(order, [third, second, base])
	assert_eq(_manager.get_depth(), 1)


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
