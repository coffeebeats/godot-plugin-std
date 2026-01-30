##
## Tests pertaining to the `Origin` library.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Origin := preload("origin.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_encode_stores_input_event_key_correctly(
	params = use_parameters(
		[
			[KEY_UNKNOWN, KEY_LOCATION_UNSPECIFIED, true],
			[KEY_0, KEY_LOCATION_UNSPECIFIED, true],
			[KEY_DOWN, KEY_LOCATION_UNSPECIFIED, true],
			[KEY_W, KEY_LOCATION_UNSPECIFIED, true],
			[KEY_Q, KEY_LOCATION_UNSPECIFIED, false],
			[KEY_SHIFT, KEY_LOCATION_UNSPECIFIED, true],
			[KEY_SHIFT, KEY_LOCATION_UNSPECIFIED, false],
			[KEY_SHIFT, KEY_LOCATION_LEFT, true],
			[KEY_SHIFT, KEY_LOCATION_LEFT, false],
			[KEY_SHIFT, KEY_LOCATION_RIGHT, true],
			[KEY_SHIFT, KEY_LOCATION_RIGHT, false],
			[KEY_ESCAPE, KEY_LOCATION_RIGHT, false],
			[KEY_CTRL, KEY_LOCATION_UNSPECIFIED, true],
			[KEY_CTRL, KEY_LOCATION_LEFT, true],
			[KEY_CTRL, KEY_LOCATION_RIGHT, true],
		]
	),
) -> void:
	# Given: An input event to encode.
	var event := InputEventKey.new()
	event.location = params[1]
	if params[2]:
		event.physical_keycode = params[0]
	else:
		event.keycode = params[0]

	# Given: The event is encoded.
	var value_encoded: int = Origin.encode(event)

	# When: The encoded value is decoded.
	var got: InputEvent = Origin.decode(value_encoded)

	# Then: The decoded event is the right type.
	assert_not_null(got)
	assert_is(got, InputEventKey)

	# Then: The correct code is set on the event.
	assert_eq(got.physical_keycode, event.physical_keycode)
	assert_eq(got.location, event.location)


func test_encode_stores_input_event_joypad_motion_correctly(
	params = use_parameters(
		[
			[JOY_AXIS_LEFT_X, -1.0],
			[JOY_AXIS_LEFT_X, 0.0],
			[JOY_AXIS_LEFT_X, 1.0],
			[JOY_AXIS_LEFT_Y, -1.0],
			[JOY_AXIS_LEFT_Y, 0.0],
			[JOY_AXIS_LEFT_Y, 1.0],
			[JOY_AXIS_RIGHT_X, -1.0],
			[JOY_AXIS_RIGHT_X, 0.0],
			[JOY_AXIS_RIGHT_X, 1.0],
			[JOY_AXIS_RIGHT_Y, -1.0],
			[JOY_AXIS_RIGHT_Y, 0.0],
			[JOY_AXIS_RIGHT_Y, 1.0],
			[JOY_AXIS_TRIGGER_LEFT, -1.0],
			[JOY_AXIS_TRIGGER_LEFT, 0.0],
			[JOY_AXIS_TRIGGER_LEFT, 1.0],
			[JOY_AXIS_TRIGGER_RIGHT, -1.0],
			[JOY_AXIS_TRIGGER_RIGHT, 0.0],
			[JOY_AXIS_TRIGGER_RIGHT, 1.0],
		]
	),
) -> void:
	# Given: An input event to encode.
	var event := InputEventJoypadMotion.new()
	event.axis = params[0]
	event.axis_value = params[1]

	# Given: The event is encoded.
	var value_encoded: int = Origin.encode(event)

	# When: The encoded value is decoded.
	var got: InputEvent = Origin.decode(value_encoded)

	# Then: The decoded event is the right type.
	assert_not_null(got)
	assert_is(got, InputEventJoypadMotion)

	# Then: The correct code is set on the event.
	assert_eq(got.axis, event.axis)
	assert_eq(got.axis_value, event.axis_value)


func test_encode_stores_input_event_joypad_button_correctly(
	params = use_parameters(
		[
			[JOY_BUTTON_A],
			[JOY_BUTTON_DPAD_DOWN],
			[JOY_BUTTON_LEFT_STICK],
			[JOY_BUTTON_MAX],
		]
	),
) -> void:
	# Given: An input event to encode.
	var event := InputEventJoypadButton.new()
	event.button_index = params[0]

	# Given: The event is encoded.
	var value_encoded: int = Origin.encode(event)

	# When: The encoded value is decoded.
	var got: InputEvent = Origin.decode(value_encoded)

	# Then: The decoded event is the right type.
	assert_not_null(got)
	assert_is(got, InputEventJoypadButton)

	# Then: The correct code is set on the event.
	assert_eq(got.button_index, event.button_index)


