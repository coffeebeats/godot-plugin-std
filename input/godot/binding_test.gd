##
## Tests pertaining to the `Binding` library.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Origin := preload("../origin.gd")
const Bindings := preload("binding.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

const BindingIndex := StdInputDeviceActions.BindingIndex
const BINDING_INDEX_PRIMARY := StdInputDeviceActions.BINDING_INDEX_PRIMARY
const BINDING_INDEX_SECONDARY := StdInputDeviceActions.BINDING_INDEX_SECONDARY
const BINDING_INDEX_TERTIARY := StdInputDeviceActions.BINDING_INDEX_TERTIARY


class TestBindingBase:
	extends GutTest

	var scope: StdSettingsScope = null
	var action_set: StdInputActionSet = null

	var _default_actions := PackedStringArray()
	var _parameters := [
		[StdInputDevice.DEVICE_TYPE_GENERIC, BINDING_INDEX_PRIMARY],
		[StdInputDevice.DEVICE_TYPE_GENERIC, BINDING_INDEX_SECONDARY],
		[StdInputDevice.DEVICE_TYPE_KEYBOARD, BINDING_INDEX_PRIMARY],
		[StdInputDevice.DEVICE_TYPE_KEYBOARD, BINDING_INDEX_SECONDARY],
	]

	# -- TEST HOOKS ------------------------------------------------------------------ #

	func after_each() -> void:
		# Reset project settings by deleting any configured test actions.
		for action in _default_actions:
			ProjectSettings.set_setting(&"input/" + action, null)

		scope = null
		action_set = null
		_default_actions.clear()

	func before_all() -> void:
		# NOTE: Hide unactionable errors when using object doubles.
		ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)

	func before_each() -> void:
		scope = StdSettingsScope.new()
		action_set = StdInputActionSet.new()
		action_set.name = "test-action-set"

	# -- PRIVATE METHODS ------------------------------------------------------------- #

	func _assert_events_eq(event1: InputEvent, event2: InputEvent) -> void:
		if not event1 or not event2:
			assert_eq(event1, event2)

		var value_encoded1 := Origin.encode(event1)
		assert_gt(value_encoded1, -1)

		var value_encoded2 := Origin.encode(event2)
		assert_gt(value_encoded2, -1)

		assert_eq(value_encoded1, value_encoded2)

	func _create_joypad_event(
		button: JoyButton,
		device: int = StdInputDevice.DEVICE_ID_ALL,
	) -> InputEvent:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.device = device
		return event

	func _create_kbm_event(
		key: Key,
		device: int = StdInputDevice.DEVICE_ID_ALL,
	) -> InputEvent:
		var event := InputEventKey.new()
		event.keycode = key
		event.device = device
		return event

	func _set_events_as_default(action: StringName, events: Array) -> void:
		ProjectSettings.set_setting(
			&"input/" + action, {"deadzone": 0.5, "events": events}
		)
		_default_actions.append(action)


# -- TEST METHODS -------------------------------------------------------------------- #


