##
## std/input/godot/device_glyphs.gd
##
## An implemention of `StdInputDeviceGlyphs` which maps joypad names and origins to
## custom glyphs using Godot's built-in `Input` class/SDL controller database.
##

extends StdInputDeviceGlyphs

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Bindings := preload("binding.gd")
const Origin := preload("origin.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_TYPE_GENERIC := StdInputDevice.DEVICE_TYPE_GENERIC
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

## glyph_sets defines the list of supported glyph icon sets for any device type.
##
## NOTE: Multiple sets can be provided for the same device type; this component searches
## them in order and returns the first glyph found. A joypad type which no set matches
## uses the sets matching `DEVICE_TYPE_GENERIC` instead.
@export var glyph_sets: Array[StdInputGlyphSet] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

# gdlint:ignore=class-definitions-order
static var _logger := StdLogger.create("std/input/godot/device_glyphs")

## _warned_device_types holds each joypad type which has fallen back to the generic
## sets, so that the warning is logged once per type.
var _warned_device_types: Array[StdInputDevice.DeviceType] = []

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_glyph(
	_device: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
	target_size: Vector2,
) -> Texture2D:
	var event := (
		Bindings
		. get_action_binding(
			scope,
			action_set,
			action,
			StdInputDevice.get_device_category(device_type),
			index,
		)
	)

	if not event:
		return null

	# NOTE: Only a joypad type no set matches falls back to the generic sets. A matched
	# set lacking the button doesn't, since another pad's icon would name a button the
	# player doesn't have.
	var sets := _list_glyph_sets(device_type)
	if not sets and device_type not in [DEVICE_TYPE_GENERIC, DEVICE_TYPE_KEYBOARD]:
		if device_type not in _warned_device_types:
			_warned_device_types.append(device_type)
			(
				_logger
				. warn(
					"No glyph set matches joypad; using generic glyphs.",
					{&"device_type": device_type},
				)
			)

		sets = _list_glyph_sets(DEVICE_TYPE_GENERIC)

	var unknown: Texture2D = null

	for glyph_set in sets:
		var texture := glyph_set.get_origin_glyph(event, target_size)
		if texture:
			return texture

		if not unknown:
			unknown = glyph_set.unknown_glyph

	return unknown


func _get_action_origin_count(
	_device: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
) -> int:
	var category := StdInputDevice.get_device_category(device_type)

	# NOTE: A binding repeated at a later index is not another origin, so it ends the
	# count as an unbound index does; otherwise a cycling glyph would show it twice.
	var origins := PackedInt64Array()
	for index in StdInputDeviceActions.BindingIndex.values():
		var event := Bindings.get_action_binding(
			scope, action_set, action, category, index
		)
		if not event:
			break

		var origin := Origin.encode(event)
		if origin in origins:
			break

		origins.append(origin)

	return origins.size()


func _get_action_origin_label(
	_device: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
) -> String:
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: unknown device type",
	)

	# There's little point supporting origin labels for joypad devices - a glyph icon
	# should be displayed instead.
	if device_type != StdInputDevice.DEVICE_TYPE_KEYBOARD:
		return ""

	var event := (
		Bindings
		. get_action_binding(
			scope,
			action_set,
			action,
			StdInputDevice.DEVICE_TYPE_KEYBOARD,
			index,
		)
	)

	if not event is InputEventKey:
		return ""

	return Origin.get_key_label(event)


func _has_action_origin(
	_device: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
) -> bool:
	var category := StdInputDevice.get_device_category(device_type)
	return (
		Bindings.get_action_binding(scope, action_set, action, category, index) != null
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _list_glyph_sets returns the glyph sets matching `device_type`, in order.
func _list_glyph_sets(
	device_type: StdInputDevice.DeviceType,
) -> Array[StdInputGlyphSet]:
	var sets: Array[StdInputGlyphSet] = []

	for glyph_set in glyph_sets:
		if glyph_set.matches(device_type):
			sets.append(glyph_set)

	return sets
