##
## Tests pertaining to the `Binding` library.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Binding := preload("binding.gd")
const Origin := preload("origin.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var test_action: StringName = &"test_action"

# -- TEST METHODS -------------------------------------------------------------------- #


func test_get_unset_joy_binding_reads_from_project_settings() -> void:
	# Given: An input event for a joypad.
	var event_joy := InputEventJoypadButton.new()
	event_joy.button_index = JOY_BUTTON_A
	event_joy.device = Binding.DEVICE_ID_ALL

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.physical_keycode = KEY_ENTER
	event_kbm.device = Binding.DEVICE_ID_ALL

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# When: The action is read from the empty scope.
	var got := Binding.get_joy(scope, test_action)

	# Then: The returned event matches expectations.
	_assert_events_eq(got, event_joy)


func test_get_unset_kbm_binding_reads_from_project_settings() -> void:
	# Given: An input event for a joypad.
	var event_joy := InputEventJoypadButton.new()
	event_joy.button_index = JOY_BUTTON_A
	event_joy.device = Binding.DEVICE_ID_ALL

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.physical_keycode = KEY_ENTER
	event_kbm.device = Binding.DEVICE_ID_ALL

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# When: The action is read from the empty scope.
	var got := Binding.get_kbm(scope, test_action)

	# Then: The returned events match.
	_assert_events_eq(got, event_kbm)


func test_get_set_joy_binding_reads_from_scope() -> void:
	# Given: An input event for a joypad.
	var event_joy := InputEventJoypadButton.new()
	event_joy.button_index = JOY_BUTTON_A
	event_joy.device = Binding.DEVICE_ID_ALL

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.physical_keycode = KEY_ENTER
	event_kbm.device = Binding.DEVICE_ID_ALL

	# Given: An override input event for a joypad.
	var event_joy_override := InputEventJoypadButton.new()
	event_joy_override.button_index = JOY_BUTTON_B
	event_joy_override.device = Binding.DEVICE_ID_ALL

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# Given: The override input event is stored in the scope.
	var updated := Binding.set_joy(scope, test_action, event_joy_override)
	assert_true(updated)

	# When: The action is read from the scope.
	var got := Binding.get_joy(scope, test_action)

	# Then: The returned events match.
	_assert_events_eq(got, event_joy_override)


func test_get_set_kbm_binding_reads_from_scope() -> void:
	# Given: An input event for a joypad.
	var event_joy := InputEventJoypadButton.new()
	event_joy.button_index = JOY_BUTTON_A
	event_joy.device = Binding.DEVICE_ID_ALL

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.keycode = KEY_ENTER
	event_kbm.device = Binding.DEVICE_ID_ALL

	# Given: An override input event for a keyboard.
	var event_kbm_override := InputEventKey.new()
	event_kbm_override.physical_keycode = KEY_1
	event_kbm_override.device = Binding.DEVICE_ID_ALL

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# Given: The override input event is stored in the scope.
	var updated := Binding.set_kbm(scope, test_action, event_kbm_override)
	assert_true(updated)

	# When: The action is read from the scope.
	var got := Binding.get_kbm(scope, test_action)

	# Then: The returned events match.
	_assert_events_eq(got, event_kbm_override)


func test_get_set_joy_binding_writes_to_secondary_index() -> void:
	# Given: An input event for a joypad.
	var event_joy := InputEventJoypadButton.new()
	event_joy.button_index = JOY_BUTTON_A
	event_joy.device = Binding.DEVICE_ID_ALL

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.physical_keycode = KEY_ENTER
	event_kbm.device = Binding.DEVICE_ID_ALL

	# Given: An override input event for a joypad.
	var event_joy_override := InputEventJoypadButton.new()
	event_joy_override.button_index = JOY_BUTTON_B
	event_joy_override.device = Binding.DEVICE_ID_ALL

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# Given: The override input event is stored in the scope.
	var updated := Binding.set_joy(scope, test_action, event_joy_override, Binding.BINDING_INDEX_SECONDARY)
	assert_true(updated)

	# When: The secondary action is read from the scope.
	var got := Binding.get_joy(scope, test_action, Binding.BINDING_INDEX_SECONDARY)

	# Then: The returned events match.
	_assert_events_eq(got, event_joy_override)

	# When: The primary action is read from the scope.
	got = Binding.get_joy(scope, test_action, Binding.BINDING_INDEX_PRIMARY)
	
	# Then: The primary index matches the event from project settings.
	_assert_events_eq(got, event_joy)

func test_get_set_kbm_binding_writes_to_secondary_index() -> void:
	# Given: An input event for a joypad.
	var event_joy := InputEventJoypadButton.new()
	event_joy.button_index = JOY_BUTTON_A
	event_joy.device = Binding.DEVICE_ID_ALL

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.physical_keycode = KEY_ENTER
	event_kbm.device = Binding.DEVICE_ID_ALL

	# Given: An override input event for a keyboard.
	var event_kbm_override := InputEventKey.new()
	event_kbm_override.physical_keycode = KEY_1
	event_kbm_override.device = Binding.DEVICE_ID_ALL

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# Given: The override input event is stored in the scope.
	var updated := Binding.set_kbm(
		scope,
		test_action,
		event_kbm_override,
		Binding.BINDING_INDEX_SECONDARY,
	)
	assert_true(updated)

	# When: The secondary action is read from the scope.
	var got := Binding.get_kbm(scope, test_action, Binding.BINDING_INDEX_SECONDARY)

	# Then: The returned events match.
	_assert_events_eq(got, event_kbm_override)

	# When: The primary action is read from the scope.
	got = Binding.get_kbm(scope, test_action, Binding.BINDING_INDEX_PRIMARY)
	
	# Then: The primary index matches the event from project settings.
	_assert_events_eq(got, event_kbm)

func test_set_empty_joy_binding_resets_value() -> void:
	# Given: An input event for a joypad.
	var event_joy := InputEventJoypadButton.new()
	event_joy.button_index = JOY_BUTTON_A
	event_joy.device = Binding.DEVICE_ID_ALL

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.physical_keycode = KEY_ENTER
	event_kbm.device = Binding.DEVICE_ID_ALL

	# Given: An override input event for a joypad.
	var event_joy_override := InputEventJoypadButton.new()
	event_joy_override.button_index = JOY_BUTTON_B
	event_joy_override.device = Binding.DEVICE_ID_ALL

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# Given: The override input event is stored in the scope.
	var updated := Binding.set_joy(scope, test_action, event_joy_override)
	assert_true(updated)

	# Given: The scope is cleared for the action.
	updated = Binding.set_joy(scope, test_action, null)
	assert_true(updated)

	# When: The action is read from the scope.
	var got := Binding.get_joy(scope, test_action)

	# Then: The returned events match.
	_assert_events_eq(got, event_joy)


func test_set_empty_kbm_binding_resets_value() -> void:
	# Given: An input event for a joypad.
	var event_joy := InputEventJoypadButton.new()
	event_joy.button_index = JOY_BUTTON_A
	event_joy.device = Binding.DEVICE_ID_ALL

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.physical_keycode = KEY_ENTER
	event_kbm.device = Binding.DEVICE_ID_ALL

	# Given: An override input event for a keyboard.
	var event_kbm_override := InputEventKey.new()
	event_kbm_override.keycode = KEY_1
	event_kbm_override.device = Binding.DEVICE_ID_ALL

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# Given: The override input event is stored in the scope.
	var updated := Binding.set_kbm(scope, test_action, event_kbm_override)
	assert_true(updated)

	# Given: The scope is cleared for the action.
	updated = Binding.set_kbm(scope, test_action, null)
	assert_true(updated)

	# When: The action is read from the scope.
	var got := Binding.get_kbm(scope, test_action)

	# Then: The returned events match.
	_assert_events_eq(got, event_kbm)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	ProjectSettings.set_setting(&"input/" + test_action, null)


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _assert_events_eq(event1: InputEvent, event2: InputEvent) -> void:
	if not event1 or not event2:
		assert_eq(event1, event2)

	var value_encoded1 := Origin.encode(event1)
	assert_gt(value_encoded1, -1)

	var value_encoded2 := Origin.encode(event2)
	assert_gt(value_encoded2, -1)

	assert_eq(value_encoded1, value_encoded2)

func _set_events_as_default(action: StringName, events: Array[InputEvent]) -> void:
	ProjectSettings.set_setting(&"input/" + action, {"deadzone": 0.5, "events": events})
