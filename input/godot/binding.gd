##
## std/input/godot/binding.gd
##
## A shared library for reading and writing input bindings to a `StdSettingsScope`.
##
## NOTE: This implementation requires that all bindings apply to all players. Changing
## bindings for one player thus changes them for all players.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is
## a "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Origin := preload("origin.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## EMPTY is a sentinel value denoting an unbound input device origin. This is used to
## "overwrite" a default value bound in project settings.
const EMPTY := (1 << 63) - 1

## UNSET is a sentinel value denoting a missing input device origin.
const UNSET := -1

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create("std/input/godot/binding")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## bind_action updates the stored input event for the provided action and device
## type at the specified binding index/rank.
##
## NOTE: Binding an action to an origin will *unbind* that origin from other actions
## within the specified action set and other binding indices/rank of the same action.
static func bind_action(
	scope: StdSettingsScope,
	action_set: StdInputActionSet,
	action: StringName,
	event: InputEvent,
	device_type: StdInputDevice.DeviceType = StdInputDevice.DEVICE_TYPE_UNKNOWN,
	index: StdInputDeviceActions.BindingIndex = (
		StdInputDeviceActions.BINDING_INDEX_PRIMARY
	),
) -> bool:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action_set is StdInputActionSet, "missing input: action set")
	assert(action, "missing input: action name")
	assert(action in action_set.list_action_names(), "invalid input: unknown action")
	assert(event is InputEvent, "missing argument: input event")
	assert(
		device_type > StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: device type",
	)
	assert(index >= 0, "invalid argument: unsupported index")

	var value_encoded: int = Origin.encode(event)
	if value_encoded == -1:
		assert(false, "invalid argument: input event")
		return false

	if not Origin.is_encoded_value_for_device(value_encoded, device_type):
		assert(false, "invalid input; wrong event type")
		return false

	var changed := false

	for a in action_set.list_action_names():
		for i in StdInputDeviceActions.BindingIndex.values():
			var category := get_action_set_category(action_set, device_type)
			var key := get_action_key(a, i)

			if a == action and i == index:
				var origin_current := scope.config.get_int(category, key, UNSET)
				var origin_default := _get_origin_from_project_settings(
					a,
					device_type,
					i,
				)

				if value_encoded == origin_default:
					if origin_current == UNSET:
						continue

					if scope.config.erase(category, key):
						(
							_logger
							. info(
								"Reset action binding.",
								{&"set": action_set.name, &"action": action},
							)
						)

					changed = true

					continue

				if scope.config.set_int(category, key, value_encoded):
					(
						_logger
						. info(
							"Bound action to origin.",
							{
								&"set": action_set.name,
								&"action": action,
								&"origin": value_encoded,
							},
						)
					)

					changed = true

				continue

			var action_changed := _compare_and_swap(
				scope, category, key, value_encoded, EMPTY
			)
			if (
				not action_changed
				and (
					value_encoded
					== _get_origin_from_project_settings(
						a,
						device_type,
						i,
					)
				)
			):
				action_changed = scope.config.set_int(category, key, EMPTY)

			if action_changed:
				(
					_logger
					. debug(
						"Unbound action.",
						{&"set": action_set.name, &"action": action},
					)
				)

			changed = action_changed or changed

	return changed


## get_action_binding reads the stored input event for the provided action and device
## type at the specified binding index/rank. Bound events are first read from the
## provided `StdSettingsScope` and then from project settings, taking the first binding
## found. If no bound origin is found, then `null` is returned.
##
## NOTE: Binding indices are independent; an existing binding does not guarantee other
## `BindingIndex` values are bound.
static func get_action_binding(
	scope: StdSettingsScope,
	action_set: StdInputActionSet,
	action: StringName,
	device_type: StdInputDevice.DeviceType = StdInputDevice.DEVICE_TYPE_UNKNOWN,
	index: StdInputDeviceActions.BindingIndex = (
		StdInputDeviceActions.BINDING_INDEX_PRIMARY
	),
) -> InputEvent:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action_set is StdInputActionSet, "missing input: action set")
	assert(action, "missing input: action name")
	assert(action in action_set.list_action_names(), "invalid input: unknown action")
	assert(
		device_type > StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: device type",
	)
	assert(index >= 0, "invalid argument: unsupported index")

	var category := get_action_set_category(action_set, device_type)
	var key := get_action_key(action, index)

	var value_encoded := scope.config.get_int(category, key, UNSET)
	if value_encoded == EMPTY:
		return null

	var event: InputEvent
	if value_encoded != UNSET:
		if not Origin.is_encoded_value_for_device(value_encoded, device_type):
			assert(false, "invalid input; wrong event type")
			return null

		event = Origin.decode(value_encoded)

	if not event:
		event = _get_event_from_project_settings(action, device_type, index)

	if not event:
		return null

	# This library does not support storing specific device IDs, so set a "match
	# all" device ID for returned events.
	event.device = StdInputDevice.DEVICE_ID_ALL

	return event


## get_action_set_category returns the category name for the specified action set and
## input device type.
static func get_action_set_category(
	action_set: StdInputActionSet,
	device_type: StdInputDevice.DeviceType,
) -> StringName:
	return "%s/%d" % [action_set.name, device_type]


## get_action_key returns the key name within a category for the specified action name
## and binding index.
static func get_action_key(
	action: StringName, index: StdInputDeviceActions.BindingIndex
) -> StringName:
	return "%s/%d" % [action, index]


