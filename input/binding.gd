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

## BindingIndex is an enumeration of "ranks"/"indices" in which a binding can occupy.
enum BindingIndex {
	PRIMARY = 0,
	SECONDARY = 1,
	TERTIARY = 2,
}

## BINDING_INDEX_PRIMARY is the primary device type-specific binding for an action.
const BINDING_INDEX_PRIMARY := BindingIndex.PRIMARY

## BINDING_INDEX_SECONDARY is the secondary device type-specific binding for an action.
const BINDING_INDEX_SECONDARY := BindingIndex.SECONDARY

## BINDING_INDEX_TERTIARY is the tertiary device type-specific binding for an action.
const BINDING_INDEX_TERTIARY := BindingIndex.TERTIARY

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_joy reads a stored joypad-typed input event for the provided action at the
## specified binding index/rank. Bound events are first read from the provided scope and
## then from project settings, taking the first set found. If no values are found `null`
## is returned.
##
## NOTE: An existing binding does not guarantee a higher-priority `BindingIndex` is
## bound. Additionally, it's possible that the returned origin is bound to the same
## action at a different `BindingIndex` rank.
static func get_joy(
	scope: StdSettingsScope,
	action: StringName,
	index: BindingIndex = BINDING_INDEX_PRIMARY,
) -> InputEvent:
	var event := _get_event_from_scope(
		scope,
		_CATEGORY_JOY,
		action,
		Origin.bitmask_indices_joy,
		index,
	)

	if not event:
		event = _get_event_from_project_settings(
			action, Origin.bitmask_indices_joy, index,
		)

	if not event:
		return null
	
	# This library does not support storing specific device IDs, so set a "match
	# all" device ID for returned events.
	event.device = DEVICE_ID_ALL

	return event


## get_kbm reads a stored keyboard+mouse-typed input event for the provided action at
## the specified binding index/rank. Bound events are first read from the provided scope
## and then from project settings, taking the first set found. If no values are found
## `null` is returned.
##
## NOTE: An existing binding does not guarantee a higher-priority `BindingIndex` is
## bound. Additionally, it's possible that the returned origin is bound to the same
## action at a different `BindingIndex` rank.
static func get_kbm(
	scope: StdSettingsScope,
	action: StringName,
	index: BindingIndex = BINDING_INDEX_PRIMARY,
) -> InputEvent:
	var event := _get_event_from_scope(
		scope,
		_CATEGORY_KBM,
		action,
		Origin.bitmask_indices_kbm,
		index,
	)

	if not event:
		event = _get_event_from_project_settings(
			action, Origin.bitmask_indices_kbm, index,
		)

	if not event:
		return null

	# This library does not support storing specific device IDs, so set a "match
	# all" device ID for returned events.
	event.device = DEVICE_ID_ALL
	
	return event


## set_joy stores the provided input event as a binding for the specified action at the
## specified binding index/rank. Only joypad-typed events will be stored. If `event` is
## `null`, the binding will be erased.
##
## NOTE: Each `BindingIndex` rank is independent of one another; duplicates must be
## managed by the caller.
static func set_joy(
	scope: StdSettingsScope,
	action: StringName,
	event: InputEvent,
	index: BindingIndex = BINDING_INDEX_PRIMARY,
) -> bool:
	if event and event.device != DEVICE_ID_ALL:
		assert(false, "invalid input; unsupport device ID found")
		return false

	return _set_event_on_scope(
		scope,
		_CATEGORY_JOY,
		action,
		Origin.bitmask_indices_joy,
		event,
		index,
	)

## set_kbm stores the provided input event as a binding for the specified action at the
## specified binding index/rank. Only keyboard and mouse-typed events will be stored.
## If `event` is `null`, the binding will be erased.
##
## NOTE: Each `BindingIndex` rank is independent of one another; duplicates must be
## managed by the caller.
static func set_kbm(
	scope: StdSettingsScope,
	action: StringName,
	event: InputEvent,
	index: BindingIndex = BINDING_INDEX_PRIMARY,
) -> bool:
	if event and event.device != DEVICE_ID_ALL:
		assert(false, "invalid input; unsupport device ID found")
		return false

	return _set_event_on_scope(
		scope,
		_CATEGORY_KBM,
		action,
		Origin.bitmask_indices_kbm,
		event,
		index,
	)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _get_event_from_scope(
	scope: StdSettingsScope,
	category: StringName,
	action: StringName,
	origin_bitmask_indices: PackedInt64Array,
	index: BindingIndex,
) -> InputEvent:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action, "missing input: action name")
	assert(index >= 0, "invalid argument: unsupported index")

	var value_encoded := scope.config.get_int(category, action + "/%d" % index, -1)
	if value_encoded == -1:
		return null

	if not Origin.is_encoded_value_type(value_encoded, origin_bitmask_indices):
		assert(false, "invalid input; wrong event type")
		return null

	return Origin.decode(value_encoded)

static func _get_event_from_project_settings(
	action: StringName,
	origin_bitmask_indices: PackedInt64Array,
	index: BindingIndex,
) -> InputEvent:
	assert(action, "missing input: action name")
	assert(index >= 0, "invalid argument: unsupported index")

	var info = ProjectSettings.get_setting_with_override(&"input/" + action)
	if not info is Dictionary:
		return null

	var i: int = 0
	for event in info["events"]:
		# NOTE: This is a less efficient means of checking compatibility, but
		# it maintains consistency with other input event stores.
		if not (
			Origin
			.is_encoded_value_type(
				Origin.encode(event),
				origin_bitmask_indices,
			)
		):
			continue

		## NOTE: This assumes that project settings are ordered according to
		## `BindingIndex` rank.
		if i == index:
			return event

		i += 1

	return null

static func _set_event_on_scope(
	scope: StdSettingsScope,
	category: StringName,
	action: StringName,
	origin_bitmask_indices: PackedInt64Array,
	event: InputEvent,
	index: BindingIndex,
) -> bool:
	assert(scope is StdSettingsScope, "missing input: scope")
	assert(action, "missing input: action name")
	assert(index >= 0, "invalid argument: unsupported index")

	action = action + "/%d" % index

	if event == null:
		return scope.config.erase(category, action)

	var value_encoded := Origin.encode(event)
	if value_encoded < 0:
		return false

	if not (
		Origin
		.is_encoded_value_type(
			value_encoded,
			origin_bitmask_indices,
		)
	):
		assert(false, "invalid input; wrong event type")
		return false

	return scope.config.set_int(category, action, value_encoded)
