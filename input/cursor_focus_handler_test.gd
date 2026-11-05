# gdlint:disable=max-public-methods
# gdlint:disable=max-file-lines

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


func test_get_focus_target_skips_anchor_whose_focus_an_ancestor_disables() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: An anchor under a container which disables focus for its subtree.
	var container := Control.new()
	container.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	add_child_autofree(container)

	var button := Button.new()
	container.add_child(button)

	var handler := StdInputCursorFocusHandler.new()
	handler.use_as_anchor = true
	button.add_child(handler)

	# Then: No focus target is returned.
	assert_null(StdInputCursorFocusHandler.get_focus_target())

	# When: The container lets its subtree take focus again.
	container.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED

	# Then: The anchor is returned.
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


func test_anchor_beside_its_control_follows_the_controls_visibility() -> void:
	# Given: A cursor in the scene, hidden.
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A hidden panel holding a focusable button.
	var panel := Control.new()
	panel.name = &"Panel"
	panel.hide()
	add_child_autofree(panel)
	var button := Button.new()
	button.name = &"Button"
	button.focus_mode = Control.FOCUS_ALL
	panel.add_child(button)

	# Given: An anchor handler for the button beside the panel rather than under it.
	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("../Panel/Button")
	handler.use_as_anchor = true
	add_child_autofree(handler)
	await get_tree().process_frame
	assert_null(cursor.get_viewport().gui_get_focus_owner(), "precondition: no focus")

	# When: The panel is shown, and the frame ends.
	panel.show()
	await get_tree().process_frame

	# Then: The button has focus.
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), button)


func test_handler_beside_its_control_frees_itself_after_its_control_is_freed() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A panel holding a button.
	var panel := Control.new()
	panel.name = &"Panel"
	add_child_autofree(panel)
	var button := Button.new()
	button.name = &"Button"
	panel.add_child(button)

	# Given: A handler for the button beside the panel rather than under it.
	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("../Panel/Button")
	add_child_autofree(handler)
	await get_tree().process_frame

	# When: The panel leaves the tree and enters it again.
	remove_child(panel)
	add_child(panel)
	await get_tree().process_frame

	# Then: The handler is kept.
	assert_true(is_instance_valid(handler))

	# When: The panel is queued for deletion, and the frame ends.
	panel.queue_free()
	await get_tree().process_frame

	# When: The cursor hides.
	cursor.hide_cursor()
	await get_tree().process_frame

	# Then: The handler is freed.
	assert_false(is_instance_valid(handler))


func test_anchor_beside_its_control_detached_then_freed_is_no_target() -> void:
	# Given: A cursor in the scene, hidden.
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A panel holding a focusable button.
	var panel := Control.new()
	panel.name = &"Panel"
	add_child_autofree(panel)
	var button := Button.new()
	button.name = &"Button"
	button.focus_mode = Control.FOCUS_ALL
	panel.add_child(button)

	# Given: An anchor handler for the button beside the panel rather than under it.
	var handler := StdInputCursorFocusHandler.new()
	handler.control = NodePath("../Panel/Button")
	handler.use_as_anchor = true
	add_child_autofree(handler)
	await get_tree().process_frame
	assert_eq(StdInputCursorFocusHandler.get_focus_target(), button, "precondition")

	# When: The panel is detached, then queued free, as a popped screen is.
	remove_child(panel)
	panel.queue_free()

	# When: The frame ends.
	await get_tree().process_frame

	# Then: No focus target is found.
	assert_null(StdInputCursorFocusHandler.get_focus_target())


