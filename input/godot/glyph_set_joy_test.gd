##
## std/input/godot/glyph_set_joy_test.gd
##
## Tests pertaining to the `StdInputGlyphSetJoy` class.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

## _BUTTONS maps each joypad button to the glyph set property holding its texture.
const _BUTTONS := {
	JOY_BUTTON_A: &"button_a",
	JOY_BUTTON_B: &"button_b",
	JOY_BUTTON_X: &"button_x",
	JOY_BUTTON_Y: &"button_y",
	JOY_BUTTON_BACK: &"button_back",
	JOY_BUTTON_GUIDE: &"button_guide",
	JOY_BUTTON_START: &"button_start",
	JOY_BUTTON_LEFT_STICK: &"button_stick_left",
	JOY_BUTTON_RIGHT_STICK: &"button_stick_right",
	JOY_BUTTON_LEFT_SHOULDER: &"button_shoulder_left",
	JOY_BUTTON_RIGHT_SHOULDER: &"button_shoulder_right",
	JOY_BUTTON_DPAD_UP: &"button_dpad_up",
	JOY_BUTTON_DPAD_DOWN: &"button_dpad_down",
	JOY_BUTTON_DPAD_LEFT: &"button_dpad_left",
	JOY_BUTTON_DPAD_RIGHT: &"button_dpad_right",
	JOY_BUTTON_MISC1: &"button_misc",
	JOY_BUTTON_PADDLE1: &"button_paddle_1",
	JOY_BUTTON_PADDLE2: &"button_paddle_2",
	JOY_BUTTON_PADDLE3: &"button_paddle_3",
	JOY_BUTTON_PADDLE4: &"button_paddle_4",
	JOY_BUTTON_TOUCHPAD: &"button_touchpad",
}

## _MOTIONS maps each joypad axis and direction to the glyph set property holding its
## texture.
const _MOTIONS := {
	[JOY_AXIS_LEFT_X, -1.0]: &"stick_left_direction_left",
	[JOY_AXIS_LEFT_X, 1.0]: &"stick_left_direction_right",
	[JOY_AXIS_LEFT_Y, -1.0]: &"stick_left_direction_up",
	[JOY_AXIS_LEFT_Y, 1.0]: &"stick_left_direction_down",
	[JOY_AXIS_RIGHT_X, -1.0]: &"stick_right_direction_left",
	[JOY_AXIS_RIGHT_X, 1.0]: &"stick_right_direction_right",
	[JOY_AXIS_RIGHT_Y, -1.0]: &"stick_right_direction_up",
	[JOY_AXIS_RIGHT_Y, 1.0]: &"stick_right_direction_down",
	[JOY_AXIS_TRIGGER_LEFT, 1.0]: &"analog_trigger_left",
	[JOY_AXIS_TRIGGER_RIGHT, 1.0]: &"analog_trigger_right",
}

# -- INITIALIZATION ------------------------------------------------------------------ #

var _glyph_set: StdInputGlyphSetJoy = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_glyph_set_joy_origin_glyph_returns_each_buttons_own_texture() -> void:
	for button in _BUTTONS:
		# Given: A binding to the button.
		var event := InputEventJoypadButton.new()
		event.button_index = button

		# When: The glyph is fetched for the binding.
		var got := _glyph_set.get_origin_glyph(event)

		# Then: The button's own texture is returned.
		assert_eq(got, _glyph_set.get(_BUTTONS[button]), _BUTTONS[button])


func test_glyph_set_joy_origin_glyph_returns_each_directions_own_texture() -> void:
	for motion in _MOTIONS:
		# Given: A binding to the axis direction.
		var event := InputEventJoypadMotion.new()
		event.axis = motion[0]
		event.axis_value = motion[1]

		# When: The glyph is fetched for the binding.
		var got := _glyph_set.get_origin_glyph(event)

		# Then: The direction's own texture is returned.
		assert_eq(got, _glyph_set.get(_MOTIONS[motion]), _MOTIONS[motion])


func test_glyph_set_joy_origin_textures_each_have_a_test_origin() -> void:
	# Given: Every origin texture property the glyph set declares.
	var properties: Array[StringName] = []
	for property in _glyph_set.get_script().get_script_property_list():
		if (
			property["hint_string"] == "Texture2D"
			and property["name"] != "unknown_glyph"
		):
			properties.append(property["name"])

	# Then: Each is mapped from an origin in `_BUTTONS` or `_MOTIONS`.
	var tested: Array = _BUTTONS.values() + _MOTIONS.values()
	for property in properties:
		assert_has(tested, property)

	# Then: The maps name no property the set lacks.
	assert_eq(tested.size(), properties.size())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_glyph_set = StdInputGlyphSetJoy.new()
	_glyph_set.device_types = [StdInputDevice.DEVICE_TYPE_GENERIC]

	for property in _BUTTONS.values() + _MOTIONS.values():
		_glyph_set.set(property, PlaceholderTexture2D.new())
