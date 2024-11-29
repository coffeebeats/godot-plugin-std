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

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.keycode = KEY_ENTER

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# Given: A new action set.
	var action_set := InputActionSet.new()
	action_set.name = "test-action-set"

	# Given: The action is added to the action set.
	action_set.actions_digital.append(test_action)

	# When: The action is read from the empty scope.
	var got := Binding.get_joy(scope, action_set, test_action)

	# Then: The returned events match.
	_assert_events_equal(got, [event_joy])


func test_get_unset_kbm_binding_reads_from_project_settings() -> void:
	# Given: An input event for a joypad.
	var event_joy := InputEventJoypadButton.new()
	event_joy.button_index = JOY_BUTTON_A

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.keycode = KEY_ENTER

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# Given: A new action set.
	var action_set := InputActionSet.new()
	action_set.name = "test-action-set"

	# Given: The action is added to the action set.
	action_set.actions_digital.append(test_action)

	# When: The action is read from the empty scope.
	var got := Binding.get_kbm(scope, action_set, test_action)

	# Then: The returned events match.
	_assert_events_equal(got, [event_kbm])


func test_get_set_joy_binding_reads_from_scope() -> void:
	# Given: An input event for a joypad.
	var event_joy := InputEventJoypadButton.new()
	event_joy.button_index = JOY_BUTTON_A

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.keycode = KEY_ENTER

	# Given: An override input event for a joypad.
	var event_joy_override := InputEventJoypadButton.new()
	event_joy_override.button_index = JOY_BUTTON_B

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# Given: A new action set.
	var action_set := InputActionSet.new()
	action_set.name = "test-action-set"

	# Given: The action is added to the action set.
	action_set.actions_digital.append(test_action)

	# Given: The override input event is stored in the scope.
	var updated := Binding.set_joy(scope, action_set, test_action, [event_joy_override])
	assert_true(updated)

	# When: The action is read from the scope.
	var got := Binding.get_joy(scope, action_set, test_action)

	# Then: The returned events match.
	_assert_events_equal(got, [event_joy_override])


func test_get_set_kbm_binding_reads_from_scope() -> void:
	# Given: An input event for a joypad.
	var event_joy := InputEventJoypadButton.new()
	event_joy.button_index = JOY_BUTTON_A

	# Given: An input event for a keyboard.
	var event_kbm := InputEventKey.new()
	event_kbm.keycode = KEY_ENTER

	# Given: An override input event for a keyboard.
	var event_kbm_override := InputEventKey.new()
	event_kbm_override.keycode = KEY_1

	# Given: Default settings are defined in project settings.
	_set_events_as_default(test_action, [event_joy, event_kbm])

	# Given: A new, empty scope.
	var scope := StdSettingsScope.new()

	# Given: A new action set.
	var action_set := InputActionSet.new()
	action_set.name = "test-action-set"

	# Given: The action is added to the action set.
	action_set.actions_digital.append(test_action)

	# Given: The override input event is stored in the scope.
	var updated := Binding.set_kbm(scope, action_set, test_action, [event_kbm_override])
	assert_true(updated)

	# When: The action is read from the scope.
	var got := Binding.get_kbm(scope, action_set, test_action)

	# Then: The returned events match.
	_assert_events_equal(got, [event_kbm_override])


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	ProjectSettings.set_setting(&"input/" + test_action, null)


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _set_events_as_default(action: StringName, events: Array[InputEvent]) -> void:
	ProjectSettings.set_setting(&"input/" + action, {"deadzone": 0.5, "events": events})


func _assert_events_equal(v1: Array[InputEvent], v2: Array[InputEvent]) -> void:
	var events1 := PackedInt64Array()
	var events2 := PackedInt64Array()

	if v1 is Array[InputEvent]:
		for event in v1:
			var value_encoded := Origin.encode(event)
			assert_gt(value_encoded, -1)

			events1.append(value_encoded)

	if v2 is Array[InputEvent]:
		for event in v2:
			var value_encoded := Origin.encode(event)
			assert_gt(value_encoded, -1)

			events2.append(value_encoded)

	assert_eq_deep(events1, events2)