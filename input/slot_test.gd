##
## Tests pertaining to the `StdInputSlot` library.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var slot: StdInputSlot = null


## JoypadMonitor is a fake implementation of `StdInputSlot.JoypadMonitor`.
class JoypadMonitor:
	extends StdInputSlot.JoypadMonitor

	@export var connected: Array[int] = []
	@export
	var device_type: StdInputDevice.DeviceType = StdInputDevice.DEVICE_TYPE_UNKNOWN

	func _broadcast_connected_joypads() -> void:
		for device in connected:
			joy_connected.emit(device, device_type)


# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_slot_activates_keyboard_on_ready() -> void:
	# Given: The input slot is configured to claim keyboard + mouseinput.
	slot.claim_kbm_input = true

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The input slot is added to the scene.
	add_child_autofree(slot)

	# Then: The active device is the keyboard.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_is(got, StdInputDevice)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# Then: The keyboard device is connected.
	assert_signal_emit_count(slot, "device_connected", 1)
	assert_signal_emitted_with_parameters(slot, "device_connected", [got])

	# Then: The keyboard device is activated.
	assert_signal_emit_count(slot, "device_activated", 1)
	assert_signal_emitted_with_parameters(slot, "device_activated", [got])

	# Then: The keyboard is in the list of connected devices.
	assert_eq(len(slot.get_connected_devices()), 1)
	assert_has(slot.get_connected_devices(), got)


func test_input_slot_connects_and_disconnects_joypads() -> void:
	# Given: A new `StdInputSlot` is instantiated.
	assert_is(slot, StdInputSlot)

	# Given: The input slot is configured to claim keyboard+mouse input.
	slot.claim_kbm_input = false

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The input slot is added to the scene.
	add_child_autofree(slot)

	# Given: There's no active or connected devices.
	assert_null(slot.get_active_device())
	assert_signal_not_emitted(slot, "device_activated")
	assert_signal_not_emitted(slot, "device_connected")

	# When: A newly connected joypad device is broadcast.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_XBOX
	slot.joypad_monitor.broadcast_connected_joypads()

	# Then: The joypad is active.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_not_null(got)
	assert_is(got, StdInputDevice)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_XBOX)

	# Then: The connect signal was emitted.
	assert_signal_emit_count(slot, "device_connected", 1)
	assert_signal_emitted_with_parameters(slot, "device_connected", [got])

	# Then: The activate signal was emitted.
	assert_signal_emit_count(slot, "device_activated", 1)
	assert_signal_emitted_with_parameters(slot, "device_activated", [got])

	# Then: The joypad is in the list of connected devices.
	assert_eq(len(slot.get_connected_devices()), 1)
	assert_has(slot.get_connected_devices(), got)

	# When: The connected joypad device is disconnected.
	slot.joypad_monitor.joy_disconnected.emit(0)

	# Then: The disconnect signal was emitted.
	assert_signal_emit_count(slot, "device_disconnected", 1)
	assert_signal_emitted_with_parameters(slot, "device_disconnected", [got])

	# Then: There are no connected devices.
	assert_eq(len(slot.get_connected_devices()), 0)


func test_input_slot_swap_reconnects_joypads() -> void:
	# Given: A new `StdInputSlot` is instantiated.
	assert_is(slot, StdInputSlot)

	# Given: The input slot is configured to claim keyboard+mouse input.
	slot.claim_kbm_input = false

	# Given: The input slot is added to the scene.
	add_child_autofree(slot)

	# Given: A device ID for a single connected joypad.
	var device_id := 1

	# When: A newly connected joypad device is broadcast.
	slot.joypad_monitor.connected = [device_id] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_XBOX
	slot.joypad_monitor.broadcast_connected_joypads()

	# Then: The joypad is active.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_not_null(got)
	assert_is(got, StdInputDevice)
	assert_eq(got.device_id, device_id)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_XBOX)

	# Then: The joypad is in the list of connected devices.
	assert_eq(len(slot.get_connected_devices()), 1)
	assert_has(slot.get_connected_devices(), got)

	# Given: A new joypad monitor is created and 1 device is already connected.
	var joypad_monitor := JoypadMonitor.new()
	joypad_monitor.connected = [device_id]
	joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_XBOX
	add_child_autofree(joypad_monitor)

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The joypad monitor is swapped.
	var joypad_monitor_prev := slot.joypad_monitor
	slot.joypad_monitor = joypad_monitor
	joypad_monitor_prev.free()

	# Then: The same joypad is active (the `InputDevice` may be different though).
	var got_next: StdInputDevice = autofree(slot.get_active_device())
	assert_not_null(got_next)
	assert_is(got_next, StdInputDevice)
	assert_eq(got_next.device_id, device_id)
	assert_eq(got_next.device_type, StdInputDevice.DEVICE_TYPE_XBOX)

	# Then: The disconnect signal was emitted.
	assert_signal_emit_count(slot, "device_disconnected", 1)
	assert_signal_emitted_with_parameters(slot, "device_disconnected", [got])

	# Then: The connect signal was emitted.
	assert_signal_emit_count(slot, "device_connected", 1)
	assert_signal_emitted_with_parameters(slot, "device_connected", [got_next])

	# Then: There is 1 connected device.
	assert_eq(len(slot.get_connected_devices()), 1)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	# Construct input slot scene.

	slot = StdInputSlot.new()
	slot.glyph_type_override_property = StdSettingsPropertyInt.new()
	slot.haptics_disabled_property = StdSettingsPropertyBool.new()
	slot.haptics_strength_property = StdSettingsPropertyFloatRange.new()

	slot.joypad_monitor = JoypadMonitor.new()
	slot.add_child(slot.joypad_monitor)

	slot.cursor = StdInputCursor.new()
	slot.add_child(slot.cursor)

	slot.actions_kbm = add_child_autofree(StdInputDeviceActions.new())
	slot.glyphs_kbm = add_child_autofree(StdInputDeviceGlyphs.new())
	slot.haptics_kbm = add_child_autofree(StdInputDeviceHaptics.new())

	slot.actions_joy = add_child_autofree(StdInputDeviceActions.new())
	slot.glyphs_joy = add_child_autofree(StdInputDeviceGlyphs.new())
	slot.haptics_joy = add_child_autofree(StdInputDeviceHaptics.new())
