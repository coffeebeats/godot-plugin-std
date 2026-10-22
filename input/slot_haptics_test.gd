##
## std/input/slot_haptics_test.gd
##
## Tests pertaining to how a `StdInputSlot` routes haptics to its active device.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## Haptics is a haptics component which records each call it receives.
class Haptics:
	extends StdInputDeviceHaptics

	var calls: Array = []

	func _start_vibrate_strong(device: int, duration: float, strength: float) -> void:
		calls.append([&"strong", device, duration, strength])

	func _start_vibrate_weak(device: int, duration: float, strength: float) -> void:
		calls.append([&"weak", device, duration, strength])

	func _stop_vibrate(device: int) -> void:
		calls.append([&"stop", device])


# -- INITIALIZATION ------------------------------------------------------------------ #

var haptics: Haptics = null
var slot: StdInputSlot = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_slot_vibrate_reaches_active_joypad_at_set_strength() -> void:
	# Given: A joypad is active and the haptics strength setting is at half.
	_activate_joypad()
	slot.haptics_strength_property.set_value(0.5)

	# When: The slot vibrates both motors at full strength.
	slot.start_vibrate_strong(0.25, 1.0)
	slot.start_vibrate_weak(0.5, 1.0)

	# Then: The joypad's haptics component received both at half strength.
	assert_eq(haptics.calls, [[&"strong", 0, 0.25, 0.5], [&"weak", 0, 0.5, 0.5]])


func test_input_slot_stop_vibrate_reaches_active_joypad() -> void:
	# Given: A joypad is active.
	_activate_joypad()

	# When: The slot stops vibrating.
	slot.stop_vibrate()

	# Then: The joypad's haptics component received the stop.
	assert_eq(haptics.calls, [[&"stop", 0]])


func test_input_slot_vibrate_after_active_joypad_disconnects_does_nothing() -> void:
	# Given: The active joypad has disconnected, leaving no device active.
	_activate_joypad()
	slot.joypad_monitor.joy_disconnected.emit(0)
	assert_null(slot.get_active_device(), "precondition: no device active")

	# When: The slot vibrates.
	slot.start_vibrate_strong(0.25, 1.0)

	# Then: No haptics component was called.
	assert_eq(haptics.calls, [])


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	slot = SlotTest.make_slot()
	slot.claim_kbm_input = false

	var scope := StdSettingsScope.new()

	slot.haptics_disabled_property.scope = scope
	slot.haptics_disabled_property.category = &"test"
	slot.haptics_disabled_property.name = &"haptics_disabled"

	slot.haptics_strength_property.scope = scope
	slot.haptics_strength_property.category = &"test"
	slot.haptics_strength_property.name = &"haptics_strength"
	slot.haptics_strength_property.default = 1.0

	haptics = Haptics.new()
	slot.haptics_joy = haptics
	slot.add_child(haptics)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _activate_joypad adds the slot to the scene and connects joypad `0`, which becomes
## the active device.
func _activate_joypad() -> void:
	add_child_autofree(slot)
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_active_device())
