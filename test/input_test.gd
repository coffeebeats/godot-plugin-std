# gdlint:ignore=max-public-methods
##
## Tests pertaining to the `StdTestInput` class.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

const _DRAG_DISTANCE := Vector2(50, 0)
const _DRAG_PAYLOAD := "payload"
const _GUT_LAYER_PATH := ^"GutRunner/GutLayer"


## DragScene holds a control which starts a drag, and one which accepts the drop.
class DragScene:
	extends Control

	var source := DragSource.new()
	var target := DropTarget.new()

	func _init() -> void:
		source.position = Vector2(100, 100)
		source.size = Vector2(100, 40)
		add_child(source)

		target.position = Vector2(400, 100)
		target.size = Vector2(100, 40)
		add_child(target)


## DragSource offers a payload to drag.
class DragSource:
	extends Button

	func _get_drag_data(_at_position: Vector2) -> Variant:
		return _DRAG_PAYLOAD


## DropTarget records what's dropped on it.
class DropTarget:
	extends Control

	var dropped: Array[Variant] = []

	func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
		return true

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		dropped.append(data)


## UnhandledInputRecorder records the input events left unhandled in its viewport.
class UnhandledInputRecorder:
	extends Node

	var events: Array[InputEvent] = []

	func _unhandled_input(event: InputEvent) -> void:
		events.append(event)


# -- INITIALIZATION ------------------------------------------------------------------ #

var _ui_accept_events: Array[InputEvent] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_click_mounted_button_presses_focuses_and_hovers_it(
	params = use_parameters(
		[
			# NOTE: This is under GUT's panel.
			Vector2(10, 10),
			# NOTE: This is beyond the headless root's own size.
			Vector2(400, 300),
		]
	)
) -> void:
	# Given: A button at the given position.
	var button := _make_button(params)
	var pressed := _count_pressed(button)

	# Given: The button is mounted.
	var input := await StdTestInput.mount(self, button)

	# When: The button is clicked.
	input.click(button)

	# Then: The click was picked as a real one is.
	assert_eq(pressed.size(), 1)
	assert_true(button.has_focus())
	assert_eq(get_tree().root.gui_get_hovered_control(), button)


func test_click_overlapping_controls_picks_topmost() -> void:
	# Given: Two buttons in the same place, the second drawn over the first.
	var scene := Control.new()
	var back := _make_button(Vector2(100, 100))
	var front := _make_button(Vector2(100, 100))
	scene.add_child(back)
	scene.add_child(front)
	var back_pressed := _count_pressed(back)
	var front_pressed := _count_pressed(front)

	# Given: The buttons are mounted.
	var input := await StdTestInput.mount(self, scene)

	# When: The covered button is clicked.
	input.click(back)

	# Then: The button on top took the click.
	assert_eq(front_pressed.size(), 1)
	assert_eq(back_pressed.size(), 0)


func test_click_sends_motion_then_press_then_release() -> void:
	# Given: A mounted button recording the GUI input it receives.
	var button := _make_button(Vector2(100, 100))
	var received := _record_gui_input(button)
	var input := await StdTestInput.mount(self, button)

	# When: The button is clicked.
	input.click(button)

	# Then: The mouse arrived before it pressed, as a player's does.
	assert_eq(received.size(), 3)
	assert_true(received[0] is InputEventMouseMotion)
	assert_true(received[1] is InputEventMouseButton and received[1].pressed)
	assert_true(received[2] is InputEventMouseButton and not received[2].pressed)


func test_click_moves_mouse_to_control_center() -> void:
	# Given: A mounted button.
	var button := _make_button(Vector2(400, 300))
	var input := await StdTestInput.mount(self, button)

	# When: The button is clicked.
	input.click(button)

	# Then: The root's mouse position is at the button's center.
	var center := button.get_global_rect().get_center()
	assert_eq(get_tree().root.get_mouse_position(), center)