class TestBindAction:
	extends TestBindingBase

	func test_to_default_origin_does_nothing_and_returns_no_change(
		params = use_parameters(_parameters),
	) -> void:
		# Given: A device type.
		var device_type: StdInputDevice.DeviceType = params[0]

		# Given: A binding index.
		var index: BindingIndex = params[1]

		# Given: A digital action name.
		var action := &"test-action"

		# Given: An action set with one digital action.
		action_set.actions_digital.append(action)

		# Given: Default events for each binding index.
		var events_default := BindingIndex.values().map(
			func(i):
				return (
					_create_kbm_event(KEY_A + i)
					if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
					else _create_joypad_event(JOY_BUTTON_A + i)
				)
		)

		# Given: The test action is bound to an origin.
		_set_events_as_default(action, events_default)
		_assert_events_eq(
			Bindings.get_action_binding(scope, action_set, action, device_type, index),
			events_default[index],
		)

		# When: The action is bound to the default event.
		var changed := (
			Bindings
			. bind_action(
				scope,
				action_set,
				action,
				events_default[index],
				device_type,
				index,
			)
		)

		# Then: There is no change.
		assert_false(changed)
		_assert_events_eq(
			Bindings.get_action_binding(scope, action_set, action, device_type, index),
			events_default[index],
		)

	func test_updates_stored_origin_and_returns_changed(
		params = use_parameters(_parameters),
	) -> void:
		# Given: A device type.
		var device_type: StdInputDevice.DeviceType = params[0]

		# Given: A binding index.
		var index: BindingIndex = params[1]

		# Given: A digital action name.
		var action := &"test-action"

		# Given: An action set with one digital action.
		action_set.actions_digital.append(action)

		# Given: Default events for each binding index.
		var events_default := BindingIndex.values().map(
			func(i):
				return (
					_create_kbm_event(KEY_A + i)
					if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
					else _create_joypad_event(JOY_BUTTON_A + i)
				)
		)

		# Given: The test action is bound to an origin.
		_set_events_as_default(action, events_default)
		_assert_events_eq(
			Bindings.get_action_binding(scope, action_set, action, device_type, index),
			events_default[index],
		)

		# When: The action is bound to a non-default event.
		var event_new := (
			_create_kbm_event(KEY_Z)
			if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
			else _create_joypad_event(JOY_BUTTON_Y)
		)
		var changed := (
			Bindings
			. bind_action(
				scope,
				action_set,
				action,
				event_new,
				device_type,
				index,
			)
		)

		# Then: The binding is successfully changed.
		assert_true(changed)
		_assert_events_eq(
			Bindings.get_action_binding(scope, action_set, action, device_type, index),
			event_new,
		)

	func test_unbinds_origin_from_other_indicies_of_same_action(
		params = use_parameters(
			[
				[StdInputDevice.DEVICE_TYPE_GENERIC],
				[StdInputDevice.DEVICE_TYPE_KEYBOARD],
			]
		),
	) -> void:
		# Given: A device type.
		var device_type: StdInputDevice.DeviceType = params[0]

		# Given: A digital action name.
		var action := &"test-action"

		# Given: An action set with one digital action.
		action_set.actions_digital.append(action)

		# Given: The test action exists but has no default values.
		_set_events_as_default(action, [])

		# Given: The action is bound to a primary origin.
		var event := (
			_create_kbm_event(KEY_A)
			if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
			else _create_joypad_event(JOY_BUTTON_A)
		)
		var changed := (
			Bindings
			. bind_action(
				scope,
				action_set,
				action,
				event,
				device_type,
				BINDING_INDEX_PRIMARY,
			)
		)
		assert_true(changed)

		# When: The secondary index is bound to the same origin.
		changed = (
			Bindings
			. bind_action(
				scope,
				action_set,
				action,
				event,
				device_type,
				BINDING_INDEX_SECONDARY,
			)
		)
		assert_true(changed)

		# Then: The primary index is unbound.
		assert_null(
			(
				Bindings
				. get_action_binding(
					scope,
					action_set,
					action,
					device_type,
					BINDING_INDEX_PRIMARY,
				)
			),
		)

		# Then: The secondary index is bound to the correct origin.
		_assert_events_eq(
			event,
			(
				Bindings
				. get_action_binding(
					scope,
					action_set,
					action,
					device_type,
					BINDING_INDEX_SECONDARY,
				)
			),
		)

	func test_unbinds_origin_from_other_actions_in_action_set(
		params = use_parameters(_parameters),
	) -> void:
		# Given: A device type.
		var device_type: StdInputDevice.DeviceType = params[0]

		# Given: A binding index.
		var index: BindingIndex = params[1]

		# Given: Two digital action names.
		var action1 := &"test-action1"
		var action2 := &"test-action2"

		# Given: An action set with two digital actions.
		action_set.actions_digital.append(action1)
		action_set.actions_digital.append(action2)

		# Given: The test actions exist but have no default values.
		_set_events_as_default(action1, [])
		_set_events_as_default(action2, [])

		# Given: The first action is bound to an origin.
		var event := (
			_create_kbm_event(KEY_A)
			if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
			else _create_joypad_event(JOY_BUTTON_A)
		)
		var changed := (
			Bindings
			. bind_action(
				scope,
				action_set,
				action1,
				event,
				device_type,
				index,
			)
		)
		assert_true(changed)

		# When: The second action is bound to that same origin.
		changed = (
			Bindings
			. bind_action(
				scope,
				action_set,
				action2,
				event,
				device_type,
				index,
			)
		)
		assert_true(changed)

		# Then: The first action is unbound.
		assert_null(
			(
				Bindings
				. get_action_binding(
					scope,
					action_set,
					action1,
					device_type,
					index,
				)
			),
		)

		# Then: The second action is bound to the correct origin.
		_assert_events_eq(
			event,
			(
				Bindings
				. get_action_binding(
					scope,
					action_set,
					action2,
					device_type,
					index,
				)
			),
		)


