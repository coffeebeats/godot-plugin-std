##
## Tests pertaining to the `StdInputCursor` class.
##

extends GutTest

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


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	# Clear the global cursor group before each test.
	StdGroup.with_id(StdInputCursor.GROUP_INPUT_CURSOR).clear_members()

	cursor = StdInputCursor.new()


func after_each() -> void:
	cursor = null
