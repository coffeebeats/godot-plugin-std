# gdlint:ignore=max-public-methods
# gdlint:disable=max-file-lines
##
## Tests pertaining to the `StdInputCursor` class.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

## _TEST_HIDE_ACTION is an action registered in the `InputMap` for hiding the cursor.
const _TEST_HIDE_ACTION := &"test_hide"

## _TEST_HIDE_ACTION_OTHER is a second action registered in the `InputMap` for hiding
## the cursor.
const _TEST_HIDE_ACTION_OTHER := &"test_hide_other"

# -- INITIALIZATION ------------------------------------------------------------------ #

var cursor: StdInputCursor = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_get_hovered_returns_hovered_control() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Then: No control is hovered initially.
	assert_null(cursor.get_hovered())

	# Given: A control set as hovered.
	var control := Button.new()
	add_child_autofree(control)
	cursor.set_hovered(control)

	# Then: The hovered control is returned.
	assert_eq(cursor.get_hovered(), control)

	# When: The control is unset.
	cursor.unset_hovered(control)

	# Then: No control is hovered.
	assert_null(cursor.get_hovered())


func test_get_is_confined_follows_action_sets_without_confined_property() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)
	assert_false(cursor.get_is_confined(), "precondition: not confined")

	# When: An action set which confines the cursor is applied.
	var action_set := StdInputActionSet.new()
	action_set.cursor_confined = true
	cursor.update_configuration([action_set])

	# Then: The cursor is confined.
	assert_true(cursor.get_is_confined())


func test_get_is_confined_follows_confined_property_over_action_sets() -> void:
	# Given: A cursor added to the scene whose confinement property is off.
	var property := _make_confined_property(false)
	cursor.confined_property = property
	add_child_autofree(cursor)

	# When: An action set which confines the cursor is applied.
	var action_set := StdInputActionSet.new()
	action_set.cursor_confined = true
	cursor.update_configuration([action_set])

	# Then: The cursor isn't confined.
	assert_false(cursor.get_is_confined())

	# When: The property is turned on.
	property.set_value(true)

	# Then: The cursor is confined.
	assert_true(cursor.get_is_confined())


func test_get_is_confined_true_when_property_on_over_unconfined_set() -> void:
	# Given: A cursor added to the scene whose confinement property is on.
	cursor.confined_property = _make_confined_property(true)
	add_child_autofree(cursor)

	# When: An action set which doesn't confine the cursor is applied.
	cursor.update_configuration([StdInputActionSet.new()])

	# Then: The cursor is confined.
	assert_true(cursor.get_is_confined())


func test_get_is_confined_follows_confined_property_once_its_scope_loads() -> void:
	# Given: A cursor added to the scene whose confinement property defaults to off
	# under a scope not yet loaded.
	var property := _make_confined_property(false)
	cursor.confined_property = property
	add_child_autofree(cursor)
	assert_false(cursor.get_is_confined(), "precondition: not confined")

	# When: The scope loads a saved value turning the property on.
	property.scope.config.set_bool(property.category, property.name, true)
	property.scope.is_loaded = true
	property.scope.loaded.emit()

	# Then: The cursor is confined.
	assert_true(cursor.get_is_confined())


func test_get_is_visible_returns_true_by_default() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Then: The cursor is visible by default (MOUSE_MODE_VISIBLE in headless).
	assert_true(cursor.get_is_visible())


func test_set_focus_root_emits_signal_on_change() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)
	watch_signals(cursor)

	# Given: A control to use as focus root.
	var root := Button.new()
	root.focus_mode = Control.FOCUS_ALL
	add_child_autofree(root)

	# When: The focus root is set.
	cursor.set_focus_root(root)

	# Then: The focus_root_changed signal was emitted.
	assert_signal_emitted(cursor, "focus_root_changed")
	assert_signal_emitted_with_parameters(cursor, "focus_root_changed", [root])


func test_set_focus_root_does_not_emit_signal_when_unchanged() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: A control set as focus root.
	var root := Button.new()
	root.focus_mode = Control.FOCUS_ALL
	add_child_autofree(root)
	cursor.set_focus_root(root)

	# Given: Signals are watched after the first set.
	watch_signals(cursor)

	# When: The same focus root is set again.
	cursor.set_focus_root(root)

	# Then: The signal was not emitted.
	assert_signal_not_emitted(cursor, "focus_root_changed")


