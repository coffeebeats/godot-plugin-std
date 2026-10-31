##
## std/input/godot/device_glyphs_test.gd
##
## Tests pertaining to the Godot implementation of `StdInputDeviceGlyphs`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Bindings := preload("binding.gd")
const DeviceGlyphs := preload("device_glyphs.gd")
const Origin := preload("origin.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_ID_ALL := StdInputDevice.DEVICE_ID_ALL
const DEVICE_TYPE_GENERIC := StdInputDevice.DEVICE_TYPE_GENERIC
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD
const DEVICE_TYPE_PS_5 := StdInputDevice.DEVICE_TYPE_PS_5
const DEVICE_TYPE_SWITCH_PRO := StdInputDevice.DEVICE_TYPE_SWITCH_PRO
const DEVICE_TYPE_TOUCH := StdInputDevice.DEVICE_TYPE_TOUCH
const DEVICE_TYPE_XBOX_ONE := StdInputDevice.DEVICE_TYPE_XBOX_ONE

## _DEFAULTS maps each test action to the keys it is bound to by default, in binding
## index order.
const _DEFAULTS := {
	&"test_glyph_one": [KEY_A],
	&"test_glyph_two": [KEY_A, KEY_B],
	&"test_glyph_repeated": [KEY_A, KEY_A, KEY_B],
}

# -- INITIALIZATION ------------------------------------------------------------------ #

var _glyphs: StdInputDeviceGlyphs = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_device_glyphs_origin_count_counts_each_bound_index() -> void:
	# Given: An action set declaring actions bound to one and two keys.
	var action_set := _make_action_set([&"test_glyph_one", &"test_glyph_two"])

	# When: The origins of each action are counted for the keyboard.
	var got_one := _count(action_set, &"test_glyph_one")
	var got_two := _count(action_set, &"test_glyph_two")

	# Then: Each bound index is counted.
	assert_eq(got_one, 1)
	assert_eq(got_two, 2)


func test_device_glyphs_origin_count_stops_at_a_repeated_binding() -> void:
	# Given: An action set declaring an action whose second binding repeats its first.
	var action_set := _make_action_set([&"test_glyph_repeated"])

	# When: The origins of the action are counted for the keyboard.
	var got := _count(action_set, &"test_glyph_repeated")

	# Then: Only the distinct origin before the repeat is counted.
	assert_eq(got, 1)


func test_device_glyphs_origin_label_generic_pad_returns_generic_names() -> void:
	# Given: A joypad action bound to each of a set of origins.
	var cases := {
		_button(JOY_BUTTON_A): "A",
		_button(JOY_BUTTON_START): "Start",
		_button(JOY_BUTTON_LEFT_STICK): "LS",
		_button(JOY_BUTTON_RIGHT_SHOULDER): "RB",
		_button(JOY_BUTTON_DPAD_LEFT): "D-pad Left",
		_motion(JOY_AXIS_TRIGGER_LEFT, 1.0): "LT",
	}

	for event in cases:
		# When: The label is fetched for a generic pad.
		var got := _label(event, DEVICE_TYPE_GENERIC)

		# Then: The origin's generic name is returned.
		assert_eq(got, cases[event])


func test_device_glyphs_origin_label_playstation_pad_returns_sony_names() -> void:
	# Given: A joypad action bound to each of a set of origins.
	var cases := {
		_button(JOY_BUTTON_A): "Cross",
		_button(JOY_BUTTON_Y): "Triangle",
		_button(JOY_BUTTON_BACK): "Create",
		_button(JOY_BUTTON_LEFT_STICK): "L3",
		_button(JOY_BUTTON_RIGHT_SHOULDER): "R1",
		_button(JOY_BUTTON_DPAD_UP): "D-pad Up",
		_motion(JOY_AXIS_TRIGGER_LEFT, 1.0): "L2",
	}

	for event in cases:
		# When: The label is fetched for a PlayStation pad.
		var got := _label(event, DEVICE_TYPE_PS_5)

		# Then: Sony's name for the origin is returned.
		assert_eq(got, cases[event])


func test_device_glyphs_origin_label_switch_pad_returns_nintendo_names() -> void:
	# Given: A joypad action bound to each of a set of origins.
	var cases := {
		_button(JOY_BUTTON_A): "B",
		_button(JOY_BUTTON_B): "A",
		_button(JOY_BUTTON_BACK): "−",
		_button(JOY_BUTTON_START): "+",
		_button(JOY_BUTTON_LEFT_SHOULDER): "L",
		_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0): "ZR",
	}

	for event in cases:
		# When: The label is fetched for a Switch pad.
		var got := _label(event, DEVICE_TYPE_SWITCH_PRO)

		# Then: Nintendo's name for the origin is returned.
		assert_eq(got, cases[event])


