##
## std/input/slot_devices_test.gd
##
## Tests pertaining to how a `StdInputSlot` connects, disconnects, and swaps its devices
## and their components.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")
const DeviceActions := SlotTest.DeviceActions  # gdlint:ignore=constant-name
const JoypadMonitor := SlotTest.JoypadMonitor  # gdlint:ignore=constant-name

# -- INITIALIZATION ------------------------------------------------------------------ #

var slot: StdInputSlot = null

# -- TEST METHODS -------------------------------------------------------------------- #


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
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()

	# Then: The joypad is active.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_not_null(got)
	assert_is(got, StdInputDevice)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)

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
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()

	# Then: The joypad is active.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_not_null(got)
	assert_is(got, StdInputDevice)
	assert_eq(got.device_id, device_id)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)

	# Then: The joypad is in the list of connected devices.
	assert_eq(len(slot.get_connected_devices()), 1)
	assert_has(slot.get_connected_devices(), got)

	# Given: A new joypad monitor is created and 1 device is already connected.
	var joypad_monitor := JoypadMonitor.new()
	joypad_monitor.connected = [device_id]
	joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	add_child_autofree(joypad_monitor)

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The joypad monitor is swapped.
	var joypad_monitor_prev := slot.joypad_monitor
	(
		slot
		. swap_joypad_components(
			joypad_monitor,
			slot.actions_joy,
			slot.glyphs_joy,
			slot.haptics_joy,
		)
	)
	joypad_monitor_prev.free()

	# Then: The same joypad is active (the `InputDevice` may be different though).
	var got_next: StdInputDevice = autofree(slot.get_active_device())
	assert_not_null(got_next)
	assert_is(got_next, StdInputDevice)
	assert_eq(got_next.device_id, device_id)
	assert_eq(got_next.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)

	# Then: The disconnect signal was emitted.
	assert_signal_emit_count(slot, "device_disconnected", 1)
	assert_signal_emitted_with_parameters(slot, "device_disconnected", [got])

	# Then: The connect signal was emitted.
	assert_signal_emit_count(slot, "device_connected", 1)
	assert_signal_emitted_with_parameters(slot, "device_connected", [got_next])

	# Then: There is 1 connected device.
	assert_eq(len(slot.get_connected_devices()), 1)


func test_input_slot_swap_reconnects_every_joypad() -> void:
	# Given: An input slot added to the scene with two joypads connected.
	slot.claim_kbm_input = false
	add_child_autofree(slot)
	slot.joypad_monitor.connected = [0, 1] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	for device in slot.get_connected_devices():
		autofree(device)
	assert_eq(len(slot.get_connected_devices()), 2, "precondition: two joypads")

	# Given: A new joypad monitor reporting the same two joypads.
	var joypad_monitor := JoypadMonitor.new()
	joypad_monitor.connected = [0, 1] as Array[int]
	joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	add_child_autofree(joypad_monitor)
	watch_signals(slot)

	# When: The joypad monitor is swapped.
	slot.swap_joypad_components(
		joypad_monitor, slot.actions_joy, slot.glyphs_joy, slot.haptics_joy
	)
	for device in slot.get_connected_devices():
		autofree(device)

	# Then: Both joypads were disconnected and reconnected.
	assert_signal_emit_count(slot, "device_disconnected", 2)
	assert_signal_emit_count(slot, "device_connected", 2)
	assert_eq(len(slot.get_connected_devices()), 2)


func test_input_slot_exit_disconnects_every_joypad() -> void:
	# Given: An input slot added to the scene with two joypads connected.
	slot.claim_kbm_input = false
	add_child_autofree(slot)
	slot.joypad_monitor.connected = [0, 1] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	for device in slot.get_connected_devices():
		autofree(device)
	watch_signals(slot)

	# When: The slot leaves the tree.
	remove_child(slot)

	# Then: Both joypads were disconnected.
	assert_signal_emit_count(slot, "device_disconnected", 2)
	assert_eq(len(slot.get_connected_devices()), 0)


func test_input_slot_disconnect_of_active_joypad_clears_active_device() -> void:
	# Given: An input slot added to the scene with an active joypad.
	slot.claim_kbm_input = false
	add_child_autofree(slot)
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	var joypad: StdInputDevice = autofree(slot.get_active_device())
	assert_not_null(joypad, "precondition: joypad active")

	# When: The joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(0)

	# Then: No device is active and no joypad is remembered.
	assert_null(slot.get_active_device())
	assert_null(slot.get_last_active_joypad_device())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	slot = SlotTest.make_slot()
