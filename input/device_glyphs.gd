##
## std/input/device_glyphs.gd
##
## StdInputDeviceGlyphs is an abstract interface for an input device component which
## fetches origin glyphs.
##

class_name StdInputDeviceGlyphs
extends Node

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_action_glyphs returns the glyph icon for the origin bound to the specified
## action and "binding index" (e.g. primary or secondary).
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

	return _get_action_glyph(
		device,
		device_type,
		action_set,
		action,
		index,
		target_size,
	)


## get_action_origin_label returns the localized display name for the first origin bound
## to the specified action.
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


func _get_action_origin_label(
	_device: int,
	_device_type: StdInputDevice.DeviceType,
	_action_set: StdInputActionSet,
	_action: StringName,
	_index: int,
) -> String:
	assert(false, "unimplemented")
	return ""
