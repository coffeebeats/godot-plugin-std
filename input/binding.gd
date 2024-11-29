##
## Binding
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

const SUFFIX_KBM := &"/kbm"
const SUFFIX_JOY := &"/joy"

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_joy reads the list of stored joypad-typed input events for the provided action
## within the action set. Bound events are first read from the provided scope and then
## from project settings, taking the first set found. If no values are found an empty
## array is returned.
static func get_joy(
	scope: StdSettingsScope,
	action_set: InputActionSet,
	action: StringName,
) -> Array[InputEvent]:
	return _get_events(
		scope,
		action_set,
		action,
		SUFFIX_JOY,
		Origin.bitmask_indices_joy,
	)


## get_kbm reads the list of stored keyboard+mouse-typed input events for the provided
## action within the action set. Bound events are first read from the provided scope and
## then from project settings, taking the first set found. If no values are found an
## empty array is returned.
static func get_kbm(
	scope: StdSettingsScope,
	action_set: InputActionSet,
	action: StringName,
) -> Array[InputEvent]:
	return _get_events(
		scope,
		action_set,
		action,
		SUFFIX_KBM,
		Origin.bitmask_indices_kbm,
	)


## set_joy stores the provided input events as bindings for the specified action within
## the action set. Only joypad-typed events will be stored. If `events` is null or
## empty, the bindings will be erased.
static func set_joy(
	scope: StdSettingsScope,
	action_set: InputActionSet,
	action: StringName,
	events: Array[InputEvent],
) -> bool:
	return _set_events(
		scope,
		action_set,
		action,
		SUFFIX_JOY,
		Origin.bitmask_indices_joy,
		events,
	)


## set_kbm stores the provided input events as bindings for the specified action within
## the action set. Only keyboard and mouse-typed events will be stored. If `events` is
## null or empty, the bindings will be erased.
static func set_kbm(
	scope: StdSettingsScope,
	action_set: InputActionSet,
	action: StringName,
	events: Array[InputEvent],
) -> bool:
	return _set_events(
		scope,
		action_set,
		action,
		SUFFIX_KBM,
		Origin.bitmask_indices_kbm,
		events,
	)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _get_events(
	scope: StdSettingsScope,
	action_set: InputActionSet,
	action: StringName,
	action_property_suffix: StringName,
	origin_bitmask_indices: PackedInt64Array,
) -> Array[InputEvent]:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action_set is InputActionSet, "missing input: action set")
	assert(action, "missing input: action name")

	var events: Array[InputEvent] = []

	var values := (
		scope
		. config
		. get_int_list(
			action_set.name,
			action + action_property_suffix,
			PackedInt64Array(),
		)
	)

	if values:
		var seen := PackedInt64Array()

		for value_encoded in values:
			# NOTE: This makes this function O(n^2), but array sizes will be small and
			# integer comparisons are fast.
			if value_encoded in seen:
				continue

			if not Origin.is_encoded_value_type(value_encoded, origin_bitmask_indices):
				assert(false, "invalid input; wrong event type")
				continue

			var event := Origin.decode(value_encoded)

			if action_set.is_matching_event_origin(action, event):
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

				if action_set.is_matching_event_origin(action, event):
					events.append(event)

	return events


static func _set_events(
	scope: StdSettingsScope,
	action_set: InputActionSet,
	action: StringName,
	action_property_suffix: StringName,
	origin_bitmask_indices: PackedInt64Array,
	events: Array[InputEvent],
) -> bool:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action_set is InputActionSet, "missing input: action set")
	assert(action, "missing input: action name")

	var next := PackedInt64Array()

	if events and events is Array[InputEvent]:
		for event in events:
			if not action_set.is_matching_event_origin(action, event):
				assert(false, "invalid input; wrong event type")
				continue

			var value_encoded := Origin.encode(event)
			if value_encoded in next:
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

	return (
		scope
		. config
		. set_int_list(
			action_set.name,
			action + action_property_suffix,
			next,
		)
	)
