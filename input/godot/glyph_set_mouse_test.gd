##
## std/input/godot/glyph_set_mouse_test.gd
##
## Tests pertaining to the `StdInputGlyphSetMouse` class.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

## _PROPERTIES maps each mouse button to the glyph set property holding its texture.
const _PROPERTIES := {
	MOUSE_BUTTON_LEFT: &"button_left",
	MOUSE_BUTTON_RIGHT: &"button_right",
	MOUSE_BUTTON_MIDDLE: &"button_middle",
	MOUSE_BUTTON_WHEEL_UP: &"button_wheel_up",
	MOUSE_BUTTON_WHEEL_DOWN: &"button_wheel_down",
	MOUSE_BUTTON_WHEEL_LEFT: &"button_wheel_left",
	MOUSE_BUTTON_WHEEL_RIGHT: &"button_wheel_right",
	MOUSE_BUTTON_XBUTTON1: &"button_side_1",
	MOUSE_BUTTON_XBUTTON2: &"button_side_2",
}

# -- TEST METHODS -------------------------------------------------------------------- #


func test_glyph_set_mouse_origin_glyph_returns_each_buttons_own_texture() -> void:
	# Given: A mouse glyph set with a distinct texture per button.
	var glyph_set := StdInputGlyphSetMouse.new()
	glyph_set.device_types = [StdInputDevice.DEVICE_TYPE_KEYBOARD]

	for button in _PROPERTIES:
		glyph_set.set(_PROPERTIES[button], PlaceholderTexture2D.new())

	for button in _PROPERTIES:
		# Given: A binding to the button.
		var event := InputEventMouseButton.new()
		event.button_index = button

		# When: The glyph is fetched for the binding.
		var got := glyph_set.get_origin_glyph(event)

		# Then: The button's own texture is returned.
		assert_eq(got, glyph_set.get(_PROPERTIES[button]), _PROPERTIES[button])
