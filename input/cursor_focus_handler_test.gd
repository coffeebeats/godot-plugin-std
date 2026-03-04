# gdlint:disable=max-public-methods

##
## Tests pertaining to the `StdInputCursorFocusHandler` class.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var cursor: StdInputCursor = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_get_focus_target_returns_null_when_no_anchors() -> void:
	# Given: No anchors are registered.
	StdInputCursorFocusHandler._anchors.clear()

	# When: A focus target is requested.
	var got := StdInputCursorFocusHandler.get_focus_target()

	# Then: Null is returned.
	assert_null(got)


func test_get_focus_target_returns_visible_anchor() -> void:
	# Given: A cursor in the scene (required for focus handler).
	add_child_autofree(cursor)

	# Given: A button with a focus handler configured as an anchor.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)

	var handler := StdInputCursorFocusHandler.new()
	handler.use_as_anchor = true
	button.add_child(handler)

	# Then: The button is returned as the focus target.
	assert_eq(StdInputCursorFocusHandler.get_focus_target(), button)


func test_get_focus_target_respects_ancestor_filter() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A container with a button inside.
	var container := Control.new()
	add_child_autofree(container)

	var button_inside := Button.new()
	button_inside.focus_mode = Control.FOCUS_ALL
	container.add_child(button_inside)

	var handler_inside := StdInputCursorFocusHandler.new()
	handler_inside.control = NodePath("..")
	handler_inside.use_as_anchor = true
	button_inside.add_child(handler_inside)

	# Given: A button outside the container.
	var button_outside := Button.new()
	button_outside.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button_outside)

	var handler_outside := StdInputCursorFocusHandler.new()
	handler_outside.control = NodePath("..")
	handler_outside.use_as_anchor = true
	button_outside.add_child(handler_outside)

	# When: Focus target is requested with container as ancestor.
	var got := StdInputCursorFocusHandler.get_focus_target(container)

	# Then: Only the button inside the container is returned.
	assert_eq(got, button_inside)


func test_get_focus_target_returns_last_registered_anchor() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: Two buttons with focus handlers as anchors.
	var button1 := Button.new()
	button1.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button1)

	var handler1 := StdInputCursorFocusHandler.new()
	handler1.control = NodePath("..")
	handler1.use_as_anchor = true
	button1.add_child(handler1)

	var button2 := Button.new()
	button2.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button2)

	var handler2 := StdInputCursorFocusHandler.new()
	handler2.control = NodePath("..")
	handler2.use_as_anchor = true
	button2.add_child(handler2)

	# Then: The last registered (button2) is returned.
	assert_eq(StdInputCursorFocusHandler.get_focus_target(), button2)


func test_get_focus_target_returns_highest_priority_anchor() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: Two buttons with focus handlers as anchors at different priorities.
	var button1 := Button.new()
	button1.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button1)

	var handler1 := StdInputCursorFocusHandler.new()
	handler1.control = NodePath("..")
	handler1.use_as_anchor = true
	handler1.priority = 10
	button1.add_child(handler1)

	var button2 := Button.new()
	button2.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button2)

	var handler2 := StdInputCursorFocusHandler.new()
	handler2.control = NodePath("..")
	handler2.use_as_anchor = true
	handler2.priority = 0
	button2.add_child(handler2)

	# Then: The higher priority anchor is returned despite being registered first.
	assert_eq(StdInputCursorFocusHandler.get_focus_target(), button1)


func test_anchor_is_removed_on_exit_tree() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A button with a focus handler as anchor.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child(button)

	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("..")
	handler.use_as_anchor = true
	button.add_child(handler)

	# Then: The button is the focus target.
	assert_eq(StdInputCursorFocusHandler.get_focus_target(), button)

	# NOTE: Wait for deferred calls from _ready() to complete before freeing.
	await get_tree().process_frame

	# When: The button is removed from the tree.
	button.queue_free()
	await get_tree().process_frame

	# Then: No focus target is available.
	assert_null(StdInputCursorFocusHandler.get_focus_target())


