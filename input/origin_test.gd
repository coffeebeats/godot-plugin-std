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
			[KEY_NONE],
			[KEY_UNKNOWN],
			[KEY_0],
			[KEY_DOWN],
			[KEY_W],
		]
	),
) -> void:
	# Given: An input event to encode.
	var event := InputEventKey.new()
	event.keycode = params[0]

	# Given: The event is encoded.
	var value_encoded: int = Origin.encode(event)

	# When: The encoded value is decoded.
	var got: InputEvent = Origin.decode(value_encoded)

	# Then: The decoded event is the right type.
	assert_not_null(got)
	assert_is(got, InputEventKey)

	# Then: The correct code is set on the event.
	assert_eq(got.keycode, event.keycode)


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


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