func test_click_updates_polled_mouse_state() -> void:
	# Given: A button recording what `Input` reports when it goes down.
	var button := _make_button(Vector2(100, 100))
	var polled: Array[bool] = []
	button.button_down.connect(
		func() -> void: polled.append(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	)

	# Given: The button is mounted.
	var input := await StdTestInput.mount(self, button)

	# When: The button is clicked.
	input.click(button)

	# Then: `Input` saw the press.
	assert_eq(polled, [true] as Array[bool])

	# Then: `Input` doesn't report the button as held afterward.
	assert_false(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))


func test_click_at_position_picks_control_there() -> void:
	# Given: A mounted button.
	var button := _make_button(Vector2(400, 300))
	var pressed := _count_pressed(button)
	var input := await StdTestInput.mount(self, button)

	# When: A point inside the button is clicked.
	input.click_at(Vector2(410, 310))

	# Then: The button took the click.
	assert_eq(pressed.size(), 1)

	# When: A point outside the button is clicked.
	input.click_at(Vector2(50, 50))

	# Then: The button didn't take it.
	assert_eq(pressed.size(), 1)


func test_click_at_button_index_sends_that_button() -> void:
	# Given: A mounted button recording the GUI input it receives.
	var button := _make_button(Vector2(100, 100))
	var received := _record_gui_input(button)
	var input := await StdTestInput.mount(self, button)

	# When: The button is clicked with the right mouse button.
	input.click_at(Vector2(110, 110), MOUSE_BUTTON_RIGHT)

	# Then: The press and release are of that button.
	assert_eq(received[1].button_index, MOUSE_BUTTON_RIGHT)
	assert_eq(received[2].button_index, MOUSE_BUTTON_RIGHT)


func test_mount_container_child_lays_out_before_returning() -> void:
	# Given: A button with no size of its own, centered by a full-rect container.
	var container := CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	var button := Button.new()
	button.text = "Button"
	container.add_child(button)
	var pressed := _count_pressed(button)

	# When: The container is mounted.
	var input := await StdTestInput.mount(self, container)

	# Then: The container fills the root and centers the button.
	var visible_rect := get_tree().root.get_visible_rect()
	assert_eq(container.size, visible_rect.size)
	assert_true(button.get_global_rect().has_point(visible_rect.get_center()))

	# When: The button is clicked.
	input.click(button)

	# Then: The click landed on it.
	assert_eq(pressed.size(), 1)


func test_mount_registers_helper_to_be_freed_with_the_test() -> void:
	# Given: The number of nodes GUT will free after this test.
	var count_before: int = gut.get_autofree().get_free_count()

	# When: A scene is mounted.
	await StdTestInput.mount(self, Control.new())

	# Then: GUT will free the helper too.
	assert_eq(gut.get_autofree().get_free_count(), count_before + 1)


func test_mount_free_restores_root_and_gut_layer() -> void:
	# Given: A root sized differently from the project's window.
	var root := get_tree().root
	var size_before := root.size
	root.size = Vector2i(64, 64)

	# Given: GUT's panel is shown.
	var gut_layer: CanvasLayer = root.get_node(_GUT_LAYER_PATH)
	assert_true(gut_layer.visible, "precondition: GUT's panel is shown")

	# Given: A mounted scene.
	var input := await StdTestInput.mount(self, Control.new())

	# Then: The root has changed size and GUT's panel is hidden.
	assert_ne(root.size, Vector2i(64, 64))
	assert_false(gut_layer.visible)

	# When: The helper is freed.
	input.free()

	# Then: The root and GUT's panel are as they were.
	assert_eq(root.size, Vector2i(64, 64))
	assert_true(gut_layer.visible)

	root.size = size_before