func test_encode_stores_input_event_mouse_button_correctly(
	params = use_parameters(
		[
			[MOUSE_BUTTON_NONE],
			[MOUSE_BUTTON_LEFT],
			[MOUSE_BUTTON_RIGHT],
			[MOUSE_BUTTON_WHEEL_DOWN],
			[MOUSE_BUTTON_XBUTTON2],
		]
	),
) -> void:
	# Given: An input event to encode.
	var event := InputEventMouseButton.new()
	event.button_index = params[0]

	# Given: The event is encoded.
	var value_encoded: int = Origin.encode(event)

	# When: The encoded value is decoded.
	var got: InputEvent = Origin.decode(value_encoded)

	# Then: The decoded event is the right type.
	assert_not_null(got)
	assert_is(got, InputEventMouseButton)

	# Then: The correct code is set on the event.
	assert_eq(got.button_index, event.button_index)


func test_is_encoded_value_for_device_correctly_identifies_keyboard_events(
	params = use_parameters(
		[
			[KEY_A],
			[KEY_ESCAPE],
			[KEY_SHIFT],
		]
	),
) -> void:
	# Given: A keyboard input event.
	var event := InputEventKey.new()
	event.physical_keycode = params[0]

	# Given: The event is encoded.
	var value_encoded: int = Origin.encode(event)

	# When: The encoded value is checked for device type.
	var is_kbm := Origin.is_encoded_value_for_device(
		value_encoded, StdInputDevice.DEVICE_TYPE_KEYBOARD
	)
	var is_joy := Origin.is_encoded_value_for_device(
		value_encoded, StdInputDevice.DEVICE_TYPE_GENERIC
	)

	# Then: The value is correctly identified as keyboard input.
	assert_true(is_kbm)
	assert_false(is_joy)


func test_is_encoded_value_for_device_correctly_identifies_mouse_events(
	params = use_parameters(
		[
			[MOUSE_BUTTON_LEFT],
			[MOUSE_BUTTON_RIGHT],
		]
	),
) -> void:
	# Given: A mouse input event.
	var event := InputEventMouseButton.new()
	event.button_index = params[0]

	# Given: The event is encoded.
	var value_encoded: int = Origin.encode(event)

	# When: The encoded value is checked for device type.
	var is_kbm := Origin.is_encoded_value_for_device(
		value_encoded, StdInputDevice.DEVICE_TYPE_KEYBOARD
	)
	var is_joy := Origin.is_encoded_value_for_device(
		value_encoded, StdInputDevice.DEVICE_TYPE_GENERIC
	)

	# Then: The value is correctly identified as keyboard+mouse input.
	assert_true(is_kbm)
	assert_false(is_joy)


func test_is_encoded_value_for_device_correctly_identifies_joypad_button_events(
	params = use_parameters(
		[
			[JOY_BUTTON_A],
			[JOY_BUTTON_DPAD_DOWN],
		]
	),
) -> void:
	# Given: A joypad button input event.
	var event := InputEventJoypadButton.new()
	event.button_index = params[0]

	# Given: The event is encoded.
	var value_encoded: int = Origin.encode(event)

	# When: The encoded value is checked for device type.
	var is_kbm := Origin.is_encoded_value_for_device(
		value_encoded, StdInputDevice.DEVICE_TYPE_KEYBOARD
	)
	var is_joy := Origin.is_encoded_value_for_device(
		value_encoded, StdInputDevice.DEVICE_TYPE_GENERIC
	)

	# Then: The value is correctly identified as joypad input.
	assert_false(is_kbm)
	assert_true(is_joy)


func test_is_encoded_value_for_device_correctly_identifies_joypad_axis_events(
	params = use_parameters(
		[
			[JOY_AXIS_LEFT_X, -1.0],
			[JOY_AXIS_TRIGGER_RIGHT, 1.0],
		]
	),
) -> void:
	# Given: A joypad axis input event.
	var event := InputEventJoypadMotion.new()
	event.axis = params[0]
	event.axis_value = params[1]

	# Given: The event is encoded.
	var value_encoded: int = Origin.encode(event)

	# When: The encoded value is checked for device type.
	var is_kbm := Origin.is_encoded_value_for_device(
		value_encoded, StdInputDevice.DEVICE_TYPE_KEYBOARD
	)
	var is_joy := Origin.is_encoded_value_for_device(
		value_encoded, StdInputDevice.DEVICE_TYPE_GENERIC
	)

	# Then: The value is correctly identified as joypad input.
	assert_false(is_kbm)
	assert_true(is_joy)


func test_is_encoded_value_type_returns_false_for_negative_values() -> void:
	# Given: A negative encoded value.
	var value_encoded: int = -1

	# When: The value is checked against known indices.
	var is_kbm := Origin.is_encoded_value_type(
		value_encoded, Origin.bitmask_indices_kbm
	)
	var is_joy := Origin.is_encoded_value_type(
		value_encoded, Origin.bitmask_indices_joy
	)

	# Then: Both checks return false.
	assert_false(is_kbm)
	assert_false(is_joy)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
