##
## std/input/godot/device_glyphs.gd
##
## An implemention of `StdInputDeviceGlyphs` which maps joypad names and origins to custom
## glyphs using Godot's built-in `Input` class/SDL controller database.
##

extends StdInputDeviceGlyphs

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Origin := preload("../origin.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## glyph_sets defines the list of supported glyph icon sets for any device type.
##
## NOTE: Multiple sets can be provided for the same device type; this component will
## keep searching glyph sets until it finds a matching resource, returning the first it
## finds or `null` on no match.
@export var glyph_sets: Array[InputGlyphSet] = []

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_glyph(
	_device: int,
	device_type: StdInputDevice.DeviceType,
	_action_set: StringName,
	action: StringName,
) -> GlyphData:
	for glyph_set in glyph_sets:
		if glyph_set.device_type != device_type:
			continue

		for event in InputMap.action_get_events(action):
			var data := glyph_set.get_origin_glyph(event)
			if data:
				return data

	return null
