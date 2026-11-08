##
## std/input/godot/device_glyphs.gd
##
## An implemention of `StdInputDeviceGlyphs` which maps joypad names and origins to
## custom glyphs and display names using Godot's built-in `Input` class/SDL controller
## database.
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

## origin_names defines the translation keys naming origins for any device type. std
## ships no names, so without an entry a key is named by its keyboard label, and a
## joypad or mouse origin has no name.
##
## NOTE: These are searched as `glyph_sets` are, and the first entry found is
## translated. Each value must be a translation key whose translation differs from the
## key itself, since an untranslated key asserts in debug builds and is skipped in
## release builds, so the player never reads a raw key.
@export var origin_names: Array[StdInputOriginNames] = []

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

	# NOTE: Sets which don't match the joypad type can only be the generic fallback.
	var sets := _list_matching(glyph_sets, device_type)
	if (
		sets
		and not sets[0].matches(device_type)
		and device_type not in _warned_device_types
	):
		_warned_device_types.append(device_type)
		(
			_logger
			. warn(
				"No glyph set matches joypad; using generic glyphs.",
				{&"device_type": device_type},
			)
		)

	var unknown: Texture2D = null

	for glyph_set: StdInputGlyphSet in sets:
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
		return ""

	for names: StdInputOriginNames in _list_matching(origin_names, device_type):
		var key := names.get_origin_name_key(event)
		if not key:
			continue

		var label := tr(key)
		if label != key:
			return label

		assert(false, "invalid config; untranslated origin name: %s" % key)

	if event is InputEventKey:
		return Origin.get_key_label(event)

	return ""


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


## _list_matching returns the items of `resources`, each a `StdInputGlyphSet` or a
## `StdInputOriginNames`, which match `device_type`, in order.
##
## NOTE: Only a joypad type no item matches falls back to the items matching
## `DEVICE_TYPE_GENERIC`. A matched item lacking an origin doesn't, since another pad's
## icon or name would refer to a button the player doesn't have.
func _list_matching(
	resources: Array,
	device_type: StdInputDevice.DeviceType,
) -> Array:
	var matched := resources.filter(func(item): return item.matches(device_type))
	if matched or device_type in [DEVICE_TYPE_GENERIC, DEVICE_TYPE_KEYBOARD]:
		return matched

	return resources.filter(func(item): return item.matches(DEVICE_TYPE_GENERIC))
