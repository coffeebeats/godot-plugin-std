##
## std/input/action_set.gd
##
## `InputGlyphSet` is a base class for collections of glyph icon resources for specific
## device types.
##

class_name InputGlyphSet
extends Resource

# -- DEFINITIONS --------------------------------------------------------------------- #

const GlyphData := StdInputDeviceGlyphs.GlyphData  # gdlint:ignore=constant-name

# -- CONFIGURATION ------------------------------------------------------------------- #

## device_type is the type of input device to which these glyph icons pertain.
@export var device_type: InputDevice.InputDeviceType

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_origin_glyph returns the configured resource for the provided input event.
func get_origin_glyph(event: InputEvent) -> StdInputDeviceGlyphs.GlyphData:
	return _get_origin_glyph(event)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_origin_glyph(_event: InputEvent) -> StdInputDeviceGlyphs.GlyphData:
	assert(false, "unimplemented")
	return null
