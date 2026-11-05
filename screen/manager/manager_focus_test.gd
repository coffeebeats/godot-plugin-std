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


func test_focus_root_follows_the_overlay_through_push_pop_replace_and_reset() -> void:
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
	var first_root := cursor.get_focus_root()
	assert_true(first_root.is_ancestor_of(button), "precondition: root over the scene")

	# When: A second screen is pushed.
	var second_scene := Control.new()
	await _do_push(null, second_scene)

	# Then: The root is the second screen's overlay.
	assert_true(cursor.get_focus_root().is_ancestor_of(second_scene))
	assert_ne(cursor.get_focus_root(), first_root)

	# When: The second screen is replaced.
	var third_scene := Control.new()
	_manager.replace(_create_screen(), third_scene)
	await wait_idle_frames(1)

	# Then: The root is over the replacing screen.
	assert_true(cursor.get_focus_root().is_ancestor_of(third_scene))

	# When: The replacing screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The root and the focus return to the first screen.
	assert_eq(cursor.get_focus_root(), first_root)
	assert_eq(_manager.get_viewport().gui_get_focus_owner(), button)

	# When: The stack is reset to a new screen.
	var base_scene := Control.new()
	_manager.reset(_create_screen(), base_scene)
	await wait_idle_frames(1)

	# Then: The root is the new base's overlay, the only claim left.
	assert_true(cursor.get_focus_root().is_ancestor_of(base_scene))
	assert_eq(cursor._claims.size(), 1)


func test_manager_leaving_the_tree_releases_every_claim() -> void:
	# Given: Focus mode (cursor hidden).
	var cursor := _get_cursor()
	cursor.hide_cursor()

	# Given: Two screens, the first with a focused button.
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(null, first_scene)
	button.grab_focus()
	await _do_push()
	assert_eq(cursor._claims.size(), 2, "precondition: one claim per screen")

	# Given: A count of the button's focus grabs, which outlives the button.
	var grabs := [0]
	button.focus_entered.connect(func() -> void: grabs[0] += 1)

	# When: The manager leaves the tree.
	remove_child(_manager)
	await wait_idle_frames(1)

	# Then: No claim and no root remain.
	assert_null(cursor.get_focus_root())
	assert_eq(cursor._claims.size(), 0)

	# Then: The button saved under the first screen wasn't focused on the way out.
	assert_eq(grabs, [0])


func test_pop_to_restores_focus_of_the_target_screen_once() -> void:
	# Given: Focus mode (cursor hidden).
	var cursor := _get_cursor()
	cursor.hide_cursor()

	# Given: A first screen with a focused button.
	var first := _create_screen()
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(first, first_scene)
	button.grab_focus()

	# Given: Two more screens, each with a focused button, pushed over it.
	var focused: Array[Control] = []
	for i in 2:
		var scene := Control.new()
		var other := Button.new()
		other.focus_mode = Control.FOCUS_ALL
		other.focus_entered.connect(func() -> void: focused.append(other))
		scene.add_child(other)
		await _do_push(null, scene)
		other.grab_focus()
	focused.clear()

	# When: The stack is popped back to the first screen.
	_manager.pop_to(first)
	await wait_idle_frames(1)

	# Then: The first screen's button has focus.
	assert_eq(_manager.get_viewport().gui_get_focus_owner(), button)

	# Then: No popped button was focused on the way.
	assert_eq(focused, [])


func test_pop_restores_focus_under_a_shared_overlay() -> void:
	# Given: Focus mode (cursor hidden).
	_get_cursor().hide_cursor()

	# Given: A first screen with a focused button.
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(null, first_scene)
	button.grab_focus()

	# Given: A second screen which shares the first's overlay, with a focused button.
	var second_scene := Control.new()
	var other := Button.new()
	other.focus_mode = Control.FOCUS_ALL
	second_scene.add_child(other)
	await _do_push(_create_screen(null, false), second_scene)
	other.grab_focus()

	# When: The second screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: Focus is restored to the first screen's button.
	assert_eq(_manager.get_viewport().gui_get_focus_owner(), button)


