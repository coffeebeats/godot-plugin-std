##
## std/input/godot/binding.gd
##
## A shared library for reading and writing input bindings to a `StdSettingsScope`.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Origin := preload("../origin.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## BindingIndex is an enumeration of "ranks"/"indices" in which a binding can occupy.
enum BindingIndex {  # gdlint:ignore=class-definitions-order
	PRIMARY = 0,
	SECONDARY = 1,
}

## BINDING_INDEX_PRIMARY is the primary device type-specific binding for an action.
const BINDING_INDEX_PRIMARY := BindingIndex.PRIMARY

## BINDING_INDEX_SECONDARY is the secondary device type-specific binding for an action.
const BINDING_INDEX_SECONDARY := BindingIndex.SECONDARY

## EMPTY is a sentinel value denoting an unbound input device origin. This is used to
## "overwrite" a default value bound in project settings.
const EMPTY := (1 << 63) - 1

## UNSET is a sentinel value denoting a missing input device origin.
const UNSET := -1

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
	index: BindingIndex = BINDING_INDEX_PRIMARY,
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
		for i in BindingIndex.values():
			var category := _get_action_set_category(action_set, device_type)
			var key := _get_action_key(a, i)

			if a == action and i == index:
				if (
					scope.config.get_int(category, key, UNSET) == UNSET
					and (
						value_encoded
						== _get_origin_from_project_settings(
							a,
							device_type,
							i,
						)
					)
				):
					continue

				var c := scope.config.set_int(category, key, value_encoded)

				changed = (c or changed)

				continue

			changed = (
				_compare_and_swap(scope, category, key, value_encoded, EMPTY) or changed
			)

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
	index: BindingIndex = BINDING_INDEX_PRIMARY,
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

	var category := _get_action_set_category(action_set, device_type)
	var key := _get_action_key(action, index)

	var event := _get_event_from_scope(scope, category, key, device_type)

	if not event:
		event = _get_event_from_project_settings(action, device_type, index)

	if not event:
		return null

	# This library does not support storing specific device IDs, so set a "match
	# all" device ID for returned events.
	event.device = StdInputDevice.DEVICE_ID_ALL

	return event


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
	index: BindingIndex = BINDING_INDEX_PRIMARY,
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
		var category := _get_action_set_category(action_set, device_type)
		var key := _get_action_key(action, index)

		return scope.config.erase(category, key)

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

	var category := _get_action_set_category(action_set, device_type)
	return scope.config.clear(category)


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


static func _get_action_set_category(
	action_set: StdInputActionSet,
	device_type: StdInputDevice.DeviceType,
) -> StringName:
	return "%s/%d" % [action_set.name, device_type]


static func _get_action_key(
	action: StringName,
	index: BindingIndex,
) -> StringName:
	return "%s/%d" % [action, index]


static func _get_event_from_project_settings(
	action: StringName,
	device_type: StdInputDevice.DeviceType,
	index: BindingIndex,
) -> InputEvent:
	var origin := _get_origin_from_project_settings(action, device_type, index)
	if origin == UNSET:
		return null

	return Origin.decode(origin)


static func _get_origin_from_project_settings(
	action: StringName,
	device_type: StdInputDevice.DeviceType,
	index: BindingIndex,
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


static func _get_event_from_scope(
	scope: StdSettingsScope,
	category: StringName,
	key: StringName,
	device_type: StdInputDevice.DeviceType,
) -> InputEvent:
	var value_encoded := scope.config.get_int(category, key, EMPTY)
	if value_encoded == EMPTY:
		return null

	if not Origin.is_encoded_value_for_device(value_encoded, device_type):
		assert(false, "invalid input; wrong event type")
		return null

	return Origin.decode(value_encoded)