func test_handler_under_a_container_takes_no_slot_and_covers_no_sibling() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A box container holding a button.
	var scene := Control.new()
	var box := VBoxContainer.new()
	scene.add_child(box)
	var first := Button.new()
	first.name = &"Button"
	box.add_child(first)

	# Given: A panel container holding another button, below the box.
	var panel := PanelContainer.new()
	panel.position = Vector2(0, 100)
	scene.add_child(panel)
	var second := Button.new()
	second.name = &"Button"
	second.custom_minimum_size = Vector2(100, 40)
	panel.add_child(second)

	# Given: The scene is mounted and laid out.
	var input := await StdTestInput.mount(self, scene)
	var minimum := box.get_combined_minimum_size()

	# When: A handler for each button enters its container beside it.
	var handlers: Array[StdInputCursorFocusHandler] = []
	for container in [box, panel]:
		var handler := StdInputCursorFocusHandler.new()
		handler.control = NodePath("../Button")
		container.add_child(handler)
		handlers.append(handler)
	await wait_idle_frames(1)

	# Then: The box's minimum size is unchanged.
	assert_eq(box.get_combined_minimum_size(), minimum)

	# When: The panel's button is clicked.
	watch_signals(second)
	input.click(second)

	# Then: The click reaches it.
	assert_signal_emitted(second, "pressed")

	for handler in handlers:
		handler.get_parent().remove_child(handler)
		handler.free()


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
				["prior_signal", "trigger_signal", "expected_signal"],
				[
					["", "focus_entered", "focused"],
					["focus_entered", "focus_exited", "unfocused"],
					["", "mouse_entered", "hovered"],
					["mouse_entered", "mouse_exited", "unhovered"],
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

	# Given: The control first emits the signal the trigger follows, if any.
	if params.prior_signal:
		button.get(params.prior_signal).emit()

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
				[
					"block",
					"cursor_visible",
					"expected_focus_mode",
					"expected_mouse_filter"
				],
				[
					[true, true, Control.FOCUS_NONE, Control.MOUSE_FILTER_STOP],
					[true, false, Control.FOCUS_NONE, Control.MOUSE_FILTER_IGNORE],
					[false, true, Control.FOCUS_NONE, Control.MOUSE_FILTER_STOP],
					[false, false, Control.FOCUS_ALL, Control.MOUSE_FILTER_IGNORE],
				]
			)
		)
	)
) -> void:
	# Given: A cursor in the scene, shown or hidden.
	add_child_autofree(cursor)
	if not params.cursor_visible:
		cursor.hide_cursor()

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

	# Then: The button's focus mode and mouse filter follow the blocking and the cursor.
	assert_eq(button.focus_mode, params.expected_focus_mode)
	assert_eq(button.mouse_filter, params.expected_mouse_filter)


func test_disabled_anchor_enabled_under_hidden_cursor_takes_focus() -> void:
	# Given: A cursor in the scene, hidden.
	add_child_autofree(cursor)
	cursor.hide_cursor()

	# Given: A disabled button with an anchor focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = true
	add_child_autofree(button)
	var handler := StdInputCursorFocusHandler.new()
	handler.use_as_anchor = true
	button.add_child(handler)
	await get_tree().process_frame
	assert_null(cursor.get_viewport().gui_get_focus_owner(), "precondition: no focus")

	# When: The button is enabled.
	button.disabled = false

	# When: The button is drawn, and the frame ends.
	await get_tree().process_frame
	await get_tree().process_frame

	# Then: The button has focus.
	assert_eq(cursor.get_viewport().gui_get_focus_owner(), button)


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

	# Given: A press-mode button with a focus handler.
	var setup := await _mount_button(false)
	var input: StdTestInput = setup[0]
	var button: Button = setup[1]
	var handler: StdInputCursorFocusHandler = setup[2]
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS

	# Given: The mouse rests over the button.
	input.move_mouse(button.get_global_rect().get_center())

	# Given: The mouse presses the button.
	input.press_mouse()
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