func test_mount_free_restores_mouse_position() -> void:
	# Given: The root's mouse position before mounting.
	var root := get_tree().root
	var position_before := root.get_mouse_position()

	# Given: A mounted scene.
	var input := await StdTestInput.mount(self, Control.new())

	# Given: The mouse moved elsewhere.
	input.move_mouse(position_before + Vector2(200, 100))
	assert_ne(root.get_mouse_position(), position_before, "precondition: mouse moved")

	# When: The helper is freed.
	input.free()

	# Then: The mouse is back where it was.
	assert_eq(root.get_mouse_position(), position_before)


func test_mount_free_frees_mounted_scene() -> void:
	# Given: A mounted scene.
	var scene := Control.new()
	var input := await StdTestInput.mount(self, scene)

	# When: The helper is freed.
	input.free()

	# Then: The scene is freed with it.
	assert_false(is_instance_valid(scene))


func test_mount_free_without_mounting_leaves_root_unchanged() -> void:
	# Given: The root's size.
	var root := get_tree().root
	var size_before := root.size

	# Given: A helper in the tree which never mounted anything.
	var input := StdTestInput.new()
	add_child(input)

	# When: The helper is freed.
	input.free()

	# Then: The root is unchanged.
	assert_eq(root.size, size_before)


func test_mount_content_scale_click_reaches_button() -> void:
	# Given: A root drawn at twice its size.
	var root := get_tree().root
	var scale_before := root.content_scale_factor
	root.content_scale_factor = 2.0

	# Given: A mounted button.
	var button := _make_button(Vector2(200, 100))
	var pressed := _count_pressed(button)
	var input := await StdTestInput.mount(self, button)

	# When: The button is clicked.
	input.click(button)

	# Then: The click landed on it.
	assert_eq(pressed.size(), 1)

	# Then: The mouse is at its center in root coordinates.
	assert_eq(root.get_mouse_position(), button.get_global_rect().get_center())

	root.content_scale_factor = scale_before


func test_mount_sizes_root_to_project_window() -> void:
	# Given: The project's window size.
	var window_size := Vector2(
		ProjectSettings.get_setting(&"display/window/size/viewport_width"),
		ProjectSettings.get_setting(&"display/window/size/viewport_height"),
	)

	# When: A scene is mounted.
	await StdTestInput.mount(self, Control.new())

	# Then: The root has both of the project's dimensions.
	assert_eq(get_tree().root.get_visible_rect().size, window_size)


func test_move_mouse_updates_hover() -> void:
	# Given: A mounted button.
	var button := _make_button(Vector2(400, 300))
	var input := await StdTestInput.mount(self, button)

	# When: The mouse moves over the button.
	input.move_mouse(button.get_global_rect().get_center())

	# Then: The button is hovered.
	assert_true(button.is_hovered())

	# When: The mouse moves off the button.
	input.move_mouse(Vector2(50, 50))

	# Then: The button is no longer hovered.
	assert_false(button.is_hovered())


func test_move_mouse_reveals_hidden_cursor_only_with_relative_distance() -> void:
	# Given: A mounted cursor.
	StdGroup.with_id(StdInputCursor.GROUP_INPUT_CURSOR).clear_members()
	var cursor := StdInputCursor.new()
	var input := await StdTestInput.mount(self, cursor)
	cursor.update_configuration([StdInputActionSet.new()])

	# Given: The cursor is hidden.
	cursor.hide_cursor()

	# When: The mouse moves with no relative distance.
	input.move_mouse(Vector2(400, 300))

	# Then: The cursor stays hidden.
	assert_false(cursor.get_is_visible())

	# When: The mouse moves with a relative distance.
	input.move_mouse(Vector2(450, 300), Vector2(50, 0))

	# Then: The cursor is revealed.
	assert_true(cursor.get_is_visible())