class TestResetAction:
	extends TestBindingBase

	func test_returns_no_change_by_default(
		params = use_parameters(_parameters),
	) -> void:
		# Given: A device type.
		var device_type: StdInputDevice.DeviceType = params[0]

		# Given: A binding index.
		var index: BindingIndex = params[1]

		# Given: A digital action name.
		var action := &"test-action"

		# Given: An action set with one digital action.
		action_set.actions_digital.append(action)

		# Given: Default events for each binding index.
		var events_default := BindingIndex.values().map(
			func(i):
				return (
					_create_kbm_event(KEY_A + i)
					if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
					else _create_joypad_event(JOY_BUTTON_A + i)
				)
		)

		# Given: The test action is bound to the default origin.
		_set_events_as_default(action, events_default)
		_assert_events_eq(
			Bindings.get_action_binding(scope, action_set, action, device_type, index),
			events_default[index],
		)

		# When: The action's binding is reset.
		var changed := (
			Bindings
			. reset_action(
				scope,
				action_set,
				action,
				device_type,
				index,
			)
		)

		# Then: There is no change.
		assert_false(changed)
		_assert_events_eq(
			Bindings.get_action_binding(scope, action_set, action, device_type, index),
			events_default[index],
		)

	func test_clears_stored_origin_and_returns_changed(
		params = use_parameters(_parameters),
	) -> void:
		# Given: A device type.
		var device_type: StdInputDevice.DeviceType = params[0]

		# Given: A binding index.
		var index: BindingIndex = params[1]

		# Given: A digital action name.
		var action := &"test-action"

		# Given: An action set with one digital action.
		action_set.actions_digital.append(action)

		# Given: Default events for each binding index.
		var events_default := BindingIndex.values().map(
			func(i):
				return (
					_create_kbm_event(KEY_A + i)
					if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
					else _create_joypad_event(JOY_BUTTON_A + i)
				)
		)

		# Given: The test action is bound to the default origin.
		_set_events_as_default(action, events_default)
		_assert_events_eq(
			Bindings.get_action_binding(scope, action_set, action, device_type, index),
			events_default[index],
		)

		# Given: The action is then bound to a non-default origin.
		var event := (
			_create_kbm_event(KEY_Z)
			if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
			else _create_joypad_event(JOY_BUTTON_Y)
		)
		var changed := (
			Bindings
			. bind_action(
				scope,
				action_set,
				action,
				event,
				device_type,
				index,
			)
		)
		assert_true(changed)

		# When: The action's binding is reset.
		changed = (
			Bindings
			. reset_action(
				scope,
				action_set,
				action,
				device_type,
				index,
			)
		)

		# Then: There is a change back to the default origin.
		assert_true(changed)
		_assert_events_eq(
			Bindings.get_action_binding(scope, action_set, action, device_type, index),
			events_default[index],
		)

	# func test_unbinds_default_origin_from_other_indicies_of_same_action() -> void:
	# 	pass

	# func test_unbinds_origin_from_other_indicies_of_same_action() -> void:
	# 	pass

	# func test_unbinds_default_origin_from_other_actions_in_action_set() -> void:
	# 	pass