func test_disabled_button_clears_hover_visual() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: An enabled button with a focus handler.
	var setup := await _mount_button(false)
	var input: StdTestInput = setup[0]
	var button: Button = setup[1]
	var handler: StdInputCursorFocusHandler = setup[2]

	# Given: The mouse rests over the button.
	input.move_mouse(button.get_global_rect().get_center())
	assert_true(button.is_hovered(), "precondition: button should be hovered")

	# When: The button becomes disabled.
	button.disabled = true
	button.queue_redraw()
	await get_tree().process_frame

	# Then: The button is no longer hovered.
	assert_false(button.is_hovered())

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


func test_disabled_button_stops_click_from_reaching_control_behind() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: A control recording the GUI input it receives.
	var behind := Control.new()
	behind.size = Vector2(400, 300)
	behind.mouse_filter = Control.MOUSE_FILTER_STOP
	var behind_received: Array[InputEvent] = []
	behind.gui_input.connect(
		func(event: InputEvent) -> void: behind_received.append(event)
	)

	# Given: A disabled button over it, recording the same.
	var button := Button.new()
	button.disabled = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size = Vector2(100, 40)
	behind.add_child(button)
	var button_received: Array[InputEvent] = []
	button.gui_input.connect(
		func(event: InputEvent) -> void: button_received.append(event)
	)

	# Given: A focus handler on the button.
	var handler := _add_handler(button)

	# Given: Both are mounted at the root, as a game's scene is.
	var input := await StdTestInput.mount(self, behind)

	# When: The button is clicked.
	input.click(button)

	# Then: The click stopped at the button.
	var clicks := button_received.filter(
		func(event: InputEvent) -> bool: return event is InputEventMouseButton
	)
	assert_eq(clicks.size(), 2)
	assert_eq(behind_received.size(), 0)

	button.remove_child(handler)
	handler.free()


func test_disabled_button_takes_no_hover() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: A disabled button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = true
	add_child_autofree(button)
	var handler := _add_handler(button)
	watch_signals(handler)

	# When: The mouse enters the button.
	button.mouse_entered.emit()

	# Then: Nothing registers the hover.
	assert_false(handler.is_hovered())
	assert_signal_not_emitted(handler, "hovered")
	assert_null(cursor.get_hovered())


func test_disabled_button_mouse_exit_emits_no_unhovered() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: A disabled button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = true
	add_child_autofree(button)
	var handler := _add_handler(button)

	# Given: The mouse entered the button.
	button.mouse_entered.emit()
	watch_signals(handler)

	# When: The mouse exits the button.
	button.mouse_exited.emit()

	# Then: No hover is reported as ending.
	assert_signal_not_emitted(handler, "unhovered")


func test_button_disabled_while_hovered_is_unhovered() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: A hovered button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)
	var handler := _add_handler(button)
	await get_tree().process_frame
	button.mouse_entered.emit()
	assert_true(handler.is_hovered(), "precondition: button should be hovered")
	watch_signals(handler)

	# When: The button becomes disabled.
	button.disabled = true
	button.queue_redraw()
	await get_tree().process_frame

	# Then: The hover is forgotten.
	assert_false(handler.is_hovered())
	assert_signal_emitted(handler, "unhovered")
	assert_null(cursor.get_hovered())


func test_button_disabled_while_hovered_emits_no_unhovered_on_exit() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: A hovered button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)
	var handler := _add_handler(button)
	await get_tree().process_frame
	button.mouse_entered.emit()

	# Given: The button becomes disabled, which ends its hover.
	button.disabled = true
	button.queue_redraw()
	await get_tree().process_frame
	watch_signals(handler)

	# When: The mouse exits the button.
	button.mouse_exited.emit()

	# Then: The ended hover isn't reported again.
	assert_signal_not_emitted(handler, "unhovered")


