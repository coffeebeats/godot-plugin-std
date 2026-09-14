##
## std/input/slot_haptics.gd
##
## StdInputSlotDeviceHaptics is an implementation of `StdInputDeviceHaptics` which
## delegates to the device type-specific component of a `StdInputSlot`.
##

extends StdInputDeviceHaptics

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD

# -- INITIALIZATION ------------------------------------------------------------------ #

var slot: StdInputSlot = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _start_vibrate_strong(device: int, duration: float, strength: float) -> void:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return

	if not slot.active:
		return

	assert(device == slot.active.device_id, "invalid argument; wrong device ID")
	slot.active.start_vibrate_strong(duration, strength)


func _start_vibrate_weak(device: int, duration: float, strength: float) -> void:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return

	if not slot.active:
		return

	assert(device == slot.active.device_id, "invalid argument; wrong device ID")
	slot.active.start_vibrate_weak(duration, strength)


func _stop_vibrate(device: int) -> void:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return

	if not slot.active:
		return

	assert(device == slot.active.device_id, "invalid argument; wrong device ID")
	slot.active.stop_vibrate()
