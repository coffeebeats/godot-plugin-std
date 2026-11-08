##
## std/input/device_glyphs.gd
##
## StdInputDeviceGlyphs is an abstract interface for an input device component which
## fetches origin glyphs.
##

class_name StdInputDeviceGlyphs
extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## unknown_glyph is the glyph returned for an origin which is bound but has no art. Left
## empty, such an origin returns `null`, so a host can show the origin's label instead.
@export var unknown_glyph: Texture2D = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_action_glyph returns the glyph for the origin bound to `action` at binding
## `index`, for a host drawing it at `target_size` (zero lets the provider pick). A
## bound origin with no art returns `unknown_glyph`; an unbound index returns `null`.
func get_action_glyph(
	device: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
	index: int = 0,
	target_size: Vector2 = Vector2.ZERO,
) -> Texture2D:
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument; unknown device type",
	)

	var glyph := _get_action_glyph(
		device,
		device_type,
		action_set,
		action,
		index,
		target_size,
	)
	if glyph:
		return glyph

	if _has_action_origin(device, device_type, action_set, action, index):
		return unknown_glyph

	return null


## get_action_origin_count returns how many origins are bound to the specified action,
## counted from the primary binding up to the first unbound index.
func get_action_origin_count(
	device: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
) -> int:
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument; unknown device type",
	)

	return _get_action_origin_count(device, device_type, action_set, action)


## get_action_origin_label returns the display name of the origin bound to `action` at
## binding `index`, or `""` if none is bound or the provider has no name for it.
func get_action_origin_label(
	device: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
	index: int = 0,
) -> String:
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument; unknown device type",
	)

	return _get_action_origin_label(device, device_type, action_set, action, index)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_glyph(
	_device: int,
	_device_type: StdInputDevice.DeviceType,
	_action_set: StdInputActionSet,
	_action: StringName,
	_index: int,
	_target_size: Vector2,
) -> Texture2D:
	assert(false, "unimplemented")
	return null


func _get_action_origin_count(
	_device: int,
	_device_type: StdInputDevice.DeviceType,
	_action_set: StdInputActionSet,
	_action: StringName,
) -> int:
	assert(false, "unimplemented")
	return 0


func _get_action_origin_label(
	_device: int,
	_device_type: StdInputDevice.DeviceType,
	_action_set: StdInputActionSet,
	_action: StringName,
	_index: int,
) -> String:
	assert(false, "unimplemented")
	return ""


## _has_action_origin returns whether an origin is bound to the action at binding
## `index`. The default of `false` keeps `get_action_glyph` returning `null` for an
## origin with no art.
func _has_action_origin(
	_device: int,
	_device_type: StdInputDevice.DeviceType,
	_action_set: StdInputActionSet,
	_action: StringName,
	_index: int,
) -> bool:
	return false
