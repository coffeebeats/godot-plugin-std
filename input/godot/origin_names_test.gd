##
## std/input/godot/origin_names_test.gd
##
## Tests pertaining to the `StdInputOriginNames` resource.
##

extends GutTest

# -- TEST METHODS -------------------------------------------------------------------- #


func test_origin_names_key_resolves_a_joypad_button() -> void:
	# Given: Names with an entry for a joypad button.
	var names := StdInputOriginNames.new()
	names.joy_buttons = {JOY_BUTTON_A: &"test_button_a"}

	# Given: An event for that button.
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A

	# When: The event's key is resolved.
	var got := names.get_origin_name_key(event)

	# Then: The button's key is returned.
	assert_eq(got, &"test_button_a")


func test_origin_names_key_resolves_each_direction_of_an_axis() -> void:
	# Given: Names with an entry for each direction of a stick's vertical axis.
	var names := StdInputOriginNames.new()
	names.joy_axes_negative = {JOY_AXIS_LEFT_Y: &"test_left_stick_up"}
	names.joy_axes_positive = {JOY_AXIS_LEFT_Y: &"test_left_stick_down"}

	# When: An event for each direction is resolved.
	var got_negative := names.get_origin_name_key(_make_motion(JOY_AXIS_LEFT_Y, -1.0))
	var got_positive := names.get_origin_name_key(_make_motion(JOY_AXIS_LEFT_Y, 1.0))

	# Then: Each direction's own key is returned.
	assert_eq(got_negative, &"test_left_stick_up")
	assert_eq(got_positive, &"test_left_stick_down")


func test_origin_names_key_resolves_a_mouse_button() -> void:
	# Given: Names with an entry for a mouse button.
	var names := StdInputOriginNames.new()
	names.mouse_buttons = {MOUSE_BUTTON_LEFT: &"test_mouse_left"}

	# Given: An event for that button.
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT

	# When: The event's key is resolved.
	var got := names.get_origin_name_key(event)

	# Then: The button's key is returned.
	assert_eq(got, &"test_mouse_left")


func test_origin_names_key_resolves_a_physical_key() -> void:
	# Given: Names with an entry for a key.
	var names := StdInputOriginNames.new()
	names.keyboard_keys = {KEY_ENTER: &"test_key_enter"}

	# Given: An event for that physical key.
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER

	# When: The event's key is resolved.
	var got := names.get_origin_name_key(event)

	# Then: The key's translation key is returned.
	assert_eq(got, &"test_key_enter")


func test_origin_names_key_resolves_a_keycode_only_key() -> void:
	# Given: Names with an entry for a key.
	var names := StdInputOriginNames.new()
	names.keyboard_keys = {KEY_ENTER: &"test_key_enter"}

	# Given: An event naming that key by keycode alone, as project settings do.
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER

	# When: The event's key is resolved.
	var got := names.get_origin_name_key(event)

	# Then: The key's translation key is returned.
	assert_eq(got, &"test_key_enter")


func test_origin_names_key_returns_empty_without_an_entry() -> void:
	# Given: Names with an entry for one joypad button.
	var names := StdInputOriginNames.new()
	names.joy_buttons = {JOY_BUTTON_A: &"test_button_a"}

	# Given: An event for another button.
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_B

	# When: The event's key is resolved.
	var got := names.get_origin_name_key(event)

	# Then: No key is returned.
	assert_eq(got, &"")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _make_motion returns a joypad motion event on `axis` at `value`.
func _make_motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event
