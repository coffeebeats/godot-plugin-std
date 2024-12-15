##
## std/input/action_set.gd
##
## `StdInputGlyphSet` is a base class for collections of glyph icon resources for
## specific device types.
##

class_name StdInputGlyphSet
extends Resource

# -- DEFINITIONS --------------------------------------------------------------------- #

const GlyphData := StdInputDeviceGlyphs.GlyphData  # gdlint:ignore=constant-name

# -- CONFIGURATION ------------------------------------------------------------------- #

## device_types is a list of input device types to which these glyph icons pertain.
@export var device_types: Array[StdInputDevice.DeviceType] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_origin_glyph returns the configured resource for the provided input event.
func get_origin_glyph(event: InputEvent) -> StdInputDeviceGlyphs.GlyphData:
	assert(device_types, "invalid config; missing device type")
	return _get_origin_glyph(event)


## matches returns whether this glyph set can be used for the specified device type.
func matches(device_type: StdInputDevice.DeviceType) -> bool:
	assert(device_types, "invalid config; missing device type")
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: unknown device type",
	)

	return device_type in device_types


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_origin_glyph(_event: InputEvent) -> StdInputDeviceGlyphs.GlyphData:
	assert(false, "unimplemented")
	return null
