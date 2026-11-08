# gdlint:ignore=max-public-methods
##
## std/input/godot/device_glyphs_test.gd
##
## Tests pertaining to the Godot implementation of `StdInputDeviceGlyphs`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Bindings := preload("binding.gd")
const DeviceGlyphs := preload("device_glyphs.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_ID_ALL := StdInputDevice.DEVICE_ID_ALL
const DEVICE_TYPE_GENERIC := StdInputDevice.DEVICE_TYPE_GENERIC
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD
const DEVICE_TYPE_PS_5 := StdInputDevice.DEVICE_TYPE_PS_5
const DEVICE_TYPE_XBOX_ONE := StdInputDevice.DEVICE_TYPE_XBOX_ONE

## _MESSAGES maps each translation key the tests name origins with to its translation.
const _MESSAGES := {
	&"test_origin_a_button": "A Button",
	&"test_origin_circle": "Circle",
	&"test_origin_cross": "Cross",
	&"test_origin_left_click": "Left Click",
	&"test_origin_named_key": "Named Key",
}

## _CONTEXT_MESSAGES maps each translation context the tests name origins in to its
## keys and their translations in that context.
const _CONTEXT_MESSAGES := {
	&"test_playstation": {&"test_origin_share": "PlayStation Share"},
	&"test_xbox": {&"test_origin_share": "Xbox Share"},
}

## _DEFAULTS maps each test action to the keys it is bound to by default, in binding
## index order.
const _DEFAULTS := {
	&"test_glyph_one": [KEY_A],
	&"test_glyph_two": [KEY_A, KEY_B],
	&"test_glyph_repeated": [KEY_A, KEY_A, KEY_B],
}

## _JOY_DEFAULTS maps each joypad test action to the buttons it is bound to by default,
## in binding index order.
const _JOY_DEFAULTS := {
	&"test_glyph_joy": [JOY_BUTTON_A, JOY_BUTTON_B],
}

## _MOUSE_DEFAULTS maps each mouse test action to the buttons it is bound to by default,
## in binding index order.
const _MOUSE_DEFAULTS := {
	&"test_glyph_mouse": [MOUSE_BUTTON_LEFT],
}


## SizedGlyphSet is a glyph set which records each size a glyph is asked for.
class SizedGlyphSet:
	extends StdInputGlyphSet

	## target_sizes holds each size a glyph was asked for, in call order.
	var target_sizes: Array[Vector2] = []

	func _get_origin_glyph(_event: InputEvent, target_size: Vector2) -> Texture2D:
		target_sizes.append(target_size)
		return PlaceholderTexture2D.new()


# -- INITIALIZATION ------------------------------------------------------------------ #

## _glyphs is the provider under test.
var _glyphs: DeviceGlyphs = null

## _translation holds `_MESSAGES` and `_CONTEXT_MESSAGES` while the tests run.
var _translation: Translation = null

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


func test_device_glyphs_glyph_returns_the_matching_sets_art() -> void:
	# Given: A set for the joypad type with art for the bound button.
	var glyph_set := _make_joy_set([DEVICE_TYPE_XBOX_ONE], &"button_a")
	_glyphs.glyph_sets = [glyph_set]

	# When: The glyph is fetched for the joypad type.
	var got := _glyph(DEVICE_TYPE_XBOX_ONE)

	# Then: The set's art is returned.
	assert_eq(got, glyph_set.button_a)


func test_device_glyphs_glyph_uses_the_generic_set_when_no_set_matches() -> void:
	# Given: A generic set with art for the bound button, and none for the joypad type.
	var glyph_set := _make_joy_set([DEVICE_TYPE_GENERIC], &"button_a")
	_glyphs.glyph_sets = [glyph_set]

	# When: The glyph is fetched for the joypad type.
	var got := _glyph(DEVICE_TYPE_PS_5)

	# Then: The generic set's art is returned.
	assert_eq(got, glyph_set.button_a)


func test_device_glyphs_glyph_skips_the_generic_set_for_a_matched_set() -> void:
	# Given: A set for the joypad type lacking art for the bound button.
	var matched := _make_joy_set([DEVICE_TYPE_XBOX_ONE], &"button_x")

	# Given: A generic set with art for the bound button.
	var generic := _make_joy_set([DEVICE_TYPE_GENERIC], &"button_a")
	_glyphs.glyph_sets = [matched, generic]

	# When: The glyph is fetched for the joypad type.
	var got := _glyph(DEVICE_TYPE_XBOX_ONE)

	# Then: The provider's unknown glyph is returned rather than the generic art.
	assert_eq(got, _glyphs.unknown_glyph)


func test_device_glyphs_glyph_returns_a_sets_unknown_glyph_without_art() -> void:
	# Given: A set for the joypad type lacking art for the bound button.
	var first := _make_joy_set([DEVICE_TYPE_XBOX_ONE], &"button_x")

	# Given: A second set for the joypad type with an unknown glyph and no art for it.
	var second := _make_joy_set([DEVICE_TYPE_XBOX_ONE], &"button_y")
	second.unknown_glyph = PlaceholderTexture2D.new()
	_glyphs.glyph_sets = [first, second]

	# When: The glyph is fetched for the joypad type.
	var got := _glyph(DEVICE_TYPE_XBOX_ONE)

	# Then: The set's unknown glyph is returned.
	assert_eq(got, second.unknown_glyph)


func test_device_glyphs_glyph_returns_the_unknown_glyph_without_set_art() -> void:
	# Given: A set for the joypad type lacking art for the bound button.
	_glyphs.glyph_sets = [_make_joy_set([DEVICE_TYPE_XBOX_ONE], &"button_x")]

	# When: The glyph is fetched for the joypad type.
	var got := _glyph(DEVICE_TYPE_XBOX_ONE)

	# Then: The provider's unknown glyph is returned.
	assert_eq(got, _glyphs.unknown_glyph)


func test_device_glyphs_glyph_returns_null_without_an_unknown_glyph() -> void:
	# Given: A set for the joypad type lacking art for the bound button.
	_glyphs.glyph_sets = [_make_joy_set([DEVICE_TYPE_XBOX_ONE], &"button_x")]

	# Given: No unknown glyph on the provider.
	_glyphs.unknown_glyph = null

	# When: The glyph is fetched for the joypad type.
	var got := _glyph(DEVICE_TYPE_XBOX_ONE)

	# Then: No glyph is returned.
	assert_null(got)


func test_device_glyphs_glyph_skips_the_generic_set_for_the_keyboard() -> void:
	# Given: A generic set with an unknown glyph, and none for the keyboard.
	var generic := _make_joy_set([DEVICE_TYPE_GENERIC], &"button_a")
	generic.unknown_glyph = PlaceholderTexture2D.new()
	_glyphs.glyph_sets = [generic]

	# Given: An action set declaring an action bound to a key.
	var action_set := _make_action_set([&"test_glyph_one"])

	# When: The glyph is fetched for the keyboard.
	var got := _glyphs.get_action_glyph(
		DEVICE_ID_ALL, DEVICE_TYPE_KEYBOARD, action_set, &"test_glyph_one"
	)

	# Then: The provider's unknown glyph is returned, not the generic set's.
	assert_eq(got, _glyphs.unknown_glyph)


func test_device_glyphs_glyph_returns_null_for_an_unbound_action() -> void:
	# Given: A set for the joypad type with art for the button the test binds.
	_glyphs.glyph_sets = [_make_joy_set([DEVICE_TYPE_XBOX_ONE], &"button_a")]

	# Given: An action set declaring an action bound to no joypad origin.
	var action_set := _make_action_set([&"test_glyph_one"])

	# When: The glyph is fetched for the joypad type.
	var got := _glyphs.get_action_glyph(
		DEVICE_ID_ALL, DEVICE_TYPE_XBOX_ONE, action_set, &"test_glyph_one"
	)

	# Then: No glyph is returned.
	assert_null(got)


func test_device_glyphs_glyph_returns_the_unknown_glyph_for_a_lone_secondary() -> void:
	# Given: A set for the joypad type lacking art for the bound button.
	_glyphs.glyph_sets = [_make_joy_set([DEVICE_TYPE_XBOX_ONE], &"button_x")]

	# Given: An action set declaring a joypad action.
	var action_set := _make_action_set([&"test_glyph_joy"])

	# Given: The primary button rebound to the secondary index, unbinding the primary.
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	(
		Bindings
		. bind_action(
			_glyphs.scope,
			action_set,
			&"test_glyph_joy",
			event,
			DEVICE_TYPE_GENERIC,
			StdInputDeviceActions.BINDING_INDEX_SECONDARY,
		)
	)

	# When: The secondary glyph is fetched for the joypad type.
	var got := (
		_glyphs
		. get_action_glyph(
			DEVICE_ID_ALL,
			DEVICE_TYPE_XBOX_ONE,
			action_set,
			&"test_glyph_joy",
			StdInputDeviceActions.BINDING_INDEX_SECONDARY,
		)
	)

	# Then: The provider's unknown glyph is returned.
	assert_eq(got, _glyphs.unknown_glyph)


func test_device_glyphs_glyph_asks_the_set_for_the_target_size() -> void:
	# Given: A set for the joypad type which records the size it is asked for.
	var glyph_set := SizedGlyphSet.new()
	glyph_set.device_types = [DEVICE_TYPE_XBOX_ONE]
	_glyphs.glyph_sets = [glyph_set]

	# When: The glyph is fetched for a host drawing it at 48 by 48.
	(
		_glyphs
		. get_action_glyph(
			DEVICE_ID_ALL,
			DEVICE_TYPE_XBOX_ONE,
			_make_action_set([&"test_glyph_joy"]),
			&"test_glyph_joy",
			StdInputDeviceActions.BINDING_INDEX_PRIMARY,
			Vector2(48, 48),
		)
	)

	# Then: The set is asked for the glyph at that size.
	assert_eq(glyph_set.target_sizes, [Vector2(48, 48)] as Array[Vector2])


func test_device_glyphs_label_translates_a_joypad_origins_name() -> void:
	# Given: Names for the joypad type with an entry for the bound button.
	_glyphs.origin_names = [_make_names([DEVICE_TYPE_PS_5], &"test_origin_cross")]

	# When: The label is fetched for the joypad type.
	var got := _label(DEVICE_TYPE_PS_5)

	# Then: The entry's translation is returned.
	assert_eq(got, "Cross")


func test_device_glyphs_label_takes_each_origin_from_the_first_names_with_it() -> void:
	# Given: Names for the joypad type with an entry for the secondary button alone.
	var specific := StdInputOriginNames.new()
	specific.device_types = [DEVICE_TYPE_PS_5]
	specific.joy_buttons = {JOY_BUTTON_B: &"test_origin_circle"}

	# Given: Later names for the joypad type with entries for both buttons.
	var general := StdInputOriginNames.new()
	general.device_types = [DEVICE_TYPE_PS_5]
	general.joy_buttons = {
		JOY_BUTTON_A: &"test_origin_cross",
		JOY_BUTTON_B: &"test_origin_a_button",
	}
	_glyphs.origin_names = [specific, general]

	# When: The label of each binding is fetched for the joypad type.
	var got_primary := _label(DEVICE_TYPE_PS_5)
	var got_secondary := _label(
		DEVICE_TYPE_PS_5,
		&"test_glyph_joy",
		StdInputDeviceActions.BINDING_INDEX_SECONDARY,
	)

	# Then: Each origin is named by the first names with an entry for it.
	assert_eq(got_primary, "Cross")
	assert_eq(got_secondary, "Circle")


func test_device_glyphs_label_uses_the_names_matching_the_device_type() -> void:
	# Given: Names for two joypad types, each naming the bound button differently.
	_glyphs.origin_names = [
		_make_names([DEVICE_TYPE_XBOX_ONE], &"test_origin_a_button"),
		_make_names([DEVICE_TYPE_PS_5], &"test_origin_cross"),
	]

	# When: The label is fetched for each joypad type.
	var got_xbox := _label(DEVICE_TYPE_XBOX_ONE)
	var got_playstation := _label(DEVICE_TYPE_PS_5)

	# Then: Each joypad type is named by its own names.
	assert_eq(got_xbox, "A Button")
	assert_eq(got_playstation, "Cross")


func test_device_glyphs_label_uses_the_generic_names_when_none_match() -> void:
	# Given: Generic names with an entry for the bound button, and none for the type.
	_glyphs.origin_names = [_make_names([DEVICE_TYPE_GENERIC], &"test_origin_a_button")]

	# When: The label is fetched for the joypad type.
	var got := _label(DEVICE_TYPE_PS_5)

	# Then: The generic entry's translation is returned.
	assert_eq(got, "A Button")


func test_device_glyphs_label_translates_a_key_in_its_names_context() -> void:
	# Given: Names for two joypad types sharing a key, each in its own context.
	var xbox := _make_names([DEVICE_TYPE_XBOX_ONE], &"test_origin_share")
	xbox.translation_context = &"test_xbox"
	var playstation := _make_names([DEVICE_TYPE_PS_5], &"test_origin_share")
	playstation.translation_context = &"test_playstation"
	_glyphs.origin_names = [xbox, playstation]

	# When: The label is fetched for each joypad type.
	var got_xbox := _label(DEVICE_TYPE_XBOX_ONE)
	var got_playstation := _label(DEVICE_TYPE_PS_5)

	# Then: Each joypad type's key is translated in its names' context.
	assert_eq(got_xbox, "Xbox Share")
	assert_eq(got_playstation, "PlayStation Share")


func test_device_glyphs_label_returns_empty_for_a_joypad_origin_without_one() -> void:
	# Given: Names for the joypad type with no entry for the bound button.
	var names := StdInputOriginNames.new()
	names.device_types = [DEVICE_TYPE_PS_5]
	names.joy_buttons = {JOY_BUTTON_Y: &"test_origin_cross"}
	_glyphs.origin_names = [names]

	# When: The label is fetched for the joypad type.
	var got := _label(DEVICE_TYPE_PS_5)

	# Then: No label is returned.
	assert_eq(got, "")


func test_device_glyphs_label_reports_an_untranslated_name() -> void:
	# Given: Names for the joypad type with an untranslated entry for the bound button.
	var names := _make_names([DEVICE_TYPE_PS_5], &"test_origin_untranslated")
	names.translation_context = &"test_context"
	_glyphs.origin_names = [names]

	# When: The label is fetched for the joypad type.
	var got := _label(DEVICE_TYPE_PS_5)

	# Then: The untranslated key is reported with the context it was looked up in.
	assert_engine_error(
		"untranslated origin name: test_origin_untranslated (context: 'test_context')"
	)

	# Then: The raw key is not returned.
	assert_ne(got, "test_origin_untranslated")


func test_device_glyphs_label_translates_a_mouse_buttons_name() -> void:
	# Given: Names for the keyboard with an entry for the bound mouse button.
	var names := StdInputOriginNames.new()
	names.device_types = [DEVICE_TYPE_KEYBOARD]
	names.mouse_buttons = {MOUSE_BUTTON_LEFT: &"test_origin_left_click"}
	_glyphs.origin_names = [names]

	# When: The label of an action bound to the mouse button is fetched.
	var got := _label(DEVICE_TYPE_KEYBOARD, &"test_glyph_mouse")

	# Then: The entry's translation is returned.
	assert_eq(got, "Left Click")


func test_device_glyphs_label_returns_empty_for_a_mouse_button_without_one() -> void:
	# Given: No origin names on the provider.
	_glyphs.origin_names = []

	# When: The label of an action bound to a mouse button is fetched.
	var got := _label(DEVICE_TYPE_KEYBOARD, &"test_glyph_mouse")

	# Then: No label is returned.
	assert_eq(got, "")


func test_device_glyphs_label_keeps_a_keys_label_without_a_name() -> void:
	# Given: Names for the keyboard with no entry for the bound key.
	var names := StdInputOriginNames.new()
	names.device_types = [DEVICE_TYPE_KEYBOARD]
	names.keyboard_keys = {KEY_ENTER: &"test_origin_named_key"}
	_glyphs.origin_names = [names]

	# When: The label of an action bound to a key is fetched.
	var got := _label(DEVICE_TYPE_KEYBOARD, &"test_glyph_one")

	# Then: The key's own label is returned.
	assert_eq(got, "A")


func test_device_glyphs_label_prefers_a_keys_name_over_its_label() -> void:
	# Given: Names for the keyboard with an entry for the bound key.
	var names := StdInputOriginNames.new()
	names.device_types = [DEVICE_TYPE_KEYBOARD]
	names.keyboard_keys = {KEY_A: &"test_origin_named_key"}
	_glyphs.origin_names = [names]

	# When: The label of an action bound to the key is fetched.
	var got := _label(DEVICE_TYPE_KEYBOARD, &"test_glyph_one")

	# Then: The entry's translation is returned.
	assert_eq(got, "Named Key")


func test_device_glyphs_label_uses_the_override_device_types_names() -> void:
	# Given: Names for two joypad types, each naming the bound button differently.
	_glyphs.origin_names = [
		_make_names([DEVICE_TYPE_XBOX_ONE], &"test_origin_a_button"),
		_make_names([DEVICE_TYPE_PS_5], &"test_origin_cross"),
	]

	# Given: An Xbox device using the provider.
	var device: StdInputDevice = autofree(StdInputDevice.new())
	device.device_type = DEVICE_TYPE_XBOX_ONE
	device.glyphs = _glyphs

	# When: The device's label is fetched with a PlayStation override.
	var got := (
		device
		. get_action_origin_label(
			_make_action_set([&"test_glyph_joy"]),
			&"test_glyph_joy",
			StdInputDeviceActions.BINDING_INDEX_PRIMARY,
			DEVICE_TYPE_PS_5,
		)
	)

	# Then: The override's names are used.
	assert_eq(got, "Cross")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _DEFAULTS.keys() + _JOY_DEFAULTS.keys() + _MOUSE_DEFAULTS.keys():
		InputMap.erase_action(action)
		ProjectSettings.set_setting(&"input/" + action, null)

	TranslationServer.remove_translation(_translation)


func before_all() -> void:
	for action in _DEFAULTS:
		var events: Array[InputEvent] = []
		for key in _DEFAULTS[action]:
			var event := InputEventKey.new()
			event.keycode = key
			events.append(event)

		_add_action(action, events)

	for action in _JOY_DEFAULTS:
		var events: Array[InputEvent] = []
		for button in _JOY_DEFAULTS[action]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			events.append(event)

		_add_action(action, events)

	for action in _MOUSE_DEFAULTS:
		var events: Array[InputEvent] = []
		for button in _MOUSE_DEFAULTS[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			events.append(event)

		_add_action(action, events)

	_translation = Translation.new()
	_translation.locale = TranslationServer.get_locale()
	for key in _MESSAGES:
		_translation.add_message(key, _MESSAGES[key])

	for context in _CONTEXT_MESSAGES:
		for key in _CONTEXT_MESSAGES[context]:
			_translation.add_message(key, _CONTEXT_MESSAGES[context][key], context)

	TranslationServer.add_translation(_translation)


func before_each() -> void:
	var scope := StdSettingsScope.new()
	scope.is_loaded = true

	_glyphs = DeviceGlyphs.new()
	_glyphs.scope = scope
	_glyphs.unknown_glyph = PlaceholderTexture2D.new()
	add_child_autofree(_glyphs)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_action registers `action` with `events` as its default bindings.
func _add_action(action: StringName, events: Array[InputEvent]) -> void:
	InputMap.add_action(action)
	ProjectSettings.set_setting(&"input/" + action, {"deadzone": 0.5, "events": events})


## _count returns the keyboard origin count of `action` in `action_set`.
func _count(action_set: StdInputActionSet, action: StringName) -> int:
	return _glyphs.get_action_origin_count(
		DEVICE_ID_ALL, DEVICE_TYPE_KEYBOARD, action_set, action
	)


## _glyph returns the primary glyph of the joypad test action for `device_type`.
func _glyph(device_type: StdInputDevice.DeviceType) -> Texture2D:
	var action_set := _make_action_set([&"test_glyph_joy"])
	return _glyphs.get_action_glyph(
		DEVICE_ID_ALL, device_type, action_set, &"test_glyph_joy"
	)


## _label returns the label of `action` at binding `index` for `device_type`.
func _label(
	device_type: StdInputDevice.DeviceType,
	action: StringName = &"test_glyph_joy",
	index: int = StdInputDeviceActions.BINDING_INDEX_PRIMARY,
) -> String:
	var action_set := _make_action_set([action])
	return _glyphs.get_action_origin_label(
		DEVICE_ID_ALL, device_type, action_set, action, index
	)


## _make_action_set returns an action set declaring `actions`.
func _make_action_set(actions: Array[StringName]) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = &"Test"
	action_set.actions_digital = actions
	return action_set


## _make_joy_set returns a joypad glyph set for `device_types` with a texture in its
## `property` alone.
func _make_joy_set(
	device_types: Array[StdInputDevice.DeviceType], property: StringName
) -> StdInputGlyphSetJoy:
	var glyph_set := StdInputGlyphSetJoy.new()
	glyph_set.device_types = device_types
	glyph_set.set(property, PlaceholderTexture2D.new())
	return glyph_set


## _make_names returns origin names for `device_types` with `key` naming the joypad's
## south face button alone.
func _make_names(
	device_types: Array[StdInputDevice.DeviceType], key: StringName
) -> StdInputOriginNames:
	var names := StdInputOriginNames.new()
	names.device_types = device_types
	names.joy_buttons = {JOY_BUTTON_A: key}
	return names
