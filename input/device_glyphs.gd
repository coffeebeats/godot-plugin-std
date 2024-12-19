##
## std/input/device_glyphs.gd
##
## StdInputDeviceGlyphs is an abstract interface for an input device component which
## fetches origin glyphs.
##

class_name StdInputDeviceGlyphs
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const DeviceType := StdInputDevice.DeviceType  # gdlint:ignore=constant-name

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_action_glyphs returns the glyph icon for the first origin bound to the specified
## action.
func get_action_glyph(
	device: int,
	device_type: DeviceType,
	action_set: StringName,
	action: StringName,
	target_size: Vector2 = Vector2.ZERO,
) -> Texture2D:
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument; unknown device type",
	)

	return _get_action_glyph(device, device_type, action_set, action, target_size)


## get_action_origin_label returns the localized display name for the first origin bound
## to the specified action.
func get_action_origin_label(
	device: int,
	device_type: DeviceType,
	action_set: StringName,
	action: StringName,
) -> String:
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument; unknown device type",
	)

	return _get_action_origin_label(device, device_type, action_set, action)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_glyph(
	_device: int,
	_device_type: DeviceType,
	_action_set: StringName,
	_action: StringName,
	_target_size: Vector2,
) -> Texture2D:
	assert(false, "unimplemented")
	return null


func _get_action_origin_label(
	_device: int,
	_device_type: DeviceType,
	_action_set: StringName,
	_action: StringName,
) -> String:
	assert(false, "unimplemented")
	return ""