func test_set_focus_root_to_null_emits_signal() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: A control set as focus root.
	var root := Button.new()
	root.focus_mode = Control.FOCUS_ALL
	add_child_autofree(root)
	cursor.set_focus_root(root)

	# Given: Signals are watched after the first set.
	watch_signals(cursor)

	# When: The focus root is cleared.
	cursor.set_focus_root(null)

	# Then: The signal was emitted with null.
	assert_signal_emitted(cursor, "focus_root_changed")
	assert_signal_emitted_with_parameters(cursor, "focus_root_changed", [null])


func test_set_hovered_registers_control() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: A control to hover.
	var control := Button.new()
	add_child_autofree(control)

	# When: The control is set as hovered.
	var got := cursor.set_hovered(control)

	# Then: The operation succeeds.
	assert_true(got)


func test_set_hovered_rejects_same_control() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: A control already set as hovered.
	var control := Button.new()
	add_child_autofree(control)
	cursor.set_hovered(control)

	# When: The same control is set as hovered again.
	var got := cursor.set_hovered(control)

	# Then: The operation returns false (no change).
	assert_false(got)


func test_set_pending_focus_skipped_when_cursor_visible() -> void:
	# Given: A cursor added to the scene (visible by default in headless).
	add_child_autofree(cursor)
	assert_true(cursor.get_is_visible())

	# Given: A focusable button in the scene.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)

	# When: A focus target is queued and focus root is triggered.
	cursor.set_pending_focus(button)
	cursor.set_focus_root(null)

	# Then: The button does NOT have focus because cursor is visible.
	assert_ne(
		cursor.get_viewport().gui_get_focus_owner(),
		button,
	)


func test_set_pending_focus_skips_disabled_button() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A disabled button in the scene.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = true
	add_child_autofree(button)

	# When: A disabled button is queued as focus target and focus root is updated.
	cursor.set_pending_focus(button)
	cursor.set_focus_root(null)

	# Then: The disabled button does NOT have focus.
	assert_ne(
		cursor.get_viewport().gui_get_focus_owner(),
		button,
	)


func test_set_pending_focus_used_by_update_focus() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button in the scene.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)

	# When: A focus target is queued and focus root is updated.
	cursor.set_pending_focus(button)
	cursor.set_focus_root(null)

	# Then: The button has focus.
	assert_eq(
		cursor.get_viewport().gui_get_focus_owner(),
		button,
	)


func test_unset_hovered_clears_hovered_control() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: A control set as hovered.
	var control := Button.new()
	add_child_autofree(control)
	cursor.set_hovered(control)

	# When: The control is unset as hovered.
	var got := cursor.unset_hovered(control)

	# Then: The operation succeeds.
	assert_true(got)

	# Then: A new control can now be set as hovered.
	var other := Button.new()
	add_child_autofree(other)
	assert_true(cursor.set_hovered(other))


func test_show_cursor_makes_cursor_visible() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The cursor is hidden.
	cursor.hide_cursor()
	assert_false(cursor.get_is_visible())

	# When: show_cursor is called.
	cursor.show_cursor()

	# Then: The cursor is visible.
	assert_true(cursor.get_is_visible())


func test_show_cursor_noop_when_already_visible() -> void:
	# Given: A cursor added to the scene (starts visible).
	add_child_autofree(cursor)
	assert_true(cursor.get_is_visible())
	watch_signals(cursor)

	# When: show_cursor is called while already visible.
	cursor.show_cursor()

	# Then: The cursor is still visible and no signal was emitted.
	assert_true(cursor.get_is_visible())
	assert_signal_not_emitted(cursor, "cursor_visibility_changed")


func test_show_cursor_releases_stale_focus() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)
	button.grab_focus()
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), button)

	# When: The cursor becomes visible (mouse mode).
	cursor.show_cursor()

	# Then: The stale focus is released.
	assert_null(cursor.get_viewport().gui_get_focus_owner())