func test_device_glyphs_origin_label_xbox_pad_returns_certified_names() -> void:
	# Given: A joypad action bound to each of a set of origins.
	var cases := {
		_button(JOY_BUTTON_A): "A",
		_button(JOY_BUTTON_BACK): "View",
		_button(JOY_BUTTON_START): "Menu",
		_button(JOY_BUTTON_LEFT_SHOULDER): "LB",
		_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0): "RT",
	}

	for event in cases:
		# When: The label is fetched for an Xbox pad.
		var got := _label(event, DEVICE_TYPE_XBOX_ONE)

		# Then: The name Xbox certification requires is returned.
		assert_eq(got, cases[event])


func test_device_glyphs_origin_label_stick_motion_names_stick_and_direction() -> void:
	# Given: A joypad action bound to each direction of a stick.
	var cases := {
		_motion(JOY_AXIS_LEFT_X, -1.0): "Left Stick Left",
		_motion(JOY_AXIS_LEFT_X, 1.0): "Left Stick Right",
		_motion(JOY_AXIS_RIGHT_Y, -1.0): "Right Stick Up",
		_motion(JOY_AXIS_RIGHT_Y, 1.0): "Right Stick Down",
		_motion(JOY_AXIS_RIGHT_Y, 0.0): "Right Stick",
	}

	for event in cases:
		# When: The label is fetched for a pad.
		var got := _label(event, DEVICE_TYPE_PS_5)

		# Then: The stick and the direction are named.
		assert_eq(got, cases[event])


func test_device_glyphs_origin_label_unbound_joypad_action_returns_empty() -> void:
	# Given: An action set declaring an action with no joypad binding.
	var action_set := _make_action_set([&"test_glyph_one"])

	# When: The label is fetched for a generic pad.
	var got := _glyphs.get_action_origin_label(
		DEVICE_ID_ALL, DEVICE_TYPE_GENERIC, action_set, &"test_glyph_one"
	)

	# Then: There is no name to return.
	assert_eq(got, "")


func test_device_glyphs_origin_label_touch_device_returns_empty() -> void:
	# Given: A joypad action bound to a button.
	var event := _button(JOY_BUTTON_A)

	# When: The label is fetched for a touchscreen.
	var got := _label(event, DEVICE_TYPE_TOUCH)

	# Then: There is no name to return.
	assert_eq(got, "")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _DEFAULTS:
		InputMap.erase_action(action)
		ProjectSettings.set_setting(&"input/" + action, null)


func before_all() -> void:
	for action in _DEFAULTS:
		InputMap.add_action(action)

		var events: Array[InputEvent] = []
		for key in _DEFAULTS[action]:
			var event := InputEventKey.new()
			event.keycode = key
			events.append(event)

		ProjectSettings.set_setting(
			&"input/" + action, {"deadzone": 0.5, "events": events}
		)


func before_each() -> void:
	var scope := StdSettingsScope.new()
	scope.is_loaded = true

	_glyphs = DeviceGlyphs.new()
	_glyphs.scope = scope
	add_child_autofree(_glyphs)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _button returns a binding to a joypad button.
func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


## _count returns the keyboard origin count of `action` in `action_set`.
func _count(action_set: StdInputActionSet, action: StringName) -> int:
	return _glyphs.get_action_origin_count(
		DEVICE_ID_ALL, DEVICE_TYPE_KEYBOARD, action_set, action
	)


## _label returns the label `device_type` gives an action stored as bound to `event`.
func _label(event: InputEvent, device_type: StdInputDevice.DeviceType) -> String:
	var action_set := _make_action_set([&"test_glyph_one"])

	(
		_glyphs
		. scope
		. config
		. set_int(
			Bindings.get_action_set_category(action_set, DEVICE_TYPE_GENERIC),
			Bindings.get_action_key(
				&"test_glyph_one", StdInputDeviceActions.BINDING_INDEX_PRIMARY
			),
			Origin.encode(event),
		)
	)

	return _glyphs.get_action_origin_label(
		DEVICE_ID_ALL, device_type, action_set, &"test_glyph_one"
	)


## _make_action_set returns an action set declaring `actions`.
func _make_action_set(actions: Array[StringName]) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = &"Test"
	action_set.actions_digital = actions
	return action_set


## _motion returns a binding to one direction of a joypad axis.
func _motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event
