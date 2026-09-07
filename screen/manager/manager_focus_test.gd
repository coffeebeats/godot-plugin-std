##
## screen/manager/manager_focus_test.gd
##
## Tests pertaining to how `StdScreenManager` saves and restores focus and hover across
## stack operations.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Screen := preload("../screen.gd")
const Manager := preload("manager.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: Manager = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_focus_saved_and_restored_on_pop():
	# Given: A first screen with a focusable button.
	var first := _create_screen()
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(first, first_scene)
	button.grab_focus()
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button,
	)

	# When: A second screen is pushed, then popped.
	await _do_push()
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is restored to the button.
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button,
	)


func test_focus_restored_on_pop_even_when_focus_mode_cleared_synchronously():
	# Given: Focus mode (cursor hidden).
	var cursor := _get_cursor()
	cursor.hide_cursor()

	# Given: A first screen with a focused button.
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(null, first_scene)
	button.grab_focus()
	cursor.focus_root_changed.connect(
		func(root: Control) -> void:
			if root and not root.is_ancestor_of(button):
				button.focus_mode = Control.FOCUS_NONE
			else:
				button.focus_mode = Control.FOCUS_ALL,
	)

	# When: A second screen is pushed then popped.
	await _do_push()
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is restored to the button.
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button,
	)


func test_focus_restoration_respects_consumer_override_after_pop():
	# Given: Focus mode (cursor hidden).
	var cursor := _get_cursor()
	cursor.hide_cursor()

	# Given: A first screen with focusable buttons A and B, focus on A.
	var first := _create_screen()
	var first_scene := Control.new()
	var button_a := Button.new()
	button_a.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button_a)
	var button_b := Button.new()
	button_b.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button_b)
	await _do_push(first, first_scene)
	button_a.grab_focus()
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button_a,
	)

	# Given: A second screen pushed on top.
	var second := _create_screen()
	await _do_push(second)

	# Given: A handler that overrides focus to B when popped.
	second.popped.connect(
		func(_result) -> void: cursor.set_pending_focus(button_b),
	)

	# When: The second screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is on B (consumer override), not A (saved focus).
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button_b,
	)


func test_focus_restoration_skips_disabled_button_after_pop():
	# Given: Focus mode (cursor hidden) — this is where the bug manifests.
	_get_cursor().hide_cursor()

	# Given: A first screen with a focusable button.
	var first := _create_screen()
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(first, first_scene)
	button.grab_focus()
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button,
	)

	# Given: A second screen pushed on top.
	var second := _create_screen()
	await _do_push(second)

	# Given: A handler that disables the button when the screen is popped.
	second.popped.connect(
		func(_result) -> void: button.disabled = true,
	)

	# When: The second screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus does NOT land on the disabled button.
	assert_ne(
		_manager.get_viewport().gui_get_focus_owner(),
		button,
	)


func test_focus_saved_from_hovered_when_cursor_visible():
	# Given: Cursor visible (mouse mode).
	_get_cursor().show_cursor()

	# Given: A first screen with a hoverable button (no focus).
	var first := _create_screen()
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(first, first_scene)

	# Given: The button is hovered (simulated via cursor).
	_get_cursor().set_hovered(button)

	# When: A second screen is pushed (saves hovered as focus).
	await _do_push()

	# When: The cursor is hidden before popping (enter focus mode).
	_get_cursor().hide_cursor()

	# When: The second screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is restored to the button (saved from hovered).
	assert_eq(
		_manager.get_viewport().gui_get_focus_owner(),
		button,
	)


func test_pop_recalculates_hover_when_cursor_visible():
	# NOTE: SubViewport required; root viewport doesn't dispatch GUI input in headless
	# mode.
	var sv := SubViewport.new()
	sv.size = Vector2i(400, 300)
	add_child_autofree(sv)
	sv.notification(Viewport.NOTIFICATION_VP_MOUSE_ENTER)

	# Given: A manager inside the SubViewport.
	var sv_manager := Manager.new()
	sv.add_child(sv_manager)
	await wait_idle_frames(1)
	_get_cursor().show_cursor()

	# Given: A base screen with a hoverable button.
	var base := Control.new()
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size = Vector2(100, 40)
	base.add_child(button)
	sv_manager.push(_create_screen(), base)
	await wait_idle_frames(1)

	# Given: The button is hovered.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(50, 20)
	motion.relative = Vector2(50, 20)
	sv.push_input(motion)
	await get_tree().process_frame
	assert_true(
		button.is_hovered(),
		"precondition: button hovered",
	)

	# When: A second screen is pushed and mouse motion sent.
	sv_manager.push(_create_screen(), Control.new())
	await wait_idle_frames(1)
	var covered := InputEventMouseMotion.new()
	covered.position = Vector2(50, 20)
	covered.relative = Vector2.ZERO
	sv.push_input(covered)
	await get_tree().process_frame
	assert_false(
		button.is_hovered(),
		"precondition: button not hovered",
	)

	# When: The second screen is popped.
	sv_manager.pop()
	await wait_idle_frames(1)

	# Then: The button regains hover after recalculation.
	assert_true(
		button.is_hovered(),
		"button should be hovered after pop",
	)


func test_push_recalculates_hover_when_cursor_visible():
	# NOTE: SubViewport required; root viewport doesn't
	# dispatch GUI input in headless mode.
	var sv := SubViewport.new()
	sv.size = Vector2i(400, 300)
	add_child_autofree(sv)
	(
		sv
		. notification(
			Viewport.NOTIFICATION_VP_MOUSE_ENTER,
		)
	)

	# Given: A manager inside the SubViewport.
	var sv_manager := Manager.new()
	sv.add_child(sv_manager)
	await wait_idle_frames(1)
	_get_cursor().show_cursor()

	# Given: A base screen and the mouse at a known position.
	sv_manager.push(_create_screen(), Control.new())
	await wait_idle_frames(1)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(50, 20)
	motion.relative = Vector2(50, 20)
	sv.push_input(motion)
	await get_tree().process_frame

	# When: A screen with a hoverable button at the cursor position is pushed.
	var scene := Control.new()
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size = Vector2(100, 40)
	scene.add_child(button)
	sv_manager.push(_create_screen(), scene)
	await wait_idle_frames(1)

	# Then: The button is hovered after deferred recalculation.
	assert_true(
		button.is_hovered(),
		"button should be hovered after push",
	)


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


func _get_cursor() -> StdInputCursor:
	return StdGroup.get_sole_member(StdInputCursor.GROUP_INPUT_CURSOR)