func test_cursor_visibility_change_toggles_focus_mode() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A button with FOCUS_ALL and a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child_autofree(button)

	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("..")
	button.add_child(handler)

	# Given: Cursor visibility is handled correctly.
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)

	# When: Cursor becomes hidden.
	cursor.cursor_visibility_changed.emit(false)

	# Then: focus_mode is restored and mouse_filter is IGNORE.
	assert_eq(button.focus_mode, Control.FOCUS_ALL)
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	# When: Cursor becomes visible again.
	cursor.cursor_visibility_changed.emit(true)

	# Then: focus_mode is NONE and mouse_filter is restored.
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_focus_root_change_disables_controls_outside_root(
	params = use_parameters(
		(
			ParameterFactory
			. named_parameters(
				["cursor_visible", "expected_mouse_filter"],
				[
					[true, Control.MOUSE_FILTER_STOP],
					[false, Control.MOUSE_FILTER_IGNORE],
				]
			)
		)
	)
) -> void:
	# Given: A button with a focus handler outside a modal.
	var parts := _setup_outside_focus_root()
	var button: Button = parts[0]
	var modal: Control = parts[2]

	# Given: Cursor visibility is set.
	if not params.cursor_visible:
		cursor.cursor_visibility_changed.emit(false)

	# When: Focus root is set to the modal.
	cursor.focus_root_changed.emit(modal)

	# Then: Focus disabled; mouse_filter depends on cursor visibility.
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	assert_eq(button.mouse_filter, params.expected_mouse_filter)


func test_focus_root_change_to_null_restores_controls() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: A modal container.
	var modal := Control.new()
	add_child_autofree(modal)

	# Given: A button outside the modal with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child_autofree(button)

	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("..")
	button.add_child(handler)

	# Given: Focus root was set to modal (button outside root).
	cursor.focus_root_changed.emit(modal)
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)

	# When: Focus root is cleared.
	cursor.focus_root_changed.emit(null)

	# Then: Button is restored based on cursor visibility.
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_focus_root_change_keeps_controls_inside_root_enabled() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A modal container with a button inside.
	var modal := Control.new()
	add_child_autofree(modal)

	var button_inside := Button.new()
	button_inside.focus_mode = Control.FOCUS_ALL
	button_inside.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(button_inside)

	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("..")
	button_inside.add_child(handler)

	# When: Focus root is set to the modal.
	cursor.focus_root_changed.emit(modal)

	# Then: The button inside is NOT disabled (respects cursor visibility).
	# NOTE: Cursor is visible, so focus_mode should be NONE but mouse_filter preserved.
	assert_eq(button_inside.focus_mode, Control.FOCUS_NONE)
	assert_eq(button_inside.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_handler_emits_signal_on_control_event(
	params = use_parameters(
		(
			ParameterFactory
			. named_parameters(
				["trigger_signal", "expected_signal"],
				[
					["focus_entered", "focused"],
					["focus_exited", "unfocused"],
					["mouse_entered", "hovered"],
					["mouse_exited", "unhovered"],
				]
			)
		)
	)
) -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)

	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("..")
	button.add_child(handler)

	# Given: The handler signals are being watched.
	watch_signals(handler)

	# When: The control emits the trigger signal.
	button.get(params.trigger_signal).emit()

	# Then: The expected handler signal is emitted.
	assert_signal_emitted(handler, params.expected_signal)


func test_is_focused_returns_correct_state() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)

	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("..")
	button.add_child(handler)

	# Then: Initially not focused.
	assert_false(handler.is_focused())

	# When: The button gains focus.
	button.focus_entered.emit()

	# Then: is_focused returns true.
	assert_true(handler.is_focused())

	# When: The button loses focus.
	button.focus_exited.emit()

	# Then: is_focused returns false.
	assert_false(handler.is_focused())


func test_is_hovered_returns_correct_state() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)

	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("..")
	button.add_child(handler)

	# Then: Initially not hovered.
	assert_false(handler.is_hovered())

	# When: The mouse enters the button.
	button.mouse_entered.emit()

	# Then: is_hovered returns true.
	assert_true(handler.is_hovered())

	# When: The mouse exits the button.
	button.mouse_exited.emit()

	# Then: is_hovered returns false.
	assert_false(handler.is_hovered())


