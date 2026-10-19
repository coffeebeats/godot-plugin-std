##
## std/input/godot/device_glyphs_test.gd
##
## Tests pertaining to the Godot implementation of `StdInputDeviceGlyphs`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const DeviceGlyphs := preload("device_glyphs.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_ID_ALL := StdInputDevice.DEVICE_ID_ALL
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD

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


## _count returns the keyboard origin count of `action` in `action_set`.
func _count(action_set: StdInputActionSet, action: StringName) -> int:
	return _glyphs.get_action_origin_count(
		DEVICE_ID_ALL, DEVICE_TYPE_KEYBOARD, action_set, action
	)


## _make_action_set returns an action set declaring `actions`.
func _make_action_set(actions: Array[StringName]) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = &"Test"
	action_set.actions_digital = actions
	return action_set