func test_hide_cursor_makes_cursor_hidden() -> void:
	# Given: A cursor added to the scene (starts visible).
	add_child_autofree(cursor)
	assert_true(cursor.get_is_visible())

	# When: hide_cursor is called.
	cursor.hide_cursor()

	# Then: The cursor is hidden.
	assert_false(cursor.get_is_visible())


func test_input_motion_past_reveal_minimum_on_either_axis_reveals_cursor(
	relative = use_parameters(
		[Vector2(5, 0), Vector2(0, 5), Vector2(-3, 200), Vector2(200, -3)]
	),
) -> void:
	# Given: A hidden cursor whose action set reveals it on motion past (4, 4).
	_hide_with_reveal_minimum(Vector2(4, 4))

	# When: A mouse motion event moves past the minimum on one axis.
	get_viewport().push_input(_motion(relative))

	# Then: The cursor is visible.
	assert_true(cursor.get_is_visible())


func test_input_motion_within_reveal_minimum_on_both_axes_keeps_cursor_hidden(
	relative = use_parameters(
		[Vector2(4, 4), Vector2(-4, 3), Vector2(3, -4), Vector2(1, 1)]
	),
) -> void:
	# Given: A hidden cursor whose action set reveals it on motion past (4, 4).
	_hide_with_reveal_minimum(Vector2(4, 4))

	# When: A mouse motion event stays within the minimum on both axes.
	get_viewport().push_input(_motion(relative))

	# Then: The cursor is still hidden.
	assert_false(cursor.get_is_visible())


func test_input_motion_within_reveal_minimum_on_screen_keeps_cursor_hidden() -> void:
	# Given: A hidden cursor whose action set reveals it on motion past (4, 4).
	_hide_with_reveal_minimum(Vector2(4, 4))

	# When: A mouse motion event exceeds the minimum in viewport but not screen pixels.
	var event := _motion(Vector2(1, 0))
	event.relative = Vector2(10, 0)
	get_viewport().push_input(event)

	# Then: The cursor is still hidden.
	assert_false(cursor.get_is_visible())


func test_input_motion_within_reveal_window_sums_across_events() -> void:
	# Given: A hidden cursor whose action set sums motion over a second against (4, 4).
	_hide_with_reveal_minimum(Vector2(4, 4), 1.0)

	# When: Two mouse motion events each stay within the minimum.
	get_viewport().push_input(_motion(Vector2(2, 0)))
	get_viewport().push_input(_motion(Vector2(2, 0)))

	# Then: The cursor is still hidden.
	assert_false(cursor.get_is_visible())

	# When: A third event carries the sum past the minimum.
	get_viewport().push_input(_motion(Vector2(2, 0)))

	# Then: The cursor is visible.
	assert_true(cursor.get_is_visible())


func test_input_motion_within_reveal_window_cancels_opposing_motion() -> void:
	# Given: A hidden cursor whose action set sums motion over a second against (4, 4).
	_hide_with_reveal_minimum(Vector2(4, 4), 1.0)

	# When: Mouse motion events jitter back and forth within the window.
	for relative in [Vector2(3, 0), Vector2(-3, 0), Vector2(3, 0)]:
		get_viewport().push_input(_motion(relative))

	# Then: The cursor is still hidden.
	assert_false(cursor.get_is_visible())


func test_input_motion_older_than_reveal_window_is_dropped() -> void:
	# Given: A hidden cursor whose action set sums motion over 50 ms against (4, 4).
	_hide_with_reveal_minimum(Vector2(4, 4), 0.05)

	# Given: A mouse motion event within the minimum, aged past the window.
	get_viewport().push_input(_motion(Vector2(3, 0)))
	var times := cursor._reveal_motion_times
	times[0] -= 100_000
	cursor._reveal_motion_times = times

	# When: Another mouse motion event within the minimum arrives.
	get_viewport().push_input(_motion(Vector2(3, 0)))

	# Then: The cursor is still hidden.
	assert_false(cursor.get_is_visible())


func test_hide_cursor_restores_focus_from_before_reveal() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := _make_focusable_button()
	button.grab_focus()

	# Given: The cursor is revealed, which releases focus.
	cursor.show_cursor()
	assert_null(cursor.get_viewport().gui_get_focus_owner(), "precondition")

	# When: The cursor hides with nothing hovered.
	cursor.hide_cursor()

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The button has focus again.
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), button)


