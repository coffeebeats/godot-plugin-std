##
## std/input/steam/joypad_monitor_test.gd
##
## Tests pertaining to the Steam implementation of `StdInputSlot.JoypadMonitor`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SteamJoypadMonitor := preload("joypad_monitor.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_joypad_monitor_maps_slots_and_devices_in_connection_order() -> void:
	# Given: A joypad monitor which connected two devices, not added to the scene since
	# entering it needs Steam Input.
	var monitor: SteamJoypadMonitor = autofree(SteamJoypadMonitor.new())
	monitor._connected = PackedInt64Array([7, 9])

	# When/Then: Each slot maps to the device connected in that order and back.
	assert_eq(monitor.get_device_id_for_slot(0), 7)
	assert_eq(monitor.get_device_id_for_slot(1), 9)
	assert_eq(monitor.get_slot_for_device_id(7), 0)
	assert_eq(monitor.get_slot_for_device_id(9), 1)


func test_joypad_monitor_reports_a_missing_slot_or_device_as_negative() -> void:
	# Given: A joypad monitor which connected one device.
	var monitor: SteamJoypadMonitor = autofree(SteamJoypadMonitor.new())
	monitor._connected = PackedInt64Array([7])

	# When/Then: An empty slot and an unknown device both map to `-1`.
	assert_eq(monitor.get_device_id_for_slot(1), -1)
	assert_eq(monitor.get_device_id_for_slot(-1), -1)
	assert_eq(monitor.get_slot_for_device_id(9), -1)
