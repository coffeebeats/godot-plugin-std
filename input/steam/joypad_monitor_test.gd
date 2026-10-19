##
## std/input/steam/joypad_monitor_test.gd
##
## Tests pertaining to the Steam implementation of `StdInputSlot.JoypadMonitor`.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

## _JOYPAD_MONITOR_PATH is the monitor script, loaded in `before_all` rather than
## preloaded, since it can't be parsed without the `Steam` singleton the GodotSteam
## extension registers and `should_skip_script` skips this script without it.
const _JOYPAD_MONITOR_PATH := "joypad_monitor.gd"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _joypad_monitor: Variant = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_joypad_monitor_maps_slots_and_devices_in_connection_order() -> void:
	# Given: A joypad monitor which connected two devices, not added to the scene since
	# entering it needs Steam Input.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor._connected = PackedInt64Array([7, 9])

	# When/Then: Each slot maps to the device connected in that order and back.
	assert_eq(monitor.get_device_id_for_slot(0), 7)
	assert_eq(monitor.get_device_id_for_slot(1), 9)
	assert_eq(monitor.get_slot_for_device_id(7), 0)
	assert_eq(monitor.get_slot_for_device_id(9), 1)


func test_joypad_monitor_reports_a_missing_slot_or_device_as_negative() -> void:
	# Given: A joypad monitor which connected one device.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor._connected = PackedInt64Array([7])

	# When/Then: An empty slot and an unknown device both map to `-1`.
	assert_eq(monitor.get_device_id_for_slot(1), -1)
	assert_eq(monitor.get_device_id_for_slot(-1), -1)
	assert_eq(monitor.get_slot_for_device_id(9), -1)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	var path: String = get_script().resource_path.get_base_dir().path_join(
		_JOYPAD_MONITOR_PATH
	)
	_joypad_monitor = load(path)


func should_skip_script():
	if not ClassDB.class_exists(&"Steam"):
		return "the GodotSteam extension isn't available on this platform"

	return false