func test_hide_cursor_prefers_hovered_over_focus_from_before_reveal() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := _make_focusable_button()
	button.grab_focus()

	# Given: The cursor is revealed.
	cursor.show_cursor()

	# Given: Another button is hovered.
	var hovered := _make_focusable_button()
	cursor.set_hovered(hovered)

	# When: The cursor hides.
	cursor.hide_cursor()

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The hovered button has focus.
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), hovered)


func test_hide_cursor_skips_focus_from_before_reveal_outside_focus_root() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := _make_focusable_button()
	button.grab_focus()

	# Given: The cursor is revealed.
	cursor.show_cursor()

	# Given: A focus root which doesn't contain the button.
	var root := Control.new()
	add_child_autofree(root)
	cursor.set_focus_root(root)

	# When: The cursor hides.
	cursor.hide_cursor()

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The button doesn't have focus.
	assert_ne(cursor.get_viewport().gui_get_focus_owner(), button)


func test_input_hide_action_which_navigates_moves_focus_from_hovered_control() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on `ui_down`, which also moves focus down.
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions = [&"ui_down"]
	cursor.update_configuration([action_set])

	# Given: The cursor is visible.
	cursor.show_cursor()

	# Given: A hovered button.
	var hovered := _make_focusable_button()
	cursor.set_hovered(hovered)

	# Given: A button below the hovered one in focus order.
	var below := _make_focusable_button()
	hovered.focus_neighbor_bottom = hovered.get_path_to(below)

	# When: The hide action is pressed.
	get_viewport().push_input(_action(&"ui_down"))
	assert_false(cursor.get_is_visible(), "precondition: hidden by the action")

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The button below the hovered one has focus.
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), below)


func test_input_hovered_only_hide_action_which_accepts_presses_hovered_button() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on `ui_accept` while a control is hovered.
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions_if_hovered = [&"ui_accept"]
	cursor.update_configuration([action_set])

	# Given: The cursor is visible.
	cursor.show_cursor()

	# Given: A hovered button.
	var hovered := _make_focusable_button()
	cursor.set_hovered(hovered)
	watch_signals(hovered)

	# When: The hide action is pressed.
	get_viewport().push_input(_action(&"ui_accept"))
	assert_false(cursor.get_is_visible(), "precondition: hidden by the action")

	# When: The hide action is released in a later frame.
	await wait_process_frames(1)
	var release := _action(&"ui_accept")
	release.pressed = false
	get_viewport().push_input(release)

	# Then: The hovered button emits `pressed`.
	assert_signal_emitted(hovered, "pressed")


func test_input_hide_action_which_navigates_restores_focus_from_before_reveal() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on `ui_down`, which also moves focus down.
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions = [&"ui_down"]
	cursor.update_configuration([action_set])

	# Given: The cursor is hidden.
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := _make_focusable_button()
	button.grab_focus()

	# Given: A button below the focused one in focus order.
	var below := _make_focusable_button()
	button.focus_neighbor_bottom = button.get_path_to(below)

	# Given: The cursor is revealed.
	cursor.show_cursor()

	# When: The hide action is pressed with nothing hovered.
	get_viewport().push_input(_action(&"ui_down"))
	assert_false(cursor.get_is_visible(), "precondition: hidden by the action")

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The button from before the reveal has focus.
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), button)


func test_hide_cursor_consumes_focus_from_before_reveal_once() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := _make_focusable_button()
	button.grab_focus()

	# Given: The cursor is revealed.
	cursor.show_cursor()

	# Given: A pending focus target.
	var target := _make_focusable_button()
	cursor.set_pending_focus(target)

	# Given: The cursor hides, which focuses the pending target.
	cursor.hide_cursor()
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), target, "precondition")

	# When: The pending target loses focus.
	target.release_focus()

	# When: Focus is resolved again.
	cursor._update_focus()

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The button from before the reveal doesn't regain focus.
	assert_ne(cursor.get_viewport().gui_get_focus_owner(), button)


