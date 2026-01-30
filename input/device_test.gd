##
## Tests pertaining to the `StdInputDevice` class.
##

extends GutTest

# -- TEST METHODS -------------------------------------------------------------------- #


func test_get_device_category_returns_correct_category(
	params = use_parameters(
		[
			[StdInputDevice.DEVICE_TYPE_UNKNOWN, StdInputDevice.DEVICE_TYPE_UNKNOWN],
			[StdInputDevice.DEVICE_TYPE_KEYBOARD, StdInputDevice.DEVICE_TYPE_KEYBOARD],
			[StdInputDevice.DEVICE_TYPE_GENERIC, StdInputDevice.DEVICE_TYPE_GENERIC],
			[StdInputDevice.DEVICE_TYPE_PS_4, StdInputDevice.DEVICE_TYPE_GENERIC],
			[StdInputDevice.DEVICE_TYPE_PS_5, StdInputDevice.DEVICE_TYPE_GENERIC],
			[StdInputDevice.DEVICE_TYPE_XBOX_360, StdInputDevice.DEVICE_TYPE_GENERIC],
			[StdInputDevice.DEVICE_TYPE_XBOX_ONE, StdInputDevice.DEVICE_TYPE_GENERIC],
			[StdInputDevice.DEVICE_TYPE_SWITCH_PRO, StdInputDevice.DEVICE_TYPE_GENERIC],
			[StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_PAIR, StdInputDevice.DEVICE_TYPE_GENERIC],
			[StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_SINGLE, StdInputDevice.DEVICE_TYPE_GENERIC],
			[StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER, StdInputDevice.DEVICE_TYPE_GENERIC],
			[StdInputDevice.DEVICE_TYPE_STEAM_DECK, StdInputDevice.DEVICE_TYPE_GENERIC],
			[StdInputDevice.DEVICE_TYPE_TOUCH, StdInputDevice.DEVICE_TYPE_GENERIC],
		]
	),
) -> void:
	# Given: A device type and expected category.
	var device_type: StdInputDevice.DeviceType = params[0]
	var expected_category: StdInputDevice.DeviceType = params[1]

	# When: The device category is determined.
	var got := StdInputDevice.get_device_category(device_type)

	# Then: The correct category is returned.
	assert_eq(got, expected_category)


func test_is_matching_event_origin_matches_keyboard_events() -> void:
	# Given: A keyboard device.
	var device := _create_device(StdInputDevice.DEVICE_TYPE_KEYBOARD, 0)
	add_child_autofree(device)

	# Given: A key event from the same device.
	var key_event := InputEventKey.new()
	key_event.device = 0

	# When/Then: The keyboard event matches.
	assert_true(device.is_matching_event_origin(key_event))

	# Given: A mouse event from the same device.
	var mouse_event := InputEventMouseButton.new()
	mouse_event.device = 0

	# When/Then: The mouse event matches (keyboard includes mouse).
	assert_true(device.is_matching_event_origin(mouse_event))

	# Given: A joypad event.
	var joy_event := InputEventJoypadButton.new()
	joy_event.device = 0

	# When/Then: The joypad event does not match.
	assert_false(device.is_matching_event_origin(joy_event))


func test_is_matching_event_origin_matches_joypad_events() -> void:
	# Given: A joypad device.
	var device := _create_device(StdInputDevice.DEVICE_TYPE_GENERIC, 1)
	add_child_autofree(device)

	# Given: A joypad button event from the same device.
	var button_event := InputEventJoypadButton.new()
	button_event.device = 1

	# When/Then: The joypad button event matches.
	assert_true(device.is_matching_event_origin(button_event))

	# Given: A joypad motion event from the same device.
	var motion_event := InputEventJoypadMotion.new()
	motion_event.device = 1

	# When/Then: The joypad motion event matches.
	assert_true(device.is_matching_event_origin(motion_event))

	# Given: A joypad event from a different device.
	var other_event := InputEventJoypadButton.new()
	other_event.device = 2

	# When/Then: The event from a different device does not match.
	assert_false(device.is_matching_event_origin(other_event))


func test_is_matching_event_origin_matches_touch_events() -> void:
	# Given: A touch device.
	var device := _create_device(StdInputDevice.DEVICE_TYPE_TOUCH, 0)
	add_child_autofree(device)

	# Given: A screen touch event.
	var touch_event := InputEventScreenTouch.new()
	touch_event.device = 0

	# When/Then: The touch event matches.
	assert_true(device.is_matching_event_origin(touch_event))

	# Given: A screen drag event.
	var drag_event := InputEventScreenDrag.new()
	drag_event.device = 0

	# When/Then: The drag event matches.
	assert_true(device.is_matching_event_origin(drag_event))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_device(
	device_type: StdInputDevice.DeviceType,
	device_id: int,
) -> StdInputDevice:
	var device := StdInputDevice.new()
	device.device_type = device_type
	device.device_id = device_id

	# Add minimal required components.
	device.actions = StdInputDeviceActions.new()
	device.add_child(device.actions)

	device.glyphs = StdInputDeviceGlyphs.new()
	device.add_child(device.glyphs)

	device.haptics = StdInputDeviceHaptics.new()
	device.add_child(device.haptics)

	return device