func test_button_enabled_under_mouse_is_hovered() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: A disabled button with a focus handler.
	var setup := await _mount_button(true)
	var input: StdTestInput = setup[0]
	var button: Button = setup[1]
	var handler: StdInputCursorFocusHandler = setup[2]

	# Given: The button's draw modes are recorded as it draws.
	var drawn: Array[int] = []
	button.draw.connect(func() -> void: drawn.append(button.get_draw_mode()))

	# Given: The mouse rests over the button.
	input.move_mouse(button.get_global_rect().get_center())
	await get_tree().process_frame
	watch_signals(handler)

	# When: The button becomes enabled.
	button.disabled = false
	await get_tree().process_frame

	# Then: The hover is registered once by the frame's end.
	assert_true(handler.is_hovered())
	assert_signal_emit_count(handler, "hovered", 1)
	assert_eq(cursor.get_hovered(), button)

	# Then: The button was last drawn as hovered.
	assert_eq(drawn.back(), BaseButton.DRAW_HOVER)

	button.remove_child(handler)
	handler.free()


func test_button_reenabled_under_mouse_is_hovered() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: An enabled button with a focus handler.
	var setup := await _mount_button(false)
	var input: StdTestInput = setup[0]
	var button: Button = setup[1]
	var handler: StdInputCursorFocusHandler = setup[2]

	# Given: The mouse hovers the button.
	input.move_mouse(button.get_global_rect().get_center())
	await get_tree().process_frame

	# Given: The button becomes disabled under the mouse.
	button.disabled = true
	await get_tree().process_frame
	assert_false(handler.is_hovered(), "precondition: button should be unhovered")
	watch_signals(handler)

	# When: The button becomes enabled again.
	button.disabled = false
	await get_tree().process_frame

	# Then: The hover is registered again.
	assert_true(handler.is_hovered())
	assert_signal_emit_count(handler, "hovered", 1)
	assert_eq(cursor.get_hovered(), button)

	button.remove_child(handler)
	handler.free()


func test_button_enabled_after_mouse_leaves_stays_unhovered() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: A disabled button with a focus handler.
	var setup := await _mount_button(true)
	var input: StdTestInput = setup[0]
	var button: Button = setup[1]
	var handler: StdInputCursorFocusHandler = setup[2]

	# Given: The mouse moves over the button.
	input.move_mouse(button.get_global_rect().get_center())

	# Given: The mouse moves off the button.
	input.move_mouse(Vector2(300, 200))
	await get_tree().process_frame
	watch_signals(handler)

	# When: The button becomes enabled.
	button.disabled = false
	await get_tree().process_frame

	# Then: Nothing registers the hover.
	assert_false(handler.is_hovered())
	assert_signal_not_emitted(handler, "hovered")
	assert_null(cursor.get_hovered())

	button.remove_child(handler)
	handler.free()


func test_button_enabled_behind_new_overlay_stays_unhovered() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: A disabled button with a focus handler.
	var setup := await _mount_button(true)
	var input: StdTestInput = setup[0]
	var button: Button = setup[1]
	var handler: StdInputCursorFocusHandler = setup[2]

	# Given: The mouse rests over the button.
	input.move_mouse(button.get_global_rect().get_center())

	# Given: An overlay opens over the button as the focus root.
	_open_overlay(button)
	await get_tree().process_frame
	watch_signals(handler)

	# When: The button becomes enabled.
	button.disabled = false
	await get_tree().process_frame

	# Then: Nothing registers the hover.
	assert_false(handler.is_hovered())
	assert_signal_not_emitted(handler, "hovered")
	assert_null(cursor.get_hovered())

	button.remove_child(handler)
	handler.free()


func test_button_enabled_behind_overlay_is_hovered_once_overlay_closes() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: A disabled button with a focus handler.
	var setup := await _mount_button(true)
	var input: StdTestInput = setup[0]
	var button: Button = setup[1]
	var handler: StdInputCursorFocusHandler = setup[2]

	# Given: The mouse rests over the button.
	input.move_mouse(button.get_global_rect().get_center())

	# Given: An overlay opens over the button as the focus root.
	var overlay := _open_overlay(button)
	await get_tree().process_frame

	# Given: The button becomes enabled behind the overlay.
	button.disabled = false
	await get_tree().process_frame
	watch_signals(handler)

	# When: The overlay closes.
	cursor.release_focus(overlay)
	overlay.free()
	await get_tree().process_frame

	# Then: The hover is registered.
	assert_true(handler.is_hovered())
	assert_signal_emit_count(handler, "hovered", 1)
	assert_eq(cursor.get_hovered(), button)

	button.remove_child(handler)
	handler.free()