func test_hide_cursor_keeping_focus_consumes_focus_from_before_reveal() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := _make_focusable_button()
	button.grab_focus()

	# Given: The cursor is revealed.
	cursor.show_cursor()

	# Given: Another button takes focus, as a click would without a focus handler.
	var other := _make_focusable_button()
	other.grab_focus()

	# Given: The cursor hides, which keeps the other button's focus.
	cursor.hide_cursor()
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), other, "precondition")

	# When: The other button loses focus.
	other.release_focus()

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The button from before the reveal doesn't regain focus.
	assert_ne(cursor.get_viewport().gui_get_focus_owner(), button)


func test_hide_cursor_restores_focus_from_before_reveal_to_handled_control() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button managed by a focus handler.
	var button := _make_focusable_button()
	button.add_child(StdInputCursorFocusHandler.new())

	# Given: The button has focus.
	button.grab_focus()

	# Given: The cursor is revealed, which makes the button unfocusable.
	cursor.show_cursor()
	assert_eq(button.focus_mode, Control.FOCUS_NONE, "precondition: unfocusable")

	# When: The cursor hides.
	cursor.hide_cursor()

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The button has focus again.
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), button)


func test_input_reveal_in_the_hiding_frame_keeps_focus_released() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on the test action.
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions = [_TEST_HIDE_ACTION]
	cursor.update_configuration([action_set])

	# Given: The cursor is hidden.
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := _make_focusable_button()
	button.grab_focus()

	# Given: The cursor is revealed.
	cursor.show_cursor()

	# Given: The hide action is pressed, hiding the cursor.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))
	assert_false(cursor.get_is_visible(), "precondition: hidden by the action")

	# When: The mouse moves within the same frame.
	get_viewport().push_input(_motion(Vector2(3, 0)))

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The cursor is visible.
	assert_true(cursor.get_is_visible())

	# Then: Nothing has focus.
	assert_null(cursor.get_viewport().gui_get_focus_owner())


func test_set_focus_root_in_the_hiding_frame_focuses_pending_target() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := _make_focusable_button()
	button.grab_focus()

	# Given: The cursor is revealed.
	cursor.show_cursor()

	# Given: A focus root which doesn't contain the button.
	var root := Control.new()
	add_child_autofree(root)

	# Given: A focusable button under the focus root.
	var target := Button.new()
	target.focus_mode = Control.FOCUS_ALL
	root.add_child(target)

	# Given: The cursor hides.
	cursor.hide_cursor()

	# When: The button under the root is set as the pending focus target.
	cursor.set_pending_focus(target)

	# When: The focus root is set within the same frame.
	cursor.set_focus_root(root)

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The pending target has focus.
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), target)


func test_report_focus_handler_visible_in_the_hiding_frame_skips_anchor() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := _make_focusable_button()
	button.grab_focus()

	# Given: The cursor is revealed.
	cursor.show_cursor()

	# Given: An anchor focus handler on another button.
	var anchor := _make_anchor_handler()

	# Given: The cursor hides.
	cursor.hide_cursor()

	# When: The anchor's focus handler reports itself visible within the same frame.
	cursor.report_focus_handler_visible(anchor)

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The button from before the reveal has focus.
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), button)


func test_hide_cursor_yields_to_focus_grabbed_in_the_same_frame() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := _make_focusable_button()
	button.grab_focus()

	# Given: The cursor is revealed.
	cursor.show_cursor()

	# Given: Another focusable button.
	var other := _make_focusable_button()

	# Given: The cursor hides.
	cursor.hide_cursor()

	# When: The other button grabs focus within the same frame.
	other.grab_focus()

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: The other button has focus.
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), other)


func test_hide_cursor_freeing_prior_focus_in_the_same_frame_focuses_nothing() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button that has focus.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child(button)
	button.grab_focus()

	# Given: The cursor is revealed.
	cursor.show_cursor()

	# Given: The cursor hides.
	cursor.hide_cursor()

	# When: The button is freed within the same frame.
	button.free()

	# When: The frame ends.
	await wait_process_frames(1)

	# Then: Nothing has focus.
	#
	# NOTE: GUT also fails the test on any engine error the freed button causes.
	assert_null(cursor.get_viewport().gui_get_focus_owner())


