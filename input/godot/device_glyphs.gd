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
@export var glyph_sets: Array[StdInputGlyphSet] = []

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_glyph(
	_device: int,
	device_type: StdInputDevice.DeviceType,
	_action_set: StringName,
	action: StringName,
	_target_size: Vector2,
) -> Texture2D:
	for glyph_set in glyph_sets:
		if not glyph_set.matches(device_type):
			continue

		for event in InputMap.action_get_events(action):
			var texture := glyph_set.get_origin_glyph(event)
			if texture:
				return texture

	return null


func _get_action_origin_label(
	_device: int,
	device_type: DeviceType,
	_action_set: StringName,
	action: StringName,
) -> String:
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: unknown device type",
	)

	# There's little point supporting origin labels for joypad devices - a glyph icon
	# should be displayed instead.
	if device_type != StdInputDevice.DEVICE_TYPE_KEYBOARD:
		return ""

	for event in InputMap.action_get_events(action):
		if not event is InputEventKey:
			continue

		if (
			event.keycode != KEY_NONE
			and event.physical_keycode != KEY_NONE
			and event.keycode != event.physical_keycode
		):
			assert(false, "invalid input; found conflicting keycodes")
			continue

		# NOTE: Only one of these properties can be set, so take the union of them in order
		# to handle all of them.
		var keycode: Key = event.keycode | event.physical_keycode
		return OS.get_keycode_string(keycode).to_upper()

	return ""
