##
## std/input/godot/device_glyphs.gd
##
## An implemention of `StdInputDeviceGlyphs` which maps joypad names and origins to custom
## glyphs using Godot's built-in `Input` class/SDL controller database.
##

extends StdInputDeviceGlyphs

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Bindings := preload("binding.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

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
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
	_target_size: Vector2,
) -> Texture2D:
	for glyph_set in glyph_sets:
		if not glyph_set.matches(device_type):
			continue

		var event := (
			Bindings
			.get_action_binding(
				scope,
				action_set,
				action,
				StdInputDevice.get_device_category(device_type),
				index,
			)
		)

		if not event:
			return null

		var texture := glyph_set.get_origin_glyph(event)
		if texture:
			return texture

	return null


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

	# There's little point supporting origin labels for joypad devices - a glyph icon
	# should be displayed instead.
	if device_type != StdInputDevice.DEVICE_TYPE_KEYBOARD:
		return ""

	var event := (
		Bindings
		.get_action_binding(
			scope,
			action_set,
			action,
			StdInputDevice.DEVICE_TYPE_KEYBOARD,
			index,
		)
	)

	if not event is InputEventKey:
		return ""

	var physical_keycode: Key = event.physical_keycode
	if physical_keycode == KEY_NONE:
		assert(false, "invalid input; missing keycodes")
		physical_keycode = event.keycode

	var keycode := (
		DisplayServer.keyboard_get_label_from_physical(physical_keycode)
		if (
			OS.has_feature(&"windows")
			or OS.has_feature(&"macos")
			or OS.has_feature(&"linuxbsd")
		)
		else physical_keycode
	)

	if not OS.is_keycode_unicode(keycode):
		return OS.get_keycode_string(keycode)

	var label := char(keycode).strip_edges()
	if not label:
		return OS.get_keycode_string(keycode)

	return label