func test_disabled_button_input_state(
	params = use_parameters(
		(
			ParameterFactory
			. named_parameters(
				["block", "expected_mouse_filter"],
				[
					[true, Control.MOUSE_FILTER_IGNORE],
					[false, Control.MOUSE_FILTER_STOP],
				]
			)
		)
	)
) -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: A disabled button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.disabled = true
	add_child_autofree(button)

	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("..")
	handler.block_focus_and_hover_on_disable = params.block
	button.add_child(handler)

	# Then: The button's input state reflects the blocking configuration.
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	assert_eq(button.mouse_filter, params.expected_mouse_filter)


func test_get_focus_target_with_disabled_anchor(
	params = use_parameters(
		(
			ParameterFactory
			. named_parameters(
				["block", "expect_target"],
				[
					[true, false],
					[false, true],
				]
			)
		)
	)
) -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A disabled button with a focus handler as anchor.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = true
	add_child_autofree(button)

	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("..")
	handler.use_as_anchor = true
	handler.block_focus_and_hover_on_disable = params.block
	button.add_child(handler)

	# Then: The focus target reflects the blocking configuration.
	var got := StdInputCursorFocusHandler.get_focus_target()
	if params.expect_target:
		assert_eq(got, button)
	else:
		assert_null(got)


func test_clear_press_on_focus_root_exit_sends_focus_exit_to_pressed_button() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)
	var modal := Control.new()
	add_child_autofree(modal)

	# NOTE: SubViewport required; root viewport doesn't dispatch GUI input in headless
	# mode (see https://github.com/godotengine/godot/issues/73557).
	var sv := SubViewport.new()
	sv.size = Vector2i(400, 300)
	add_child_autofree(sv)

	# Given: A button inside the SubViewport with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.size = Vector2(100, 40)
	sv.add_child(button)
	var handler := _add_handler(button)
	await get_tree().process_frame

	# Given: The button is pressed via SubViewport input dispatch.
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(50, 20)
	sv.push_input(ev)
	await get_tree().process_frame
	assert_true(button.is_pressed(), "precondition: button should be pressed")

	# When: Focus root is set to the modal (button moves outside).
	cursor.focus_root_changed.emit(modal)

	# Then: The button is no longer pressed.
	assert_false(button.is_pressed())

	button.remove_child(handler)
	handler.free()


func test_clear_press_on_focus_root_exit_clears_hovered_button() -> void:
	# Given: A hovered button with a focus handler outside a modal.
	var parts := _setup_outside_focus_root()
	var button: Button = parts[0]
	var modal: Control = parts[2]
	button.notification(Control.NOTIFICATION_MOUSE_ENTER)
	assert_true(button.is_hovered())

	# When: Focus root is set to the modal.
	cursor.focus_root_changed.emit(modal)

	# Then: The button is no longer hovered.
	assert_false(button.is_hovered())


func test_clear_press_on_focus_root_exit_skips_toggle_buttons() -> void:
	# Given: A checked toggle checkbox with a focus handler outside a modal.
	add_child_autofree(cursor)
	var modal := Control.new()
	add_child_autofree(modal)
	var checkbox := CheckBox.new()
	checkbox.focus_mode = Control.FOCUS_ALL
	checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
	checkbox.button_pressed = true
	add_child_autofree(checkbox)
	_add_handler(checkbox)

	# When: Focus root is set to the modal.
	cursor.focus_root_changed.emit(modal)

	# Then: The checkbox toggle state is NOT cleared.
	assert_true(checkbox.button_pressed)