class TestResetAllActions:
	extends TestBindingBase

	func test_returns_no_change_by_default(
		params = use_parameters(_parameters),
	) -> void:
		# Given: A device type.
		var device_type: StdInputDevice.DeviceType = params[0]

		# Given: A binding index.
		var index: BindingIndex = params[1]

		# Given: Two digital action names.
		var action1 := &"test-action1"
		var action2 := &"test-action2"

		# Given: An action set with two digital actions.
		action_set.actions_digital.append(action1)
		action_set.actions_digital.append(action2)

		# Given: Default events for each action.
		var events_default1 := BindingIndex.values().map(
			func(i):
				return (
					_create_kbm_event(KEY_A + i)
					if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
					else _create_joypad_event(JOY_BUTTON_A + i)
				)
		)
		var events_default2 := BindingIndex.values().map(
			func(i):
				return (
					_create_kbm_event(KEY_A + BindingIndex.size() + i)
					if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
					else _create_joypad_event(JOY_BUTTON_A + BindingIndex.size() + i)
				)
		)

		# Given: The test actions are bound to their defaults.
		_set_events_as_default(action1, events_default1)
		_set_events_as_default(action2, events_default2)

		# When: All actions in the action set are reset.
		var changed := Bindings.reset_all_actions(scope, action_set, device_type)
		assert_false(changed)

		# Then: The action's are still bound to their defaults.
		_assert_events_eq(
			events_default1[index],
			(
				Bindings
				. get_action_binding(
					scope,
					action_set,
					action1,
					device_type,
					index,
				)
			),
		)
		_assert_events_eq(
			events_default2[index],
			(
				Bindings
				. get_action_binding(
					scope,
					action_set,
					action2,
					device_type,
					index,
				)
			),
		)

	func test_clears_all_stored_origins_and_returns_changed(
		params = use_parameters(_parameters),
	) -> void:
		# Given: A device type.
		var device_type: StdInputDevice.DeviceType = params[0]

		# Given: A binding index.
		var index: BindingIndex = params[1]

		# Given: Two digital action names.
		var action1 := &"test-action1"
		var action2 := &"test-action2"

		# Given: An action set with two digital actions.
		action_set.actions_digital.append(action1)
		action_set.actions_digital.append(action2)

		# Given: Default events for each action.
		var events_default1 := BindingIndex.values().map(
			func(i):
				return (
					_create_kbm_event(KEY_A + i)
					if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
					else _create_joypad_event(JOY_BUTTON_A + i)
				)
		)
		var events_default2 := BindingIndex.values().map(
			func(i):
				return (
					_create_kbm_event(KEY_A + BindingIndex.size() + i)
					if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
					else _create_joypad_event(JOY_BUTTON_A + BindingIndex.size() + i)
				)
		)

		# Given: The test actions are bound to their defaults.
		_set_events_as_default(action1, events_default1)
		_set_events_as_default(action2, events_default2)

		# Given: Non-default origins for both actions.
		var event1 := (
			_create_kbm_event(KEY_Y)
			if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
			else _create_joypad_event(JOY_BUTTON_DPAD_UP)
		)
		var event2 := (
			_create_kbm_event(KEY_Z)
			if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
			else _create_joypad_event(JOY_BUTTON_DPAD_DOWN)
		)

		# Given: Both actions are bound to non-default events.
		assert_true(
			(
				Bindings
				. bind_action(
					scope,
					action_set,
					action1,
					event1,
					device_type,
					index,
				)
			)
		)
		_assert_events_eq(
			Bindings.get_action_binding(scope, action_set, action1, device_type, index),
			event1,
		)
		assert_true(
			(
				Bindings
				. bind_action(
					scope,
					action_set,
					action2,
					event2,
					device_type,
					index,
				)
			)
		)
		_assert_events_eq(
			Bindings.get_action_binding(scope, action_set, action2, device_type, index),
			event2,
		)

		# When: All actions in the action set are reset.
		var changed := Bindings.reset_all_actions(scope, action_set, device_type)
		assert_true(changed)

		# Then: The actions are bound to their defaults.
		_assert_events_eq(
			(
				Bindings
				. get_action_binding(
					scope,
					action_set,
					action1,
					device_type,
					index,
				)
			),
			events_default1[index],
		)
		_assert_events_eq(
			(
				Bindings
				. get_action_binding(
					scope,
					action_set,
					action2,
					device_type,
					index,
				)
			),
			events_default2[index],
		)
