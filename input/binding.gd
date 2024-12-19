##
## std/input/binding.gd
##
## A shared library for reading and writing input bindings to a `StdSettingsScope`.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Origin := preload("origin.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## DEVICE_ID_ALL is a special identifier for matching all device ID's within InputMap.
##
## NOTE: See https://github.com/godotengine/godot/pull/99449; '-1' values may change in
## the future.
const DEVICE_ID_ALL := -1

const _CATEGORY_JOY := &"joy"
const _CATEGORY_KBM := &"kbm"

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_joy reads the list of stored joypad-typed input events for the provided action.
## Bound events are first read from the provided scope and then from project settings,
## taking the first set found. If no values are found an empty array is returned.
static func get_joy(
	scope: StdSettingsScope,
	action: StringName,
) -> Array[InputEvent]:
	var events := _get_events(
		scope,
		_CATEGORY_JOY,
		action,
		Origin.bitmask_indices_joy,
	)

	# This library does not support storing specific device IDs, so set a "match all"
	# device ID for returned events.
	for event in events:
		event.device = DEVICE_ID_ALL

	return events


## get_kbm reads the list of stored keyboard+mouse-typed input events for the provided
## action. Bound events are first read from the provided scope and then from project
## settings, taking the first set found. If no values are found an empty array is
## returned.
static func get_kbm(
	scope: StdSettingsScope,
	action: StringName,
) -> Array[InputEvent]:
	var events := _get_events(
		scope,
		_CATEGORY_KBM,
		action,
		Origin.bitmask_indices_kbm,
	)

	# This library does not support storing specific device IDs, so set a "match all"
	# device ID for returned events.
	for event in events:
		event.device = DEVICE_ID_ALL

	return events


## set_joy stores the provided input events as bindings for the specified action. Only
## joypad-typed events will be stored. If `events` is null or empty, the bindings will
## be erased.
static func set_joy(
	scope: StdSettingsScope,
	action: StringName,
	events: Array[InputEvent],
) -> bool:
	if events.any(func(e): return e.device != DEVICE_ID_ALL):
		assert(false, "invalid input; unsupport device ID found")
		return false

	return _set_events(
		scope,
		_CATEGORY_JOY,
		action,
		Origin.bitmask_indices_joy,
		events,
	)


## set_kbm stores the provided input events as bindings for the specified action. Only
## keyboard and mouse-typed events will be stored. If `events` is null or empty, the
## bindings will be erased.
static func set_kbm(
	scope: StdSettingsScope,
	action: StringName,
	events: Array[InputEvent],
) -> bool:
	if events.any(func(e): return e.device != DEVICE_ID_ALL):
		assert(false, "invalid input; unsupport device ID found")
		return false

	return _set_events(
		scope,
		_CATEGORY_KBM,
		action,
		Origin.bitmask_indices_kbm,
		events,
	)


## store_joy adds the provided input event as a binding for the specified action, if it
## does not yet exist. Only joypad-typed events will be stored.
static func store_joy(
	scope: StdSettingsScope,
	action: StringName,
	event: InputEvent,
) -> bool:
	if not event:
		return false

	var events := get_joy(scope, action)
	events.append(event)

	return set_joy(scope, action, events)


## store_kbm adds the provided input event as a binding for the specified action, if it
## does not yet exist. Only keyboard and mouse-typed events will be stored.
static func store_kbm(
	scope: StdSettingsScope,
	action: StringName,
	event: InputEvent,
) -> bool:
	if not event:
		return false

	var events := get_kbm(scope, action)
	events.append(event)

	return set_kbm(scope, action, events)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _get_events(
	scope: StdSettingsScope,
	category: StringName,
	action: StringName,
	origin_bitmask_indices: PackedInt64Array,
) -> Array[InputEvent]:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action, "missing input: action name")

	var events: Array[InputEvent] = []

	var values := scope.config.get_int_list(category, action, PackedInt64Array())

	if values:
		var seen := PackedInt64Array()

		for value_encoded in values:
			# NOTE: This makes this function O(n^2), but array sizes will be small and
			# integer comparisons are fast.
			# FIXME(https://github.com/godotengine/godot/issues/100580): Revert to `in`.
			if seen.has(value_encoded):
				continue

			if not Origin.is_encoded_value_type(value_encoded, origin_bitmask_indices):
				assert(false, "invalid input; wrong event type")
				continue

			var event := Origin.decode(value_encoded)
			if not event:
				continue

			seen.append(value_encoded)
			events.append(event)
	else:
		var info = ProjectSettings.get_setting_with_override(&"input/" + action)
		if info is Dictionary:
			for event in info["events"]:
				# NOTE: This is a less efficient means of checking compatibility, but
				# it maintains consistency with other input event stores.
				if not (
					Origin
					. is_encoded_value_type(
						Origin.encode(event),
						origin_bitmask_indices,
					)
				):
					continue

				events.append(event)

	return events


static func _set_events(
	scope: StdSettingsScope,
	category: StringName,
	action: StringName,
	origin_bitmask_indices: PackedInt64Array,
	events: Array[InputEvent],
) -> bool:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action, "missing input: action name")

	var next := PackedInt64Array()

	if events and events is Array[InputEvent]:
		for event in events:
			var value_encoded := Origin.encode(event)
			if value_encoded < 0 or value_encoded in next:
				continue

			if not (
				Origin
				. is_encoded_value_type(
					value_encoded,
					origin_bitmask_indices,
				)
			):
				assert(false, "invalid input; wrong event type")
				continue

			next.append(value_encoded)

	return scope.config.set_int_list(category, action, next)
