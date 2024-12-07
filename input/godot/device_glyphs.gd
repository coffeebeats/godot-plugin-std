##
## std/input/godot/device_glyphs.gd
##
## An implemention of `InputDevice.Glyphs` which maps joypad names and origins to custom
## glyphs using Godot's built-in `Input` class/SDL controller database.
##

extends InputDevice.Glyphs

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Origin := preload("../origin.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## glyph_sets defines the list of supported glyph icon sets for any device type.
##
## NOTE: Multiple sets can be provided for the same device type; this component will
## keep searching glyph sets until it finds a matching resource, returning the first it
## finds or `null` on no match.
@export var glyph_sets: Array[InputGlyphSet] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_origin_glyph returns a `Texture2D` containing an input origin glyph icon *for
## the specified device*. Note that `origin` is an `Origin`-encoded integer value.
func get_origin_glyph(device_type: InputDeviceType, origin: int) -> Texture2D:
	for glyph_set in glyph_sets:
		if glyph_set.device_type != device_type:
			continue

		var event := Origin.decode(origin)
		if not event:
			return null

		var texture := glyph_set.get_origin_glyph(event)
		if texture:
			return texture

	return null
