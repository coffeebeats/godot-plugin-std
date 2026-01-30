##
## Feasibility test for focus handling in headless mode.
##
## This test verifies whether focus operations work correctly when running tests
## in headless mode. If these tests pass, Tier 3 cursor/focus tests are viable.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var _focus_changed_count: int = 0
var _last_focused_control: Control = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_control_can_grab_focus() -> void:
	# Given: A focusable control added to the scene.
	var control := Button.new()
	control.focus_mode = Control.FOCUS_ALL
	add_child_autofree(control)

	# When: The control grabs focus.
	control.grab_focus()

	# Then: The control has focus.
	assert_true(control.has_focus())
	assert_eq(get_viewport().gui_get_focus_owner(), control)


func test_control_can_release_focus() -> void:
	# Given: A focused control.
	var control := Button.new()
	control.focus_mode = Control.FOCUS_ALL
	add_child_autofree(control)
	control.grab_focus()
	assert_true(control.has_focus())

	# When: Focus is released.
	control.release_focus()

	# Then: No control has focus.
	assert_false(control.has_focus())
	assert_null(get_viewport().gui_get_focus_owner())


func test_gui_focus_changed_signal_emits() -> void:
	# Given: We're watching the viewport's focus changed signal.
	_focus_changed_count = 0
	_last_focused_control = null
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)

	# Given: A focusable control.
	var control := Button.new()
	control.focus_mode = Control.FOCUS_ALL
	add_child_autofree(control)

	# When: The control grabs focus.
	control.grab_focus()

	# Then: The signal was emitted with the correct control.
	assert_eq(_focus_changed_count, 1)
	assert_eq(_last_focused_control, control)

	# Cleanup.
	get_viewport().gui_focus_changed.disconnect(_on_gui_focus_changed)


func test_focus_can_transfer_between_controls() -> void:
	# Given: Two focusable controls.
	var control1 := Button.new()
	control1.focus_mode = Control.FOCUS_ALL
	add_child_autofree(control1)

	var control2 := Button.new()
	control2.focus_mode = Control.FOCUS_ALL
	add_child_autofree(control2)

	# Given: The first control has focus.
	control1.grab_focus()
	assert_true(control1.has_focus())
	assert_false(control2.has_focus())

	# When: The second control grabs focus.
	control2.grab_focus()

	# Then: Focus transferred to the second control.
	assert_false(control1.has_focus())
	assert_true(control2.has_focus())
	assert_eq(get_viewport().gui_get_focus_owner(), control2)


func test_focus_entered_and_exited_signals_emit() -> void:
	# Given: Two controls with signal watchers.
	var control1 := Button.new()
	control1.focus_mode = Control.FOCUS_ALL
	add_child_autofree(control1)
	watch_signals(control1)

	var control2 := Button.new()
	control2.focus_mode = Control.FOCUS_ALL
	add_child_autofree(control2)
	watch_signals(control2)

	# When: The first control grabs focus.
	control1.grab_focus()

	# Then: focus_entered was emitted on control1.
	assert_signal_emitted(control1, "focus_entered")
	assert_signal_not_emitted(control1, "focus_exited")

	# When: The second control grabs focus.
	control2.grab_focus()

	# Then: focus_exited was emitted on control1, focus_entered on control2.
	assert_signal_emitted(control1, "focus_exited")
	assert_signal_emitted(control2, "focus_entered")


func test_viewport_gui_release_focus_clears_focus() -> void:
	# Given: A focused control.
	var control := Button.new()
	control.focus_mode = Control.FOCUS_ALL
	add_child_autofree(control)
	control.grab_focus()
	assert_true(control.has_focus())

	# When: The viewport releases all focus.
	get_viewport().gui_release_focus()

	# Then: No control has focus.
	assert_false(control.has_focus())
	assert_null(get_viewport().gui_get_focus_owner())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_gui_focus_changed(control: Control) -> void:
	_focus_changed_count += 1
	_last_focused_control = control