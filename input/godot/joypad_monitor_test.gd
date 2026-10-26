##
## std/input/godot/joypad_monitor_test.gd
##
## Tests pertaining to the Godot implementation of `StdInputSlot.JoypadMonitor`. The
## Steam joypad monitor's tests build theirs with `JoypadMonitor`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GodotJoypadMonitor := preload("joypad_monitor.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## JOYPAD_NAME is the name every faked joypad reports, which maps to `DEVICE_TYPE_PS_4`.
const JOYPAD_NAME := "PS4 Controller"


## JoypadMonitor is the Godot joypad monitor with Godot's open joypads faked, since no
## joypad can be opened under test.
class JoypadMonitor:
	extends GodotJoypadMonitor

	## joypads maps the device ID of each open joypad to the info Godot reports for it.
	var joypads: Dictionary[int, Dictionary] = {}

	## close closes the joypad `device`, reporting it as Godot does.
	func close(device: int) -> void:
		joypads.erase(device)
		_on_Input_joy_connection_changed(device, false)

	## open opens the joypad `device` with joypad info `info`, reporting it as Godot does.
	func open(device: int, info: Dictionary) -> void:
		joypads[device] = info
		_on_Input_joy_connection_changed(device, true)

	func _get_joy_info(device: int) -> Dictionary:
		return joypads[device]

	func _get_joy_name(_device: int) -> String:
		return JOYPAD_NAME

	func _list_joypads() -> Array[int]:
		var devices: Array[int] = []
		devices.assign(joypads.keys())
		return devices


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## virtual_gamepad returns the info Godot reports for the virtual gamepad Steam runs for
## the controller with Steam handle `handle`.
static func virtual_gamepad(handle: int) -> Dictionary:
	return {"steam_input_index": str(handle)}


# -- TEST METHODS -------------------------------------------------------------------- #


func test_joypad_monitor_reports_a_virtual_gamepad_without_a_hold() -> void:
	# Given: A joypad monitor which isn't holding Steam's virtual gamepads.
	var monitor: JoypadMonitor = autofree(JoypadMonitor.new())
	watch_signals(monitor)

	# When: The virtual gamepad of a Steam controller opens.
	monitor.open(0, virtual_gamepad(7))

	# Then: It's reported connected.
	assert_signal_emitted_with_parameters(
		monitor, "joy_connected", [0, StdInputDevice.DEVICE_TYPE_PS_4]
	)


func test_joypad_monitor_holds_a_virtual_gamepad_which_opens_during_a_hold() -> void:
	# Given: A joypad monitor holding Steam's virtual gamepads.
	var monitor: JoypadMonitor = autofree(JoypadMonitor.new())
	monitor.hold_steam_virtual_gamepads(PackedInt64Array())
	watch_signals(monitor)

	# When: The virtual gamepad of a Steam controller opens.
	monitor.open(0, virtual_gamepad(7))

	# Then: It isn't reported.
	assert_signal_not_emitted(monitor, "joy_connected")

	# When: A joypad Steam doesn't drive opens.
	monitor.open(1, {"vendor_id": "1356"})

	# Then: Only that joypad is reported.
	assert_signal_emit_count(monitor, "joy_connected", 1)
	assert_signal_emitted_with_parameters(
		monitor, "joy_connected", [1, StdInputDevice.DEVICE_TYPE_PS_4]
	)


func test_joypad_monitor_reports_a_virtual_gamepad_as_the_hold_changes() -> void:
	# Given: A joypad monitor which reported an open virtual gamepad.
	var monitor: JoypadMonitor = autofree(JoypadMonitor.new())
	monitor.open(0, virtual_gamepad(7))
	watch_signals(monitor)

	# When: The monitor starts holding Steam's virtual gamepads.
	monitor.hold_steam_virtual_gamepads(PackedInt64Array())

	# Then: The virtual gamepad is reported disconnected.
	assert_signal_emitted_with_parameters(monitor, "joy_disconnected", [0])

	# When: The hold releases the virtual gamepad's controller.
	monitor.hold_steam_virtual_gamepads(PackedInt64Array([7]))

	# Then: The virtual gamepad is reported connected.
	assert_signal_emitted_with_parameters(
		monitor, "joy_connected", [0, StdInputDevice.DEVICE_TYPE_PS_4]
	)

	# When: The hold releases the same controller again.
	monitor.hold_steam_virtual_gamepads(PackedInt64Array([7]))

	# Then: Nothing more is reported.
	assert_signal_emit_count(monitor, "joy_connected", 1)
	assert_signal_emit_count(monitor, "joy_disconnected", 1)


func test_joypad_monitor_does_not_report_a_held_joypads_disconnect() -> void:
	# Given: A joypad monitor holding an open virtual gamepad.
	var monitor: JoypadMonitor = autofree(JoypadMonitor.new())
	monitor.hold_steam_virtual_gamepads(PackedInt64Array())
	monitor.open(0, virtual_gamepad(7))
	watch_signals(monitor)

	# When: The virtual gamepad closes.
	monitor.close(0)

	# Then: It isn't reported disconnected.
	assert_signal_not_emitted(monitor, "joy_disconnected")

	# When: A joypad Steam doesn't drive opens under the same device ID.
	monitor.open(0, {"vendor_id": "1356"})

	# Then: It's reported connected.
	assert_signal_emitted_with_parameters(
		monitor, "joy_connected", [0, StdInputDevice.DEVICE_TYPE_PS_4]
	)


func test_joypad_monitor_broadcast_skips_held_joypads() -> void:
	# Given: A joypad monitor holding an open virtual gamepad beside a joypad Steam
	# doesn't drive.
	var monitor: JoypadMonitor = autofree(JoypadMonitor.new())
	monitor.joypads[0] = virtual_gamepad(7)
	monitor.joypads[1] = {"vendor_id": "1356"}
	monitor.hold_steam_virtual_gamepads(PackedInt64Array())
	watch_signals(monitor)

	# When: The connected joypads are broadcast.
	monitor.broadcast_connected_joypads()

	# Then: Only the joypad Steam doesn't drive is reported.
	assert_signal_emit_count(monitor, "joy_connected", 1)
	assert_signal_emitted_with_parameters(
		monitor, "joy_connected", [1, StdInputDevice.DEVICE_TYPE_PS_4]
	)


func test_joypad_monitor_release_reports_every_held_joypad() -> void:
	# Given: A joypad monitor holding two open virtual gamepads.
	var monitor: JoypadMonitor = autofree(JoypadMonitor.new())
	monitor.hold_steam_virtual_gamepads(PackedInt64Array())
	monitor.open(0, virtual_gamepad(7))
	monitor.open(1, virtual_gamepad(9))
	watch_signals(monitor)

	# When: The hold ends.
	monitor.release_steam_virtual_gamepads()

	# Then: Both are reported connected.
	assert_signal_emit_count(monitor, "joy_connected", 2)

	# When: Another virtual gamepad opens.
	monitor.open(2, virtual_gamepad(11))

	# Then: It's reported connected.
	assert_signal_emit_count(monitor, "joy_connected", 3)


func test_joypad_monitor_reads_a_virtual_gamepads_steam_handle() -> void:
	# When/Then: The Steam handle SDL records for a virtual gamepad is read back.
	#
	# NOTE: The joypad info is as hardware reported it on 2026-10-24.
	assert_eq(
		GodotJoypadMonitor.get_steam_handle({"steam_input_index": "176657670040285"}),
		176657670040285,
	)

	# When/Then: A joypad Steam doesn't drive has no handle.
	assert_eq(GodotJoypadMonitor.get_steam_handle({"vendor_id": "1356"}), 0)