## action_has_user_override returns whether there is a custom input binding (i.e. user-
## set value) for the specified action, device type, and binding index. This effectively
## returns whether the bindings match the default values.
static func action_has_user_override(
	scope: StdSettingsScope,
	action_set: StdInputActionSet,
	action: StringName,
	device_type: StdInputDevice.DeviceType = StdInputDevice.DEVICE_TYPE_UNKNOWN,
	index: StdInputDeviceActions.BindingIndex = (
		StdInputDeviceActions.BINDING_INDEX_PRIMARY
	),
) -> bool:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action_set is StdInputActionSet, "missing input: action set")
	assert(action, "missing input: action name")
	assert(action in action_set.list_action_names(), "invalid input: unknown action")
	assert(
		device_type > StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: device type",
	)
	assert(index >= 0, "invalid argument: unsupported index")

	var category := get_action_set_category(action_set, device_type)
	var key := get_action_key(action, index)

	return scope.config.get_int(category, key, UNSET) != UNSET


## category_has_user_override returns whether there is any custom input binding (i.e.
## user-set value) for the specified action set and device type. This effectively
## returns whether all bindings in the action set, regardless of binding index, match
## their default values.
static func category_has_user_override(
	scope: StdSettingsScope,
	action_set: StdInputActionSet,
	device_type: StdInputDevice.DeviceType = StdInputDevice.DEVICE_TYPE_UNKNOWN,
) -> bool:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action_set is StdInputActionSet, "missing input: action set")
	assert(
		device_type > StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: device type",
	)

	var category := get_action_set_category(action_set, device_type)
	return scope.config.has_category(category)


## reset_action clears the stored input event for the provided action and device type at
## the specified binding index/rank. This returns the action binding to its default
## state.
##
## NOTE: Resetting an action to its default origin will *unbind* that origin from other
## actions within the specified action set and other binding indices/rank of the same
## action. Those other actions/ranks will *not* have their bindings reset (i.e. there is
## no cascading reset effect) - they will instead be unbound.
static func reset_action(
	scope: StdSettingsScope,
	action_set: StdInputActionSet,
	action: StringName,
	device_type: StdInputDevice.DeviceType = StdInputDevice.DEVICE_TYPE_UNKNOWN,
	index: StdInputDeviceActions.BindingIndex = (
		StdInputDeviceActions.BINDING_INDEX_PRIMARY
	),
) -> bool:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action_set is StdInputActionSet, "missing input: action set")
	assert(action, "missing input: action name")
	assert(action in action_set.list_action_names(), "invalid input: unknown action")
	assert(
		device_type > StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: device type",
	)
	assert(index >= 0, "invalid argument: unsupported index")

	var event := _get_event_from_project_settings(
		action,
		device_type,
		index,
	)
	if event == null:
		var category := get_action_set_category(action_set, device_type)
		var key := get_action_key(action, index)

		var changed := scope.config.erase(category, key)
		if changed:
			(
				_logger
				. info(
					"Reset action binding.",
					{&"set": action_set.name, &"action": action},
				)
			)

		return changed

	return bind_action(
		scope,
		action_set,
		action,
		event,
		device_type,
		index,
	)


## reset_all_actions clears the stored input events for all actions and binding indices,
## within the provided action set, for the specified device type. This returns all
## action bindings within the action set to their default state.
static func reset_all_actions(
	scope: StdSettingsScope,
	action_set: StdInputActionSet,
	device_type: StdInputDevice.DeviceType = StdInputDevice.DEVICE_TYPE_UNKNOWN,
) -> bool:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action_set is StdInputActionSet, "missing input: action set")
	assert(
		device_type > StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: device type",
	)

	var category := get_action_set_category(action_set, device_type)

	var changed := scope.config.clear(category)
	if changed:
		_logger.info("Reset all action set bindings.", {&"set": action_set.name})

	return changed


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _compare_and_swap(
	scope: StdSettingsScope,
	category: StringName,
	key: StringName,
	old: int,
	new: int,
) -> bool:
	assert(old >= 0, "invalid argument: unsupported index")
	assert(new >= 0, "invalid argument: unsupported index")

	var current: int = scope.config.get_int(category, key, UNSET)
	if current != old:
		return false

	var changed := scope.config.set_int(category, key, new)
	assert(changed, "invalid state; expected value update")

	return changed


static func _get_event_from_project_settings(
	action: StringName,
	device_type: StdInputDevice.DeviceType,
	index: StdInputDeviceActions.BindingIndex,
) -> InputEvent:
	var origin := _get_origin_from_project_settings(action, device_type, index)
	if origin == UNSET:
		return null

	return Origin.decode(origin)


static func _get_origin_from_project_settings(
	action: StringName,
	device_type: StdInputDevice.DeviceType,
	index: StdInputDeviceActions.BindingIndex,
) -> int:
	var info = ProjectSettings.get_setting_with_override(&"input/" + action)
	if not info is Dictionary:
		return UNSET

	var i: int = 0
	for event in info["events"]:
		var value_encoded := Origin.encode(event)
		if value_encoded == -1:
			assert(false, "failed to encode default input event")
			continue

		if not (Origin.is_encoded_value_for_device(value_encoded, device_type)):
			continue

		## NOTE: This assumes that project settings are ordered according to
		## `BindingIndex` rank.
		if i == index:
			return value_encoded

		i += 1

	return UNSET