func test_button_hovered_behind_overlay_is_drawn_hovered_once_overlay_closes() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: An enabled button with a focus handler.
	var setup := await _mount_button(false)
	var input: StdTestInput = setup[0]
	var button: Button = setup[1]
	var handler: StdInputCursorFocusHandler = setup[2]

	# Given: The mouse hovers the button.
	input.move_mouse(button.get_global_rect().get_center())
	await get_tree().process_frame

	# Given: An overlay opens over the button, which clears its hover visuals.
	var overlay := _open_overlay(button)
	await get_tree().process_frame
	assert_false(button.is_hovered(), "precondition: button should look unhovered")
	watch_signals(handler)

	# When: The overlay closes.
	cursor.release_focus(overlay)
	overlay.free()
	await get_tree().process_frame

	# Then: The button is drawn hovered again.
	assert_true(button.is_hovered())
	assert_eq(button.get_draw_mode(), BaseButton.DRAW_HOVER)

	# Then: The hover, which never ended, isn't reported again.
	assert_true(handler.is_hovered())
	assert_signal_not_emitted(handler, "hovered")
	assert_eq(cursor.get_hovered(), button)

	button.remove_child(handler)
	handler.free()


func test_button_left_behind_overlay_stays_unhovered_once_overlay_closes() -> void:
	# Given: A cursor in the scene (starts visible).
	add_child_autofree(cursor)

	# Given: An enabled button with a focus handler.
	var setup := await _mount_button(false)
	var input: StdTestInput = setup[0]
	var button: Button = setup[1]
	var handler: StdInputCursorFocusHandler = setup[2]

	# Given: The mouse hovers the button.
	input.move_mouse(button.get_global_rect().get_center())
	await get_tree().process_frame

	# Given: An overlay opens over the button as the focus root.
	var overlay := _open_overlay(button)
	await get_tree().process_frame

	# Given: The mouse moves, so the overlay takes it from the button.
	input.move_mouse(Vector2(60, 22))
	await get_tree().process_frame
	watch_signals(handler)

	# When: The overlay closes.
	cursor.release_focus(overlay)
	overlay.free()
	await get_tree().process_frame

	# Then: The button stays unhovered.
	assert_false(button.is_hovered())
	assert_false(handler.is_hovered())
	assert_signal_not_emitted(handler, "hovered")
	assert_null(cursor.get_hovered())

	button.remove_child(handler)
	handler.free()


func test_click_while_cursor_visible_restores_focus_to_clicked_button() -> void:
	# Given: Two buttons with focus handlers, the first focused before a reveal.
	var setup := await _setup_reveal_from_first_button()
	var input: StdTestInput = setup[0]
	var first: Button = setup[1]
	var second: Button = setup[2]

	# When: The second button is clicked.
	input.click(second)

	# When: The mouse leaves the button.
	input.move_mouse(Vector2(300, 250))

	# When: The cursor hides with nothing hovered.
	cursor.hide_cursor()

	# When: The frame ends.
	await get_tree().process_frame

	# Then: The clicked button has focus rather than the one from before the reveal.
	assert_true(second.has_focus())
	assert_false(first.has_focus())