func test_hide_cursor_clears_summed_motion() -> void:
	# Given: A hidden cursor whose action set sums motion over a second against (4, 4).
	_hide_with_reveal_minimum(Vector2(4, 4), 1.0)

	# Given: The cursor is shown, then the mouse moves within the minimum.
	cursor.show_cursor()
	get_viewport().push_input(_motion(Vector2(3, 0)))

	# When: The cursor is hidden.
	cursor.hide_cursor()

	# When: Another mouse motion event within the minimum arrives.
	get_viewport().push_input(_motion(Vector2(3, 0)))

	# Then: The cursor is still hidden.
	assert_false(cursor.get_is_visible())


func test_input_hide_action_clears_summed_motion() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on the test action and sums motion against (4, 4).
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions = [_TEST_HIDE_ACTION]
	action_set.cursor_reveal_distance_minimum = Vector2(4, 4)
	action_set.cursor_reveal_window = 1.0
	cursor.update_configuration([action_set])

	# Given: The cursor is visible.
	cursor.show_cursor()
	assert_true(cursor.get_is_visible(), "precondition: cursor visible")

	# Given: The mouse moves within the minimum.
	get_viewport().push_input(_motion(Vector2(3, 0)))

	# When: The hide action is pressed.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))
	assert_false(cursor.get_is_visible(), "precondition: hidden by the action")

	# When: Another mouse motion event within the minimum arrives.
	get_viewport().push_input(_motion(Vector2(3, 0)))

	# Then: The cursor is still hidden.
	assert_false(cursor.get_is_visible())


func test_update_configuration_uses_largest_reveal_window() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: Two action sets with different reveal windows.
	var shorter := StdInputActionSet.new()
	shorter.cursor_reveal_window = 0.2
	var longer := StdInputActionSet.new()
	longer.cursor_reveal_window = 0.5

	# When: The configuration is updated with both.
	cursor.update_configuration([shorter, longer])

	# Then: The longer window is used.
	assert_eq(cursor._reveal_window, 0.5)


func test_input_ignored_while_cursor_captured() -> void:
	# Given: A cursor added to the scene under an action set which captures it.
	add_child_autofree(cursor)
	var action_set := StdInputActionSet.new()
	action_set.cursor_captured = true
	cursor.update_configuration([action_set])
	assert_false(cursor.get_is_visible(), "precondition: cursor hidden")
	watch_signals(cursor)

	# When: The mouse moves.
	get_viewport().push_input(_motion(Vector2(10, 10)))

	# When: A reveal button is pressed.
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	get_viewport().push_input(button)

	# Then: The cursor stays hidden.
	assert_false(cursor.get_is_visible())

	# Then: No visibility change is reported.
	assert_signal_not_emitted(cursor, "cursor_visibility_changed")


func test_input_held_hide_action_does_not_rehide_after_unrelated_press() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on the test action.
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions = [_TEST_HIDE_ACTION]
	cursor.update_configuration([action_set])

	# Given: The cursor is visible.
	cursor.show_cursor()
	assert_true(cursor.get_is_visible(), "precondition: cursor visible")

	# Given: The hide action is pressed and held, hiding the cursor.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))
	assert_false(cursor.get_is_visible(), "precondition: hidden by the action")

	# Given: The cursor is shown again.
	cursor.show_cursor()

	# Given: A key bound to no action is pressed.
	get_viewport().push_input(_key_press())

	# When: The held hide action reports pressed again.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))

	# Then: The cursor is still visible.
	assert_true(cursor.get_is_visible())


func test_input_hide_action_held_before_reveal_does_not_rehide() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on the test action.
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions = [_TEST_HIDE_ACTION]
	cursor.update_configuration([action_set])

	# Given: The cursor is hidden.
	cursor.hide_cursor()
	assert_false(cursor.get_is_visible(), "precondition: cursor hidden")

	# Given: The hide action is pressed and held.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))

	# Given: The cursor is shown.
	cursor.show_cursor()
	assert_true(cursor.get_is_visible(), "precondition: cursor visible")

	# When: The still-held hide action reports pressed again.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))

	# Then: The cursor is still visible.
	assert_true(cursor.get_is_visible())


