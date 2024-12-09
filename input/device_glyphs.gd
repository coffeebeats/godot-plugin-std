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


## GlyphData contains the data necessary to render the glyph icon.
class GlyphData:
	var device_type: DeviceType = DeviceType.UNKNOWN
	var label: String = ""
	var texture: Texture2D = null


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_action_glyphs returns the glyph icon for the specified action.
func get_action_glyph(
	device: int,
	device_type: DeviceType,
	action_set: StringName,
	action: StringName,
) -> GlyphData:
	return _get_action_glyph(device, device_type, action_set, action)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_glyph(
	_device: int,
	_device_type: DeviceType,
	_action_set: StringName,
	_action: StringName,
) -> GlyphData:
	assert(false, "unimplemented")
	return null