func test_clear_press_on_focus_root_exit_clears_hovered_toggle_button() -> void:
	# Given: A hovered, checked toggle checkbox with a focus handler outside a modal.
	add_child_autofree(cursor)
	var modal := Control.new()
	add_child_autofree(modal)
	var checkbox := CheckBox.new()
	checkbox.focus_mode = Control.FOCUS_ALL
	checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
	checkbox.button_pressed = true
	add_child_autofree(checkbox)
	_add_handler(checkbox)
	checkbox.notification(Control.NOTIFICATION_MOUSE_ENTER)
	assert_true(checkbox.is_hovered())

	# When: Focus root is set to the modal.
	cursor.focus_root_changed.emit(modal)

	# Then: The checkbox toggle state is preserved but hover is cleared.
	assert_true(checkbox.button_pressed)
	assert_false(checkbox.is_hovered())


func test_clear_press_on_focus_root_exit_disabled_preserves_state() -> void:
	# Given: A hovered button with clear_press_on_focus_root_exit disabled.
	var parts := _setup_outside_focus_root()
	var button: Button = parts[0]
	var handler: StdInputCursorFocusHandler = parts[1]
	var modal: Control = parts[2]
	handler.clear_press_on_focus_root_exit = false
	button.notification(Control.NOTIFICATION_MOUSE_ENTER)
	assert_true(button.is_hovered())

	# When: Focus root is set to the modal.
	cursor.focus_root_changed.emit(modal)

	# Then: The button is still hovered.
	assert_true(button.is_hovered())


func test_clear_press_on_focus_root_exit_noop_already_outside() -> void:
	# Given: A button already outside focus root (modal_a).
	var parts := _setup_outside_focus_root()
	var button: Button = parts[0]
	var modal_a: Control = parts[2]
	cursor.focus_root_changed.emit(modal_a)

	# Given: A second modal and stale hover on the button.
	var modal_b := Control.new()
	add_child_autofree(modal_b)
	button.notification(Control.NOTIFICATION_MOUSE_ENTER)
	assert_true(button.is_hovered())

	# When: Focus root changes to modal_b (button still outside).
	cursor.focus_root_changed.emit(modal_b)

	# Then: Hover is NOT cleared (was already outside; not a transition).
	assert_true(button.is_hovered())


func test_disabled_button_clears_pressed_visual() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# NOTE: SubViewport required; root viewport doesn't dispatch GUI input in headless
	# mode (see https://github.com/godotengine/godot/issues/73557).
	var sv := SubViewport.new()
	sv.size = Vector2i(400, 300)
	add_child_autofree(sv)

	# Given: A button inside the SubViewport with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.size = Vector2(100, 40)
	sv.add_child(button)
	var handler := _add_handler(button)
	await get_tree().process_frame

	# Given: The button is pressed via SubViewport input dispatch.
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(50, 20)
	sv.push_input(ev)
	await get_tree().process_frame
	assert_true(button.is_pressed(), "precondition: button should be pressed")

	# When: The button becomes disabled.
	button.disabled = true
	button.queue_redraw()
	await get_tree().process_frame

	# Then: The button is no longer pressed.
	assert_false(button.is_pressed())

	button.remove_child(handler)
	handler.free()


func test_disabled_button_releases_focus() -> void:
	# Given: A cursor in the scene with hidden cursor (focus mode).
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A focused button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)
	var handler := _add_handler(button)
	await get_tree().process_frame

	# Given: The button has focus.
	button.grab_focus()
	assert_true(button.has_focus(), "precondition: button should have focus")

	# When: The button becomes disabled (triggers _on_control_draw → _update_input_state).
	button.disabled = true
	button.queue_redraw()
	await get_tree().process_frame

	# Then: The button no longer has focus.
	assert_false(button.has_focus())

	button.remove_child(handler)
	handler.free()


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	# Clear global state before each test.
	StdGroup.with_id(StdInputCursor.GROUP_INPUT_CURSOR).clear_members()
	StdInputCursorFocusHandler._anchors.clear()

	cursor = autofree(StdInputCursor.new())


func after_each() -> void:
	cursor = null


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _add_handler(control: Control) -> StdInputCursorFocusHandler:
	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("..")
	control.add_child(handler)
	return handler


func _setup_outside_focus_root() -> Array:
	add_child_autofree(cursor)
	var modal := Control.new()
	add_child_autofree(modal)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child_autofree(button)
	var handler := _add_handler(button)
	return [button, handler, modal]