func test_click_which_reveals_cursor_restores_focus_to_clicked_button() -> void:
	# Given: Two buttons with focus handlers, the first focused before a reveal.
	var setup := await _setup_reveal_from_first_button()
	var input: StdTestInput = setup[0]
	var first: Button = setup[1]
	var second: Button = setup[2]

	# Given: The cursor hides, which returns focus to the first button.
	cursor.hide_cursor()
	await get_tree().process_frame
	assert_true(first.has_focus(), "precondition: first button focused")

	# When: The mouse moves over the second button while the cursor is hidden.
	input.move_mouse(second.get_global_rect().get_center())

	# When: The second button is clicked, which reveals the cursor.
	input.click(second)
	assert_true(cursor.get_is_visible(), "precondition: click revealed the cursor")

	# When: The mouse leaves the button.
	input.move_mouse(Vector2(300, 250))

	# When: The cursor hides with nothing hovered.
	cursor.hide_cursor()

	# When: The frame ends.
	await get_tree().process_frame

	# Then: The clicked button has focus rather than the one from before the reveal.
	assert_true(second.has_focus())
	assert_false(first.has_focus())


func test_wheel_over_button_keeps_focus_from_before_reveal() -> void:
	# Given: Two buttons with focus handlers, the first focused before a reveal.
	var setup := await _setup_reveal_from_first_button()
	var input: StdTestInput = setup[0]
	var first: Button = setup[1]
	var second: Button = setup[2]

	# When: The wheel scrolls over the second button.
	input.click(second, MOUSE_BUTTON_WHEEL_DOWN)

	# When: The mouse leaves the button.
	input.move_mouse(Vector2(300, 250))

	# When: The cursor hides with nothing hovered.
	cursor.hide_cursor()

	# When: The frame ends.
	await get_tree().process_frame

	# Then: The button from before the reveal has focus again.
	assert_true(first.has_focus())


func test_click_on_disabled_button_keeps_focus_from_before_reveal() -> void:
	# Given: Two buttons with focus handlers, the first focused before a reveal.
	var setup := await _setup_reveal_from_first_button()
	var input: StdTestInput = setup[0]
	var first: Button = setup[1]
	var second: Button = setup[2]

	# Given: The second button is disabled.
	second.disabled = true
	await get_tree().process_frame

	# When: The disabled button is clicked.
	input.click(second)

	# When: The mouse leaves the button.
	input.move_mouse(Vector2(300, 250))

	# When: The cursor hides with nothing hovered.
	cursor.hide_cursor()

	# When: The frame ends.
	await get_tree().process_frame

	# Then: The button from before the reveal has focus again.
	assert_true(first.has_focus())


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


## _mount_button mounts a button with the given `disabled` state and a focus handler,
## and returns them as `[input, button, handler]`.
func _mount_button(disabled: bool) -> Array:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.disabled = disabled
	button.size = Vector2(100, 40)
	var handler := _add_handler(button)

	var input := await StdTestInput.mount(self, button)

	return [input, button, handler]


## _open_overlay adds a mouse-stopping overlay over `button`, covering the viewport,
## claims it as the focus root, and returns it.
func _open_overlay(button: Button) -> Control:
	var overlay := Control.new()
	overlay.size = button.get_viewport_rect().size
	button.add_sibling(overlay)
	cursor.claim_focus(overlay)
	return overlay


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


## _setup_reveal_from_first_button mounts two buttons with focus handlers, focuses the
## first, and reveals the cursor, returning them as `[input, first, second]`.
func _setup_reveal_from_first_button() -> Array:
	add_child_autofree(cursor)
	cursor.update_configuration([StdInputActionSet.new()])

	var scene := Control.new()

	var buttons: Array[Button] = []
	for i in 2:
		var button := Button.new()
		button.size = Vector2(100, 40)
		button.position = Vector2(0, 100 * i)
		scene.add_child(button)
		_add_handler(button)
		buttons.append(button)

	var input := await StdTestInput.mount(self, scene)

	cursor.hide_cursor()
	buttons[0].grab_focus()
	cursor.show_cursor()
	assert_false(buttons[0].has_focus(), "precondition: focus released on reveal")

	return [input, buttons[0], buttons[1]]