func test_move_mouse_carries_buttons_held_at_the_time() -> void:
	# Given: A mounted control recording its input, with the mouse over it.
	var control := Control.new()
	control.size = Vector2(200, 200)
	var received := _record_gui_input(control)
	var input := await StdTestInput.mount(self, control)
	input.move_mouse(Vector2(10, 10))

	# When: The mouse moves during a press.
	input.press_mouse()
	input.move_mouse(Vector2(20, 10))

	# Then: The motion reports the held button.
	assert_eq(received[-1].button_mask, MOUSE_BUTTON_MASK_LEFT)

	# When: The mouse moves after the release.
	input.release_mouse()
	input.move_mouse(Vector2(30, 10))

	# Then: The motion reports no button.
	assert_eq(received[-1].button_mask, 0)


func test_move_mouse_without_relative_distance_starts_no_drag() -> void:
	# Given: A press on a mounted drag source.
	var scene := DragScene.new()
	var input := await StdTestInput.mount(self, scene)
	input.move_mouse(scene.source.get_global_rect().get_center())
	input.press_mouse()

	# When: The mouse moves without a distance.
	input.move_mouse(scene.target.get_global_rect().get_center())

	# Then: No drag started.
	assert_false(get_viewport().gui_is_dragging())


func test_press_action_focused_button_holds_action_and_presses_on_release() -> void:
	# Given: A mounted button.
	var button := _make_button(Vector2(100, 100))
	var pressed := _count_pressed(button)
	var input := await StdTestInput.mount(self, button)

	# Given: The button has focus.
	button.grab_focus()

	# When: An action which activates the button is pressed.
	input.press_action(&"ui_accept")

	# Then: The action is held and the button hasn't fired yet.
	assert_true(Input.is_action_pressed(&"ui_accept"))
	assert_eq(pressed.size(), 0)

	# When: The action is released.
	input.release_action(&"ui_accept")

	# Then: The action is no longer held and the button fired.
	assert_false(Input.is_action_pressed(&"ui_accept"))
	assert_eq(pressed.size(), 1)


func test_press_key_focused_button_presses_on_release() -> void:
	# Given: A mounted button.
	var button := _make_button(Vector2(100, 100))
	var pressed := _count_pressed(button)
	var input := await StdTestInput.mount(self, button)

	# Given: The button has focus.
	button.grab_focus()

	# When: A key bound to `ui_accept` is pressed and released.
	input.press_key(KEY_ENTER)
	input.release_key(KEY_ENTER)

	# Then: The button fired.
	assert_eq(pressed.size(), 1)


func test_press_key_updates_polled_key_state() -> void:
	# Given: A mounted scene.
	var input := await StdTestInput.mount(self, Control.new())

	# When: A key bound to `ui_accept` is pressed.
	input.press_key(KEY_ENTER)

	# Then: `Input` saw it.
	assert_true(Input.is_key_pressed(KEY_ENTER))
	assert_true(Input.is_action_pressed(&"ui_accept"))

	# When: The key is released.
	input.release_key(KEY_ENTER)

	# Then: Neither is held.
	assert_false(Input.is_key_pressed(KEY_ENTER))
	assert_false(Input.is_action_pressed(&"ui_accept"))


func test_press_key_with_nothing_focused_reaches_unhandled_input() -> void:
	# Given: A mounted scene recording unhandled input.
	var recorder := UnhandledInputRecorder.new()
	var input := await StdTestInput.mount(self, recorder)

	# When: A key is pressed and released.
	input.press_key(KEY_ESCAPE)
	input.release_key(KEY_ESCAPE)

	# Then: The recorder saw the press and then the release of that key.
	assert_eq(recorder.events.size(), 2)
	assert_eq(recorder.events[0].keycode, KEY_ESCAPE)
	assert_true(recorder.events[0].pressed)
	assert_eq(recorder.events[1].keycode, KEY_ESCAPE)
	assert_false(recorder.events[1].pressed)


