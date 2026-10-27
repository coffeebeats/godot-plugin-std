# gdlint:ignore=max-public-methods
##
## std/input/steam/joypad_monitor_test.gd
##
## Tests pertaining to the Steam implementation of `StdInputSlot.JoypadMonitor`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GodotJoypadMonitorTest := preload("../godot/joypad_monitor_test.gd")

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
	monitor._types[9] = Steam.INPUT_TYPE_PS4_CONTROLLER
	watch_signals(monitor)

	# When: The connected joypads are broadcast.
	monitor.broadcast_connected_joypads()

	# Then: Only the occupied slot is reported, with the type its device connected with.
	assert_signal_emit_count(monitor, "joy_connected", 1)
	assert_signal_emitted_with_parameters(
		monitor, "joy_connected", [1, StdInputDevice.DEVICE_TYPE_PS_4]
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


func test_joypad_monitor_waits_for_steam_to_list_a_reported_device() -> void:
	# Given: A joypad monitor with no device connected.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	watch_signals(monitor)

	# When: Steam reports a controller it doesn't list yet.
	monitor._wait_for_device(7, 0)
	monitor._connect_waiting_devices([], 16)

	# Then: The controller waits, checked each frame, without connecting.
	assert_signal_not_emitted(monitor, "joy_connected")
	assert_eq(monitor.get_slot_for_device_id(7), -1)
	assert_true(monitor.is_processing())

	# When: Steam lists the controller.
	monitor._connect_waiting_devices([7], 32)

	# Then: The device takes slot 0 as a generic joypad.
	#
	# NOTE: Steam Input isn't running under test to name the joypad's family.
	assert_engine_error(_STEAM_ERROR)
	assert_signal_emitted_with_parameters(
		monitor, "joy_connected", [0, StdInputDevice.DEVICE_TYPE_GENERIC]
	)
	assert_eq(monitor.get_device_id_for_slot(0), 7)

	# Then: Steam Input is in use, and nothing is checked each frame.
	assert_true(monitor.steam_input_enabled_property.get_value())
	assert_false(monitor.is_processing())

	# When: Steam reports the controller again.
	monitor._wait_for_device(7, 48)
	monitor._connect_waiting_devices([7], 48)

	# Then: It isn't connected twice.
	assert_signal_emit_count(monitor, "joy_connected", 1)


func test_joypad_monitor_waits_for_a_device_steam_reports_connected() -> void:
	# Given: A joypad monitor with no device connected.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	watch_signals(monitor)

	# When: Steam reports a controller connected which it doesn't list.
	#
	# NOTE: Steam Input isn't running under test to list it.
	monitor._on_device_connected(7)

	# Then: The controller waits, checked each frame, without connecting.
	assert_engine_error(_STEAM_ERROR)
	assert_signal_not_emitted(monitor, "joy_connected")
	assert_true(monitor.is_processing())

	# When: Steam lists the controller.
	monitor._connect_waiting_devices([7], Time.get_ticks_msec())

	# Then: The controller takes slot 0.
	assert_engine_error(_STEAM_ERROR)
	assert_eq(monitor.get_slot_for_device_id(7), 0)


func test_joypad_monitor_waits_for_a_device_whose_configuration_loads_first() -> void:
	# Given: A joypad monitor with no device connected.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	watch_signals(monitor)

	# When: A Steam Input configuration loads before Steam reports the controller.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": true})

	# Then: The controller waits, checked each frame, without connecting.
	assert_engine_error(_STEAM_ERROR)
	assert_signal_not_emitted(monitor, "joy_connected")
	assert_true(monitor.is_processing())

	# When: Steam reports the controller connected, then lists it.
	monitor._on_device_connected(7)
	monitor._connect_waiting_devices([7], Time.get_ticks_msec())

	# Then: The controller is connected once.
	assert_engine_error(_STEAM_ERROR)
	assert_engine_error(_STEAM_ERROR)
	assert_signal_emit_count(monitor, "joy_connected", 1)


func test_joypad_monitor_connects_an_unlisted_device_after_the_timeout() -> void:
	# Given: A joypad monitor waiting for Steam to list a reported controller.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	monitor._wait_for_device(7, 0)
	watch_signals(monitor)

	# When: Steam still doesn't list it just before the timeout.
	monitor._connect_waiting_devices([], 999)

	# Then: The controller still waits.
	assert_signal_not_emitted(monitor, "joy_connected")

	# When: Steam still doesn't list it at the timeout.
	monitor._connect_waiting_devices([], 1000)

	# Then: The controller connects anyway, and nothing is checked each frame.
	assert_engine_error(_STEAM_ERROR)
	assert_eq(monitor.get_slot_for_device_id(7), 0)
	assert_false(monitor.is_processing())


func test_joypad_monitor_drops_a_waiting_device_which_disconnects() -> void:
	# Given: A joypad monitor waiting for Steam to list a reported controller.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	monitor._wait_for_device(7, 0)
	watch_signals(monitor)

	# When: The controller disconnects, and Steam then lists its handle.
	monitor._on_device_disconnected(7)
	monitor._connect_waiting_devices([7], 16)

	# Then: The controller isn't connected, and nothing is checked each frame.
	assert_signal_not_emitted(monitor, "joy_connected")
	assert_false(monitor.is_processing())


func test_joypad_monitor_drops_a_waiting_device_whose_configuration_opts_out() -> void:
	# Given: A joypad monitor waiting for Steam to list a reported controller.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	monitor._wait_for_device(7, 0)
	watch_signals(monitor)

	# When: Its configuration loads without the Steam Input API, then Steam lists it.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": false})
	monitor._connect_waiting_devices([7], 16)

	# Then: The controller isn't connected, and nothing is checked each frame.
	assert_signal_not_emitted(monitor, "joy_connected")
	assert_false(monitor.is_processing())


func test_joypad_monitor_compares_a_reported_type_with_the_connected_one() -> void:
	# Given: A joypad monitor which connected a device of unknown type.
	#
	# NOTE: Steam Input isn't running under test to report one.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	monitor._wait_for_device(7, 0)
	monitor._connect_waiting_devices([7], 0)
	assert_engine_error(_STEAM_ERROR)

	# When/Then: The type it connected with matches, and another type doesn't.
	assert_true(monitor._has_connected_type(7, Steam.INPUT_TYPE_UNKNOWN))
	assert_false(monitor._has_connected_type(7, Steam.INPUT_TYPE_PS4_CONTROLLER))


func test_joypad_monitor_connects_a_replugged_device_again() -> void:
	# Given: A joypad monitor with a device connected in slot 0.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	monitor._wait_for_device(7, 0)
	monitor._connect_waiting_devices([7], 0)
	assert_engine_error(_STEAM_ERROR)

	# When: The controller is unplugged and plugged in again under a new handle.
	monitor._on_device_disconnected(7)
	monitor._wait_for_device(9, 16)
	monitor._connect_waiting_devices([9], 16)

	# Then: The controller is connected in slot 0 again.
	assert_engine_error(_STEAM_ERROR)
	assert_eq(monitor.get_device_id_for_slot(0), 9)
	assert_true(monitor.steam_input_enabled_property.get_value())


func test_joypad_monitor_skips_a_device_whose_configuration_opted_out_first() -> void:
	# Given: A joypad monitor with no device connected.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	watch_signals(monitor)

	# When: A controller's configuration loads without using the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": false})

	# When: Steam then reports the controller connected, as on a replug.
	monitor._on_device_connected(7)

	# Then: The controller isn't connected.
	assert_signal_not_emitted(monitor, "joy_connected")
	assert_eq(monitor.get_slot_for_device_id(7), -1)

	# When: The controller is replugged before its configuration loads again.
	monitor._on_device_disconnected(7)
	monitor._wait_for_device(7, 0)
	monitor._connect_waiting_devices([7], 0)

	# Then: It's connected, since its old configuration no longer applies.
	assert_engine_error(_STEAM_ERROR)
	assert_eq(monitor.get_slot_for_device_id(7), 0)


func test_joypad_monitor_ignores_a_disconnect_of_a_device_it_dropped() -> void:
	# Given: A joypad monitor with no device connected.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	watch_signals(monitor)

	# When: Steam reports a disconnect of a controller the monitor never connected.
	monitor._on_device_disconnected(7)

	# Then: No slot is reported disconnected.
	assert_signal_not_emitted(monitor, "joy_disconnected")


func test_joypad_monitor_releases_an_opted_out_virtual_gamepad() -> void:
	# Given: A joypad monitor which holds Steam's virtual gamepads in a Godot one.
	var godot_monitor := _make_godot_joypad_monitor()
	var monitor := _make_joypad_monitor(godot_monitor)

	# Given: A Steam controller's virtual gamepad is open.
	godot_monitor.open(0, GodotJoypadMonitorTest.virtual_gamepad(7))
	watch_signals(godot_monitor)

	# When: The controller's configuration loads without the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": false})

	# Then: The Godot monitor reports its virtual gamepad.
	assert_signal_emitted_with_parameters(
		godot_monitor, "joy_connected", [0, StdInputDevice.DEVICE_TYPE_PS_4]
	)

	# When: Its configuration loads again using the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": true})

	# Then: The Godot monitor holds its virtual gamepad again.
	#
	# NOTE: Steam Input isn't running under test to list the controller.
	assert_engine_error(_STEAM_ERROR)
	assert_signal_emitted_with_parameters(godot_monitor, "joy_disconnected", [0])


func test_joypad_monitor_holds_a_disconnected_controllers_virtual_gamepad() -> void:
	# Given: A joypad monitor which holds Steam's virtual gamepads in a Godot one.
	var godot_monitor := _make_godot_joypad_monitor()
	var monitor := _make_joypad_monitor(godot_monitor)

	# Given: A Steam controller's virtual gamepad is open.
	godot_monitor.open(0, GodotJoypadMonitorTest.virtual_gamepad(7))

	# Given: The controller's configuration loaded without the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": false})
	watch_signals(godot_monitor)

	# When: Steam reports the controller disconnected before Godot closes its gamepad.
	monitor._on_device_disconnected(7)

	# Then: The Godot monitor reports the virtual gamepad disconnected.
	assert_signal_emitted_with_parameters(godot_monitor, "joy_disconnected", [0])

	# When: Godot closes it.
	godot_monitor.close(0)

	# Then: It isn't reported disconnected again.
	assert_signal_emit_count(godot_monitor, "joy_disconnected", 1)


func test_joypad_monitor_tracks_an_opt_out_without_a_godot_joypad_monitor() -> void:
	# Given: A joypad monitor without a Godot joypad monitor.
	var monitor := _make_joypad_monitor(null)

	# When: A controller's configuration loads without the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": false})

	# Then: The controller is opted out.
	assert_eq(monitor._opted_out, PackedInt64Array([7]))


func test_joypad_monitor_releases_a_virtual_gamepad_whose_binding_opts_out() -> void:
	# Given: A joypad monitor reading a controller binding without the game's actions.
	var godot_monitor := _make_godot_joypad_monitor()
	var binding := {"loaded": true, "actions": false}
	var monitor := _make_joypad_monitor_with_binding(godot_monitor, binding)

	# Given: The Godot monitor holds the controller's open virtual gamepad.
	godot_monitor.open(0, GodotJoypadMonitorTest.virtual_gamepad(7))
	watch_signals(godot_monitor)
	watch_signals(monitor)

	# When: Steam reports the controller connected before its configuration loads.
	monitor._on_device_connected(7)

	# Then: The Godot monitor reports its virtual gamepad, and this monitor doesn't.
	assert_signal_not_emitted(monitor, "joy_connected")
	assert_signal_emitted_with_parameters(
		godot_monitor, "joy_connected", [0, StdInputDevice.DEVICE_TYPE_PS_4]
	)


func test_joypad_monitor_keeps_an_opt_out_whose_configuration_binds_no_actions(
) -> void:
	# Given: A joypad monitor reading a controller binding without the game's actions.
	var godot_monitor := _make_godot_joypad_monitor()
	var binding := {"loaded": true, "actions": false}
	var monitor := _make_joypad_monitor_with_binding(godot_monitor, binding)

	# Given: The Godot monitor holds the controller's open virtual gamepad.
	godot_monitor.open(0, GodotJoypadMonitorTest.virtual_gamepad(7))

	# Given: The controller opted out once Steam reported it.
	monitor._on_device_connected(7)
	watch_signals(godot_monitor)
	watch_signals(monitor)

	# When: Its configuration loads using the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": true})

	# When: A frame later, Steam lists the controller.
	monitor._read_settling_bindings(Time.get_ticks_msec())
	monitor._connect_waiting_devices([7], Time.get_ticks_msec())

	# Then: The Godot monitor still reports the gamepad, and this monitor doesn't.
	assert_signal_not_emitted(godot_monitor, "joy_disconnected")
	assert_signal_not_emitted(monitor, "joy_connected")


func test_joypad_monitor_keeps_an_opt_out_while_its_binding_loads_again() -> void:
	# Given: A joypad monitor reading a controller binding without the game's actions.
	var godot_monitor := _make_godot_joypad_monitor()
	var binding := {"loaded": true, "actions": false}
	var monitor := _make_joypad_monitor_with_binding(godot_monitor, binding)

	# Given: The Godot monitor holds the controller's open virtual gamepad.
	godot_monitor.open(0, GodotJoypadMonitorTest.virtual_gamepad(7))

	# Given: The controller opted out once Steam reported it.
	monitor._on_device_connected(7)
	watch_signals(godot_monitor)

	# Given: Steam is loading the binding again.
	binding["loaded"] = false

	# When: The controller's configuration loads using the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": true})

	# Then: The Godot monitor still reports the virtual gamepad, and nothing waits.
	assert_signal_not_emitted(godot_monitor, "joy_disconnected")
	assert_true(monitor._waiting.is_empty())

	# When: A frame later, the binding loads without any of the game's actions.
	binding["loaded"] = true
	monitor._read_settling_bindings(Time.get_ticks_msec())

	# Then: The Godot monitor still reports the virtual gamepad, never dropping it.
	assert_signal_not_emitted(godot_monitor, "joy_disconnected")
	assert_signal_not_emitted(godot_monitor, "joy_connected")


func test_joypad_monitor_opts_in_a_configuration_opt_out_once_its_binding_loads(
) -> void:
	# Given: A joypad monitor reading a controller binding Steam hasn't loaded.
	var godot_monitor := _make_godot_joypad_monitor()
	var binding := {"loaded": false, "actions": true}
	var monitor := _make_joypad_monitor_with_binding(godot_monitor, binding)

	# Given: The Godot monitor holds the controller's open virtual gamepad.
	godot_monitor.open(0, GodotJoypadMonitorTest.virtual_gamepad(7))

	# Given: The controller's configuration loaded without the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": false})
	watch_signals(godot_monitor)

	# When: A configuration using the Steam Input API loads.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": true})

	# Then: The Godot monitor still reports the virtual gamepad.
	assert_signal_not_emitted(godot_monitor, "joy_disconnected")

	# When: A frame later, the binding loads with the game's actions.
	binding["loaded"] = true
	monitor._read_settling_bindings(Time.get_ticks_msec())

	# Then: The Godot monitor holds the virtual gamepad again.
	assert_signal_emitted_with_parameters(godot_monitor, "joy_disconnected", [0])

	# Then: The controller waits for Steam.
	assert_true(7 in monitor._waiting)


func test_joypad_monitor_reads_a_binding_again_after_its_configuration_loads() -> void:
	# Given: A joypad monitor reading a controller binding with the game's actions.
	var godot_monitor := _make_godot_joypad_monitor()
	var binding := {"loaded": true, "actions": true}
	var monitor := _make_joypad_monitor_with_binding(godot_monitor, binding)

	# Given: The Godot monitor holds the controller's open virtual gamepad.
	godot_monitor.open(0, GodotJoypadMonitorTest.virtual_gamepad(7))

	# Given: The joypad monitor connected the controller.
	monitor._on_device_connected(7)
	monitor._connect_waiting_devices([7], Time.get_ticks_msec())
	assert_engine_error(_STEAM_ERROR)
	assert_engine_error(_STEAM_ERROR)
	watch_signals(godot_monitor)
	watch_signals(monitor)

	# When: A new configuration loads while the binding still reports the previous one.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": true})

	# Then: The controller stays connected.
	#
	# NOTE: Steam Input isn't running under test to type the controller.
	assert_engine_error(_STEAM_ERROR)
	assert_signal_not_emitted(monitor, "joy_disconnected")

	# When: A frame later, the binding gives none of the game's actions an origin.
	binding["actions"] = false
	monitor._read_settling_bindings(Time.get_ticks_msec())

	# Then: The joypad monitor disconnects the controller.
	assert_signal_emitted_with_parameters(monitor, "joy_disconnected", [0])

	# Then: The Godot monitor reports its virtual gamepad.
	assert_signal_emitted_with_parameters(
		godot_monitor, "joy_connected", [0, StdInputDevice.DEVICE_TYPE_PS_4]
	)


func test_joypad_monitor_stops_reading_a_binding_once_it_settles() -> void:
	# Given: A joypad monitor reading a controller binding without the game's actions.
	var binding := {"loaded": true, "actions": false}
	var monitor := _make_joypad_monitor_with_binding(null, binding)

	# Given: It started reading the binding on each frame at launch.
	monitor._settle_binding(7, 0)

	# When: A frame passes just before the reads stop.
	monitor._read_settling_bindings(999)

	# Then: The binding is read again, and processing continues.
	assert_called_count(monitor._is_binding_opted_out, 2)
	assert_true(monitor.is_processing())

	# When: A frame passes once the reads stop.
	monitor._read_settling_bindings(1000)

	# Then: The binding isn't read, and nothing is processed each frame.
	assert_called_count(monitor._is_binding_opted_out, 2)
	assert_false(monitor.is_processing())


func test_joypad_monitor_reads_no_binding_after_a_configuration_opts_out() -> void:
	# Given: A joypad monitor reading a controller binding with the game's actions.
	var binding := {"loaded": true, "actions": true}
	var monitor := _make_joypad_monitor_with_binding(null, binding)

	# Given: The joypad monitor connected the controller.
	monitor._on_device_connected(7)
	monitor._connect_waiting_devices([7], Time.get_ticks_msec())
	assert_engine_error(_STEAM_ERROR)
	assert_engine_error(_STEAM_ERROR)

	# When: A configuration loads without the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": false})

	# When: A frame later, the binding still reports the previous configuration.
	monitor._read_settling_bindings(Time.get_ticks_msec())

	# Then: The controller stays opted out, and nothing is processed each frame.
	assert_eq(monitor._opted_out, PackedInt64Array([7]))
	assert_eq(monitor.get_slot_for_device_id(7), -1)
	assert_false(monitor.is_processing())


func test_joypad_monitor_reads_no_binding_once_a_configuration_opts_out_first() -> void:
	# Given: A joypad monitor reading a stale binding with the game's actions.
	var binding := {"loaded": true, "actions": true}
	var monitor := _make_joypad_monitor_with_binding(null, binding)

	# When: A configuration loads without the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": false})

	# When: Steam then reports the controller connected, as on a replug.
	monitor._on_device_connected(7)

	# When: A frame passes.
	monitor._read_settling_bindings(Time.get_ticks_msec())

	# Then: The controller stays opted out, and nothing is processed each frame.
	assert_eq(monitor._opted_out, PackedInt64Array([7]))
	assert_false(monitor.is_processing())


func test_joypad_monitor_stops_reading_the_binding_of_a_device_which_disconnects(
) -> void:
	# Given: A joypad monitor reading a controller binding with the game's actions.
	var binding := {"loaded": true, "actions": true}
	var monitor := _make_joypad_monitor_with_binding(null, binding)

	# Given: The joypad monitor connected the controller.
	monitor._on_device_connected(7)
	monitor._connect_waiting_devices([7], Time.get_ticks_msec())
	assert_engine_error(_STEAM_ERROR)
	assert_engine_error(_STEAM_ERROR)

	# When: The controller disconnects.
	monitor._on_device_disconnected(7)

	# When: A frame later, its binding reads as before.
	monitor._read_settling_bindings(Time.get_ticks_msec())

	# Then: It isn't waited for again, and nothing is processed each frame.
	assert_true(monitor._waiting.is_empty())
	assert_false(monitor.is_processing())


func test_joypad_monitor_waits_for_a_listed_device_until_its_binding_loads() -> void:
	# Given: A joypad monitor reading a controller binding Steam hasn't loaded.
	var binding := {"loaded": false, "actions": true}
	var monitor := _make_joypad_monitor_with_binding(null, binding)

	# Given: The joypad monitor waits for the controller.
	monitor._wait_for_device(7, 0)
	watch_signals(monitor)

	# When: Steam lists the controller.
	monitor._connect_waiting_devices([7], 16)

	# Then: The controller still waits, checked each frame.
	assert_signal_not_emitted(monitor, "joy_connected")
	assert_true(monitor.is_processing())

	# When: Steam loads its binding.
	binding["loaded"] = true
	monitor._connect_waiting_devices([7], 32)

	# Then: The controller takes slot 0.
	#
	# NOTE: Steam Input isn't running under test to type the controller.
	assert_engine_error(_STEAM_ERROR)
	assert_eq(monitor.get_slot_for_device_id(7), 0)


func test_joypad_monitor_opts_out_a_hot_plugged_device_once_its_binding_loads() -> void:
	# Given: A joypad monitor reading a controller binding Steam hasn't loaded.
	var godot_monitor := _make_godot_joypad_monitor()
	var binding := {"loaded": false, "actions": false}
	var monitor := _make_joypad_monitor_with_binding(godot_monitor, binding)

	# Given: The Godot monitor holds the hot-plugged controller's open virtual gamepad.
	godot_monitor.open(0, GodotJoypadMonitorTest.virtual_gamepad(7))
	watch_signals(godot_monitor)
	watch_signals(monitor)

	# When: The controller's configuration loads using the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": true})

	# When: Steam then reports the controller connected.
	monitor._on_device_connected(7)

	# Then: The Godot monitor still holds the virtual gamepad.
	#
	# NOTE: Steam Input isn't running under test to list the controller.
	assert_engine_error(_STEAM_ERROR)
	assert_engine_error(_STEAM_ERROR)
	assert_signal_not_emitted(godot_monitor, "joy_connected")

	# When: A frame later, the binding loads without any of the game's actions.
	binding["loaded"] = true
	monitor._read_settling_bindings(Time.get_ticks_msec())

	# When: Steam lists the controller.
	monitor._connect_waiting_devices([7], Time.get_ticks_msec())

	# Then: The Godot monitor reports its virtual gamepad, and this monitor doesn't.
	assert_signal_emitted_with_parameters(
		godot_monitor, "joy_connected", [0, StdInputDevice.DEVICE_TYPE_PS_4]
	)
	assert_signal_not_emitted(monitor, "joy_connected")


func test_joypad_monitor_waits_for_a_new_device_whose_binding_is_loading() -> void:
	# Given: A joypad monitor reading a controller binding Steam hasn't loaded.
	var binding := {"loaded": false, "actions": true}
	var monitor := _make_joypad_monitor_with_binding(null, binding)

	# When: Its configuration loads using the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": true})

	# Then: The controller waits for Steam.
	#
	# NOTE: Steam Input isn't running under test to list it.
	assert_engine_error(_STEAM_ERROR)
	assert_true(7 in monitor._waiting)


func test_joypad_monitor_follows_each_configuration_without_action_sets() -> void:
	# Given: A joypad monitor without the game's action sets.
	var monitor := _make_joypad_monitor(null)

	# Given: A controller's configuration loaded without the Steam Input API.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": false})

	# When: A configuration using the Steam Input API loads.
	monitor._on_configuration_loaded(480, 7, {"uses_steam_input_api": true})

	# Then: The controller opts in, waiting for Steam.
	#
	# NOTE: Steam Input isn't running under test to list it.
	assert_engine_error(_STEAM_ERROR)
	assert_eq(monitor._opted_out, PackedInt64Array())
	assert_true(7 in monitor._waiting)


func test_joypad_monitor_reads_no_binding_without_action_sets() -> void:
	# Given: A joypad monitor without the game's action sets.
	var monitor := _make_joypad_monitor(null)

	# When: Steam reports a controller.
	monitor._settle_binding(7, 0)

	# Then: Its binding can't be read, so it isn't read on each frame.
	#
	# NOTE: Reading it would raise an engine error, since Steam Input isn't running.
	assert_false(monitor._can_read_binding(7))
	assert_true(monitor._settling.is_empty())
	assert_false(monitor.is_processing())


func test_joypad_monitor_cannot_read_a_binding_steam_has_not_loaded() -> void:
	# Given: A joypad monitor with the game's action sets.
	var monitor := _make_joypad_monitor(null)
	var action_sets: Array[StdInputActionSet] = [_make_action_set(&"Menu")]
	action_sets[0].actions_digital = [&"ui_accept"]
	monitor.action_sets = action_sets

	# When/Then: A controller's binding can't be read before Steam loads it.
	#
	# NOTE: Steam Input isn't running under test, so no binding loads.
	assert_false(monitor._can_read_binding(7))
	assert_engine_error(_STEAM_ERROR)


func test_joypad_monitor_names_action_sets_as_the_manifest_does() -> void:
	# Given: Two sets, a layer under one of them, and a layer with no parent.
	var menu := _make_action_set(&"Menu")
	var options := _make_action_set(&"MenuOptions", true) as StdInputActionSetLayer
	options.parent = menu
	var navigation := _make_action_set(&"MenuNavigation", true)
	var action_sets: Array[StdInputActionSet] = [
		menu, _make_action_set(&"Splash"), options, navigation
	]

	# When/Then: A set and a layer with a parent keep their names.
	assert_eq(
		_joypad_monitor._list_manifest_names(menu, action_sets),
		PackedStringArray(["Menu"]),
	)
	assert_eq(
		_joypad_monitor._list_manifest_names(options, action_sets),
		PackedStringArray(["MenuOptions"]),
	)

	# When/Then: A layer with no parent is named under each set.
	assert_eq(
		_joypad_monitor._list_manifest_names(navigation, action_sets),
		PackedStringArray(["MenuNavigation_Menu", "MenuNavigation_Splash"]),
	)


func test_joypad_monitor_does_not_match_a_virtual_gamepad_by_index() -> void:
	# Given: A joypad monitor which connected one device.
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor._connected = PackedInt64Array([7])

	# When/Then: Godot's joypad 0 isn't a virtual gamepad, though slot 0 is connected.
	assert_false(monitor._is_virtual_gamepad(0))


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


## _make_godot_joypad_monitor returns a Godot joypad monitor whose open joypads are
## faked.
func _make_godot_joypad_monitor() -> GodotJoypadMonitorTest.JoypadMonitor:
	return autofree(GodotJoypadMonitorTest.JoypadMonitor.new())


## _make_action_set returns an action set called `action_set_name`, or a layer if
## `is_layer` is set.
func _make_action_set(
	action_set_name: StringName, is_layer: bool = false
) -> StdInputActionSet:
	var action_set: StdInputActionSet = (
		StdInputActionSetLayer.new() if is_layer else StdInputActionSet.new()
	)
	action_set.name = action_set_name
	return action_set


## _make_joypad_monitor returns an instance of `script`, or of the monitor, which holds
## Steam's virtual gamepads in `godot_monitor`, when it's set, as it does once Steam
## Input starts. It isn't added to the scene, since entering it needs Steam Input.
func _make_joypad_monitor(
	godot_monitor: StdInputSlot.JoypadMonitor,
	script: Script = null,
) -> StdInputSlot.JoypadMonitor:
	var monitor: StdInputSlot.JoypadMonitor = autofree(
		(script if script else _joypad_monitor).new()
	)
	monitor.steam_input_enabled_property = _make_steam_input_enabled_property()
	monitor.godot_joypad_monitor = godot_monitor
	monitor._hold_virtual_gamepads()
	return monitor


## _make_joypad_monitor_with_binding returns a joypad monitor, as `_make_joypad_monitor`
## does, with an action set. Every binding it reads has loaded while the `loaded` key of
## `binding` is set, and gives the game's actions an origin while `actions` is set.
func _make_joypad_monitor_with_binding(
	godot_monitor: StdInputSlot.JoypadMonitor, binding: Dictionary
) -> StdInputSlot.JoypadMonitor:
	var monitor := _make_joypad_monitor(godot_monitor, partial_double(_joypad_monitor))
	var action_sets: Array[StdInputActionSet] = [_make_action_set(&"Menu")]
	monitor.action_sets = action_sets

	stub(monitor, "_can_read_binding").to_call(
		func(_device: int) -> bool: return binding["loaded"]
	)
	stub(monitor, "_is_binding_opted_out").to_call(
		func(_device: int) -> bool: return not binding["actions"]
	)

	return monitor


## _make_steam_input_enabled_property returns a property for the monitor to toggle, in a
## new scope which isn't loaded yet.
func _make_steam_input_enabled_property() -> StdSettingsPropertyBool:
	var property := StdSettingsPropertyBool.new()
	property.scope = StdSettingsScope.new()
	property.category = &"test"
	property.name = &"steam_input_enabled"
	return property