func test_pop_over_a_claim_hidden_by_a_live_scene_restores_the_scene_focus() -> void:
	# Given: Focus mode (cursor hidden).
	var cursor := _get_cursor()
	cursor.hide_cursor()

	# Given: A first screen which keeps running under others, with a focused button.
	var first := _create_screen()
	first.pause_when_covered = false
	var first_scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	first_scene.add_child(button)
	await _do_push(first, first_scene)
	button.grab_focus()

	# Given: A panel in that scene claims focus, and its button takes it.
	var panel := Control.new()
	first_scene.add_child(panel)
	var panel_button := Button.new()
	panel_button.focus_mode = Control.FOCUS_ALL
	panel.add_child(panel_button)
	cursor.claim_focus(panel)
	panel_button.grab_focus()
	assert_eq(cursor.get_focus_root(), panel, "precondition: panel on top")

	# Given: A second screen pushed over the scene.
	await _do_push()

	# Given: The scene hides the panel while covered.
	panel.hide()
	await wait_idle_frames(1)

	# When: The second screen is popped.
	_manager.pop()
	await wait_idle_frames(1)

	# Then: The root is the scene's overlay, and its saved button has focus.
	assert_true(cursor.get_focus_root().is_ancestor_of(first_scene))
	assert_ne(cursor.get_focus_root(), panel)
	assert_eq(_manager.get_viewport().gui_get_focus_owner(), button)


func test_pop_recalculates_hover_at_mouse_away_from_origin() -> void:
	# Given: A manager mounted by the helper.
	var manager := Manager.new()
	var input := await StdTestInput.mount(self, manager)

	# Given: The cursor is visible.
	_get_cursor().show_cursor()

	# Given: A base screen with a button away from the viewport's origin.
	var base := Control.new()
	var button := Button.new()
	button.position = Vector2(400, 300)
	button.size = Vector2(100, 40)
	base.add_child(button)
	manager.push(_create_screen(), base)
	await wait_idle_frames(1)

	# Given: The button was clicked, which leaves it hovered.
	input.click(button)
	assert_true(button.is_hovered(), "precondition: button hovered")

	# Given: A second screen covers it.
	manager.push(_create_screen(), Control.new())
	await wait_idle_frames(1)

	# Given: A motion there clears its hover.
	input.move_mouse(button.get_global_rect().get_center())
	assert_false(button.is_hovered(), "precondition: button not hovered")

	# When: The second screen is popped.
	manager.pop()
	await wait_idle_frames(1)

	# Then: Hover is recalculated at the mouse, over the button.
	assert_true(button.is_hovered())


func test_pop_under_a_content_scale_recalculates_hover_at_the_mouse() -> void:
	# Given: A root drawn at twice its size.
	var root := get_tree().root
	var scale_before := root.content_scale_factor
	root.content_scale_factor = 2.0

	# Given: A manager mounted by the helper.
	var manager := Manager.new()
	var input := await StdTestInput.mount(self, manager)

	# Given: The cursor is visible.
	_get_cursor().show_cursor()

	# Given: A base screen with a button away from the viewport's origin.
	var base := Control.new()
	var button := Button.new()
	button.position = Vector2(200, 100)
	button.size = Vector2(100, 40)
	base.add_child(button)
	manager.push(_create_screen(), base)
	await wait_idle_frames(1)

	# Given: A second screen covers it.
	manager.push(_create_screen(), Control.new())
	await wait_idle_frames(1)

	# Given: The mouse rests over the covered button.
	input.move_mouse(button.get_global_rect().get_center())
	assert_false(button.is_hovered(), "precondition: button not hovered")

	# When: The second screen is popped.
	manager.pop()
	await wait_idle_frames(1)

	# Then: Hover is recalculated at the mouse, over the button.
	assert_true(button.is_hovered())

	root.content_scale_factor = scale_before


func test_push_recalculates_hover_when_cursor_visible():
	# Given: A manager mounted by the helper.
	var manager := Manager.new()
	var input := await StdTestInput.mount(self, manager)

	# Given: The cursor is visible.
	_get_cursor().show_cursor()

	# Given: A base screen and the mouse at a known position.
	manager.push(_create_screen(), Control.new())
	await wait_idle_frames(1)
	input.move_mouse(Vector2(50, 20))

	# When: A screen with a hoverable button at the cursor position is pushed.
	var scene := Control.new()
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size = Vector2(100, 40)
	scene.add_child(button)
	manager.push(_create_screen(), scene)
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
	transition: StdTransition = null,
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
