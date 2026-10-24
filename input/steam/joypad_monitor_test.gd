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

## _STEAM_ERROR is the condition GodotSteam reports when it rejects a call because
## Steam Input isn't running, as under test.
const _STEAM_ERROR := "SteamAPI_SteamInput() == nullptr"

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


func test_joypad_monitor_disconnect_keeps_every_other_device_in_its_slot() -> void:
	# Given: A joypad monitor which connected two devices.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	monitor._connected = PackedInt64Array([7, 9])
	watch_signals(monitor)

	# When: The device in slot 0 disconnects.
	monitor._disconnect_device(7)

	# Then: Slot 0 is reported disconnected and is left empty.
	assert_signal_emitted_with_parameters(monitor, "joy_disconnected", [0])
	assert_eq(monitor.get_device_id_for_slot(0), -1)
	assert_eq(monitor.get_slot_for_device_id(7), -1)
	assert_eq(monitor.get_slot_for_device_id(0), -1)

	# Then: The other device keeps its slot.
	assert_eq(monitor.get_device_id_for_slot(1), 9)
	assert_eq(monitor.get_slot_for_device_id(9), 1)

	# When: Another device takes a slot.
	var got: int = monitor._claim_slot(11)

	# Then: It takes the empty slot.
	assert_eq(got, 0)
	assert_eq(monitor.get_device_id_for_slot(0), 11)
	assert_eq(monitor.get_slot_for_device_id(11), 0)


func test_joypad_monitor_broadcast_skips_empty_slots() -> void:
	# Given: A joypad monitor whose slot 0 emptied when its device disconnected.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor._connected = PackedInt64Array([0, 9])
	watch_signals(monitor)

	# When: The connected joypads are broadcast.
	monitor.broadcast_connected_joypads()

	# Then: Only the occupied slot is reported, as a generic joypad, since Steam Input
	# isn't running to name the device's family.
	assert_engine_error("SteamAPI_SteamInput() == nullptr")
	assert_signal_emit_count(monitor, "joy_connected", 1)
	assert_signal_emitted_with_parameters(
		monitor, "joy_connected", [1, StdInputDevice.DEVICE_TYPE_GENERIC]
	)


func test_joypad_monitor_disconnect_drops_trailing_empty_slots() -> void:
	# Given: A joypad monitor which connected two devices while Steam Input is in use.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	monitor.steam_input_enabled_property.set_value(true)
	monitor._connected = PackedInt64Array([7, 9])

	# When: The device in slot 1 disconnects.
	monitor._disconnect_device(9)

	# Then: Its slot is dropped, so the next device appends after slot 0.
	assert_eq(monitor._connected, PackedInt64Array([7]))
	assert_eq(monitor._claim_slot(11), 1)

	# When: Every device disconnects.
	monitor._disconnect_device(7)
	monitor._disconnect_device(11)

	# Then: No slot is kept and Steam Input is no longer in use.
	assert_eq(monitor._connected, PackedInt64Array())
	assert_false(monitor.steam_input_enabled_property.get_value())


func test_joypad_monitor_connects_a_device_steam_reports_connected() -> void:
	# Given: A joypad monitor with no device connected.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	watch_signals(monitor)

	# When: Steam reports a controller connected, as it does for each controller
	# already connected once device callbacks are enabled.
	monitor._on_device_connected(7)

	# Then: The device takes slot 0 and Steam Input is in use, as a generic joypad,
	# since Steam Input isn't running to name its family.
	assert_engine_error(_STEAM_ERROR)
	assert_signal_emitted_with_parameters(
		monitor, "joy_connected", [0, StdInputDevice.DEVICE_TYPE_GENERIC]
	)
	assert_eq(monitor.get_device_id_for_slot(0), 7)
	assert_true(monitor.steam_input_enabled_property.get_value())

	# When: Steam reports the controller connected again.
	monitor._on_device_connected(7)

	# Then: It isn't connected twice.
	assert_signal_emit_count(monitor, "joy_connected", 1)


func test_joypad_monitor_connects_a_replugged_device_again() -> void:
	# Given: A joypad monitor with a device connected in slot 0.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	monitor._on_device_connected(7)
	assert_engine_error(_STEAM_ERROR)

	# When: The controller is unplugged and plugged in again under a new handle.
	monitor._on_device_disconnected(7)
	monitor._on_device_connected(9)

	# Then: The controller is connected in slot 0 again.
	assert_engine_error(_STEAM_ERROR)
	assert_eq(monitor.get_device_id_for_slot(0), 9)
	assert_true(monitor.steam_input_enabled_property.get_value())


func test_joypad_monitor_ignores_a_disconnect_of_a_device_it_dropped() -> void:
	# Given: A joypad monitor with no device connected.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	watch_signals(monitor)

	# When: Steam reports a controller disconnected which the monitor never connected,
	# as for one whose configuration doesn't use the Steam Input API.
	monitor._on_device_disconnected(7)

	# Then: No slot is reported disconnected.
	assert_signal_not_emitted(monitor, "joy_disconnected")


func test_joypad_monitor_maps_steam_input_types_to_device_families() -> void:
	# When/Then: Known Steam Input types map to their family, and the rest are generic.
	assert_eq(
		_joypad_monitor.get_device_type(Steam.INPUT_TYPE_PS4_CONTROLLER),
		StdInputDevice.DEVICE_TYPE_PS_4,
	)
	assert_eq(
		_joypad_monitor.get_device_type(Steam.INPUT_TYPE_XBOXONE_CONTROLLER),
		StdInputDevice.DEVICE_TYPE_XBOX_ONE,
	)
	assert_eq(
		_joypad_monitor.get_device_type(Steam.INPUT_TYPE_STEAM_DECK_CONTROLLER),
		StdInputDevice.DEVICE_TYPE_STEAM_DECK,
	)
	assert_eq(
		_joypad_monitor.get_device_type(Steam.INPUT_TYPE_UNKNOWN),
		StdInputDevice.DEVICE_TYPE_GENERIC,
	)


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


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _make_steam_input_enabled_property returns a property for the monitor to toggle, in a
## new scope which isn't loaded yet.
func _make_steam_input_enabled_property() -> StdSettingsPropertyBool:
	var property := StdSettingsPropertyBool.new()
	property.scope = StdSettingsScope.new()
	property.category = &"test"
	property.name = &"steam_input_enabled"
	return property