func test_input_hide_action_held_within_hide_delay_does_not_hide_after_it() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on the test action after a one-second delay.
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions = [_TEST_HIDE_ACTION]
	action_set.cursor_hide_delay = 1.0
	cursor.update_configuration([action_set])

	# Given: The cursor was just shown.
	cursor.show_cursor()
	cursor._time_since_mouse_motion = 0.0

	# Given: The hide action is pressed and held within the delay.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))
	assert_true(cursor.get_is_visible(), "precondition: cursor visible")

	# Given: The delay elapses.
	cursor._time_since_mouse_motion = 5.0

	# When: The still-held hide action reports pressed again.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))

	# Then: The cursor is still visible.
	assert_true(cursor.get_is_visible())


func test_input_hide_action_pressed_after_hide_delay_hides() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on the test action after a one-second delay.
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions = [_TEST_HIDE_ACTION]
	action_set.cursor_hide_delay = 1.0
	cursor.update_configuration([action_set])

	# Given: The cursor is visible.
	cursor.show_cursor()

	# Given: The delay has elapsed.
	cursor._time_since_mouse_motion = 5.0

	# When: The hide action is pressed.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))

	# Then: The cursor is hidden.
	assert_false(cursor.get_is_visible())


func test_input_hovered_only_hide_action_hides_while_hovered() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on the test action only while a control is hovered.
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions_if_hovered = [_TEST_HIDE_ACTION]
	cursor.update_configuration([action_set])

	# Given: The cursor is visible.
	cursor.show_cursor()
	assert_true(cursor.get_is_visible(), "precondition: cursor visible")

	# Given: A control is hovered.
	var control := Button.new()
	add_child_autofree(control)
	cursor.set_hovered(control)

	# When: The hide action is pressed.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))

	# Then: The cursor is hidden.
	assert_false(cursor.get_is_visible())


func test_input_hovered_only_hide_action_keeps_cursor_without_hover() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on the test action only while a control is hovered.
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions_if_hovered = [_TEST_HIDE_ACTION]
	cursor.update_configuration([action_set])

	# Given: The cursor is visible with no control hovered.
	cursor.show_cursor()
	assert_true(cursor.get_is_visible(), "precondition: cursor visible")
	assert_null(cursor.get_hovered(), "precondition: nothing hovered")

	# When: The hide action is pressed.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))

	# Then: The cursor is still visible.
	assert_true(cursor.get_is_visible())


func test_input_hide_action_also_hovered_only_hides_without_hover() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set hides on the test action.
	var action_set := StdInputActionSet.new()
	action_set.cursor_hide_actions = [_TEST_HIDE_ACTION]

	# Given: A layer also hides on the test action while a control is hovered.
	var layer := StdInputActionSet.new()
	layer.cursor_hide_actions_if_hovered = [_TEST_HIDE_ACTION]
	cursor.update_configuration([action_set, layer])

	# Given: The cursor is visible with no control hovered.
	cursor.show_cursor()
	assert_true(cursor.get_is_visible(), "precondition: cursor visible")
	assert_null(cursor.get_hovered(), "precondition: nothing hovered")

	# When: The hide action is pressed.
	get_viewport().push_input(_action(_TEST_HIDE_ACTION))

	# Then: The cursor is hidden.
	assert_false(cursor.get_is_visible())


func test_input_reveal_button_release_keeps_cursor_hidden() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: The action set reveals on the left mouse button.
	var action_set := StdInputActionSet.new()
	action_set.cursor_reveal_mouse_buttons = [MOUSE_BUTTON_LEFT]
	cursor.update_configuration([action_set])

	# Given: The cursor is hidden.
	cursor.hide_cursor()
	assert_false(cursor.get_is_visible(), "precondition: cursor hidden")

	# When: The button's release arrives.
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = false
	get_viewport().push_input(button)

	# Then: The cursor stays hidden.
	assert_false(cursor.get_is_visible())

	# When: The button is pressed.
	button.pressed = true
	get_viewport().push_input(button)

	# Then: The cursor is revealed.
	assert_true(cursor.get_is_visible())


func test_process_releases_every_hide_action_no_longer_pressed() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: Two tracked hide actions which are no longer pressed.
	cursor._pressed = [_TEST_HIDE_ACTION, _TEST_HIDE_ACTION_OTHER] as Array[String]

	# When: A frame is processed.
	cursor._process(0.1)

	# Then: Neither action is tracked.
	assert_true(cursor._pressed.is_empty())