func test_press_mouse_holds_button_until_released() -> void:
	# Given: A mounted button with the mouse over it.
	var button := _make_button(Vector2(100, 100))
	var pressed := _count_pressed(button)
	var input := await StdTestInput.mount(self, button)
	input.move_mouse(button.get_global_rect().get_center())

	# When: The mouse button is pressed.
	input.press_mouse()

	# Then: It's held and the button hasn't fired yet.
	assert_true(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	assert_eq(pressed.size(), 0)

	# When: The mouse button is released.
	input.release_mouse()

	# Then: It's no longer held and the button fired.
	assert_false(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	assert_eq(pressed.size(), 1)


func test_press_mouse_then_move_mouse_past_threshold_drags_and_drops() -> void:
	# Given: A press on a mounted drag source.
	var scene := DragScene.new()
	var input := await StdTestInput.mount(self, scene)
	input.move_mouse(scene.source.get_global_rect().get_center())
	input.press_mouse()

	# When: The mouse moves past the drag threshold.
	input.move_mouse(scene.target.get_global_rect().get_center(), _DRAG_DISTANCE)

	# Then: A drag started.
	assert_true(get_viewport().gui_is_dragging())

	# When: The mouse button is released over the target.
	input.release_mouse()

	# Then: The payload dropped and the drag ended.
	assert_eq(scene.target.dropped, [_DRAG_PAYLOAD] as Array[Variant])
	assert_false(get_viewport().gui_is_dragging())


func test_send_dispatches_event_through_input() -> void:
	# Given: A mounted scene recording unhandled input.
	var recorder := UnhandledInputRecorder.new()
	var input := await StdTestInput.mount(self, recorder)

	# When: A joypad button is sent.
	input.send(_make_joy_button(0, JOY_BUTTON_X))

	# Then: `Input` saw it and it reached the scene.
	assert_true(Input.is_joy_button_pressed(0, JOY_BUTTON_X))
	assert_eq(recorder.events.size(), 1)
	assert_eq(recorder.events[0].button_index, JOY_BUTTON_X)


func test_send_free_releases_each_held_input() -> void:
	# Given: A mounted scene.
	var input := await StdTestInput.mount(self, Control.new())

	# Given: A press of each kind is held, on two joypads.
	input.press_mouse()
	input.press_key(KEY_F1)
	input.press_action(&"ui_accept")
	input.send(_make_joy_button(0, JOY_BUTTON_X))
	input.send(_make_joy_button(1, JOY_BUTTON_X))
	assert_true(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "precondition: mouse")
	assert_true(Input.is_key_pressed(KEY_F1), "precondition: key")
	assert_true(Input.is_action_pressed(&"ui_accept"), "precondition: action")
	assert_true(Input.is_joy_button_pressed(0, JOY_BUTTON_X), "precondition: joypad 0")
	assert_true(Input.is_joy_button_pressed(1, JOY_BUTTON_X), "precondition: joypad 1")

	# When: The helper is freed.
	input.free()

	# Then: None of them is held.
	assert_false(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	assert_false(Input.is_key_pressed(KEY_F1))
	assert_false(Input.is_action_pressed(&"ui_accept"))
	assert_false(Input.is_joy_button_pressed(0, JOY_BUTTON_X))
	assert_false(Input.is_joy_button_pressed(1, JOY_BUTTON_X))


func test_send_free_releases_action_after_bound_joypad_event() -> void:
	# Given: An action bound to a joypad button.
	InputMap.action_add_event(&"ui_accept", _make_joy_button(-1, JOY_BUTTON_Y))

	# Given: A mounted scene holding the action.
	var input := await StdTestInput.mount(self, Control.new())
	input.press_action(&"ui_accept")

	# Given: The bound button was pressed and released on the action's device.
	input.send(_make_joy_button(0, JOY_BUTTON_Y))
	var release := _make_joy_button(0, JOY_BUTTON_Y)
	release.pressed = false
	input.send(release)

	# When: The helper is freed.
	input.free()

	# Then: The action isn't held.
	assert_false(Input.is_action_pressed(&"ui_accept"))


func test_send_free_ends_drag_in_progress() -> void:
	# Given: A drag in progress in a mounted scene.
	var scene := DragScene.new()
	var input := await StdTestInput.mount(self, scene)
	input.move_mouse(scene.source.get_global_rect().get_center())
	input.press_mouse()
	input.move_mouse(scene.target.get_global_rect().get_center(), _DRAG_DISTANCE)
	assert_true(get_viewport().gui_is_dragging(), "precondition: dragging")

	# When: The helper is freed.
	input.free()

	# Then: The drag ended.
	assert_false(get_viewport().gui_is_dragging())


func test_send_free_resets_held_joypad_axis(
	params = use_parameters(
		[
			1.0,
			# NOTE: This is below the value at which the event reports being pressed.
			0.25,
		]
	)
) -> void:
	# Given: A mounted scene.
	var input := await StdTestInput.mount(self, Control.new())

	# Given: A joypad axis is held.
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = params
	input.send(event)
	assert_eq(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), params, "precondition: axis held")

	# When: The helper is freed.
	input.free()

	# Then: The axis is back at rest.
	assert_eq(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), 0.0)


func test_send_released_input_is_not_released_again_at_free() -> void:
	# Given: A mounted scene recording unhandled input.
	var recorder := UnhandledInputRecorder.new()
	var input := await StdTestInput.mount(self, recorder)

	# Given: A key was pressed and released.
	input.press_key(KEY_ESCAPE)
	input.release_key(KEY_ESCAPE)
	var count_before := recorder.events.size()

	# When: The scene is taken out of the helper and the helper is freed.
	input.remove_child(recorder)
	add_child_autofree(recorder)
	input.free()

	# Then: No further key event arrived.
	var keys := recorder.events.filter(
		func(event: InputEvent) -> bool: return event is InputEventKey
	)
	assert_eq(keys.size(), count_before)


func test_send_released_touch_is_not_released_again_at_free() -> void:
	# Given: A mounted scene recording unhandled input.
	var recorder := UnhandledInputRecorder.new()
	var input := await StdTestInput.mount(self, recorder)

	# Given: A touch was pressed and released.
	var press := InputEventScreenTouch.new()
	press.pressed = true
	input.send(press)
	input.send(InputEventScreenTouch.new())
	assert_eq(_filter_touches(recorder.events).size(), 2, "precondition: touches seen")

	# When: The scene is taken out of the helper and the helper is freed.
	input.remove_child(recorder)
	add_child_autofree(recorder)
	input.free()

	# Then: No further touch arrived.
	assert_eq(_filter_touches(recorder.events).size(), 2)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	# NOTE: Other suites leave every action's bindings cleared, so bind this explicitly.
	_ui_accept_events = InputMap.action_get_events(&"ui_accept")
	InputMap.action_erase_events(&"ui_accept")

	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	InputMap.action_add_event(&"ui_accept", enter)


func after_each() -> void:
	InputMap.action_erase_events(&"ui_accept")
	for event in _ui_accept_events:
		InputMap.action_add_event(&"ui_accept", event)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _count_pressed returns an array which grows by one each time `button` is pressed.
func _count_pressed(button: BaseButton) -> Array[bool]:
	var pressed: Array[bool] = []
	button.pressed.connect(func() -> void: pressed.append(true))
	return pressed


## _filter_touches returns the touches among `events`.
func _filter_touches(events: Array[InputEvent]) -> Array[InputEvent]:
	return events.filter(
		func(event: InputEvent) -> bool: return event is InputEventScreenTouch
	)


func _make_button(position: Vector2) -> Button:
	var button := Button.new()
	button.position = position
	button.size = Vector2(100, 40)
	return button


func _make_joy_button(device: int, button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button_index
	event.pressed = true
	return event


## _record_gui_input returns an array which grows with the GUI input `control` receives.
func _record_gui_input(control: Control) -> Array[InputEvent]:
	var received: Array[InputEvent] = []
	control.gui_input.connect(func(event: InputEvent) -> void: received.append(event))
	return received
