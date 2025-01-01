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
	device_type: StdInputDevice.DeviceType,  # Active or overridden device type
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
	target_size: Vector2,
) -> Texture2D:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return null

	match device_type:
		DEVICE_TYPE_KEYBOARD:
			var device := slot._kbm_device.device_id if slot._kbm_device else -1

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
					index,
					target_size,
				)
			)

		_:
			var device := (
				slot._last_active_joypad.device_id if slot._last_active_joypad else -1
			)

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
					index,
					target_size,
				)
			)


func _get_action_origin_label(
	_device: int,  # Active device ID
	device_type: StdInputDevice.DeviceType,  # Active or overridden device type
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
) -> String:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return ""

	match device_type:
		DEVICE_TYPE_KEYBOARD:
			var device := slot._kbm_device.device_id if slot._kbm_device else -1

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
					index,
				)
			)

		_:
			var device := (
				slot._last_active_joypad.device_id if slot._last_active_joypad else -1
			)

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
					index,
				)
			)