func test_input_motion_within_reveal_minimum_keeps_hide_delay_running() -> void:
	# Given: A visible cursor whose action set reveals it on motion past (4, 4).
	add_child_autofree(cursor)
	var action_set := StdInputActionSet.new()
	action_set.cursor_reveal_distance_minimum = Vector2(4, 4)
	cursor.update_configuration([action_set])
	assert_true(cursor.get_is_visible(), "precondition: cursor visible")

	# Given: Five seconds have passed since the last mouse motion.
	cursor._time_since_mouse_motion = 5.0

	# When: A mouse motion event stays within the minimum.
	get_viewport().push_input(_motion(Vector2(1, 0)))

	# Then: The time since motion is untouched.
	assert_eq(cursor._time_since_mouse_motion, 5.0)

	# When: A mouse motion event moves past the minimum.
	get_viewport().push_input(_motion(Vector2(10, 0)))

	# Then: The time since motion is reset.
	assert_eq(cursor._time_since_mouse_motion, 0.0)


func test_set_focus_root_preserves_focus_when_cursor_hidden() -> void:
	# Given: A cursor added to the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focusable button under a root that has focus.
	var root := Control.new()
	add_child_autofree(root)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	root.add_child(button)
	button.grab_focus()
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), button)

	# When: The focus root is set to the button's ancestor.
	cursor.set_focus_root(root)

	# Then: The button retains focus.
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), button)


func test_unset_hovered_rejects_wrong_control() -> void:
	# Given: A cursor added to the scene.
	add_child_autofree(cursor)

	# Given: A control set as hovered.
	var control := Button.new()
	add_child_autofree(control)
	cursor.set_hovered(control)

	# Given: A different control.
	var other := Button.new()
	add_child_autofree(other)

	# When: The wrong control is unset.
	var got := cursor.unset_hovered(other)

	# Then: The operation returns false (not the hovered control).
	assert_false(got)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	InputMap.erase_action(_TEST_HIDE_ACTION)
	InputMap.erase_action(_TEST_HIDE_ACTION_OTHER)


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)

	InputMap.add_action(_TEST_HIDE_ACTION)
	InputMap.add_action(_TEST_HIDE_ACTION_OTHER)


func before_each() -> void:
	# Clear the global cursor group before each test.
	StdGroup.with_id(StdInputCursor.GROUP_INPUT_CURSOR).clear_members()

	cursor = StdInputCursor.new()


func after_each() -> void:
	cursor = null


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _action returns a press of `action`, as the Steam actions component publishes one.
func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


## _hide_with_reveal_minimum adds the cursor to the scene, configures it with an action
## set whose reveal distance minimum is `minimum` and reveal window is `window`, and
## hides it.
func _hide_with_reveal_minimum(minimum: Vector2, window: float = 0.0) -> void:
	add_child_autofree(cursor)
	var action_set := StdInputActionSet.new()
	action_set.cursor_reveal_distance_minimum = minimum
	action_set.cursor_reveal_window = window
	cursor.update_configuration([action_set])
	cursor.hide_cursor()
	assert_false(cursor.get_is_visible(), "precondition: cursor hidden")


## _key_press returns a press of a key bound to no action.
func _key_press() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_A
	event.pressed = true
	return event


## _make_anchor_handler adds a focusable button to the scene, managed by an anchor focus
## handler, and returns the handler.
func _make_anchor_handler() -> StdInputCursorFocusHandler:
	var handler := StdInputCursorFocusHandler.new()
	handler.use_as_anchor = true
	_make_focusable_button().add_child(handler)
	return handler


## _make_confined_property returns a cursor confinement property whose value defaults
## to `value`.
func _make_confined_property(value: bool) -> StdSettingsPropertyBool:
	var property := StdSettingsPropertyBool.new()
	property.scope = StdSettingsScope.new()
	property.category = &"test"
	property.name = &"confined"
	property.default = value
	return property


## _make_focusable_button adds a focusable button to the scene and returns it.
func _make_focusable_button() -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)
	return button


## _motion returns a mouse motion event which moves by `relative` in screen pixels.
func _motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.screen_relative = relative
	return event
