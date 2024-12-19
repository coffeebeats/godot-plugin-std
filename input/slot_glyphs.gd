##
## std/input/slot_glyphs.gd
##
## StdInputSlotDeviceGlyphs is an implementation of `StdInputDeviceGlyphs` which
## delegates to the device type-specific component of a `StdInputSlot`.
##

extends StdInputDeviceGlyphs

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD

# -- INITIALIZATION ------------------------------------------------------------------ #

var slot: StdInputSlot = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_glyph(
	_device: int,  # Active device ID
	device_type: DeviceType,  # Active or overridden device type
	action_set: StringName,
	action: StringName,
	target_size: Vector2,
) -> GlyphData:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return null

	match device_type:
		DEVICE_TYPE_KEYBOARD:
			if not slot._kbm_device:
				assert(not slot.claim_kbm_input, "invalid state; missing device")
				return null

			var device := slot._kbm_device.device_id

			assert(
				slot.glyphs_kbm is StdInputDeviceGlyphs,
				"invalid state; missing component",
			)

			return (
				slot
				. glyphs_kbm
				. get_action_glyph(
					device,
					DEVICE_TYPE_KEYBOARD,
					action_set,
					action,
					target_size,
				)
			)

		_:
			# Cannot display glyphs for a joypad that's never been connected.
			if not slot._last_active_joypad:
				return null

			var device := slot._last_active_joypad.device_id

			assert(
				slot.glyphs_joy is StdInputDeviceGlyphs,
				"invalid state; missing component",
			)

			return (
				slot
				. glyphs_joy
				. get_action_glyph(
					device,
					device_type,
					action_set,
					action,
					target_size,
				)
			)


func _get_action_origin_label(
	_device: int,  # Active device ID
	device_type: DeviceType,  # Active or overridden device type
	action_set: StringName,
	action: StringName,
) -> String:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return ""

	match device_type:
		DEVICE_TYPE_KEYBOARD:
			if not slot._kbm_device:
				assert(not slot.claim_kbm_input, "invalid state; missing device")
				return ""

			var device := slot._kbm_device.device_id

			assert(
				slot.glyphs_kbm is StdInputDeviceGlyphs,
				"invalid state; missing component",
			)

			return (
				slot
				. glyphs_kbm
				. get_action_origin_label(
					device,
					DEVICE_TYPE_KEYBOARD,
					action_set,
					action,
				)
			)

		_:
			# Cannot display glyphs for a joypad that's never been connected.
			if not slot._last_active_joypad:
				return ""

			var device := slot._last_active_joypad.device_id

			assert(
				slot.glyphs_joy is StdInputDeviceGlyphs,
				"invalid state; missing component",
			)

			return (
				slot
				. glyphs_joy
				. get_action_origin_label(
					device,
					device_type,
					action_set,
					action,
				)
			)
