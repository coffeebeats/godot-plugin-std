##
## std/input/steam/joypad_monitor.gd
##
## An implementation of `StdInputSlot.JoypadMonitor` that uses the Steam Input API.
##
## NOTE: This implementation depends on the `GodotSteam` extension being installed as a
## peer dependency. This script will not work without it.
##

extends StdInputSlot.JoypadMonitor

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## steam_input_enabled_property is a settings property that the joypad monitor will
## toggle based on connected controller activity.
##
## NOTE: It unfortunately seems that the only way to check for whether Steam Input is in
## use is by the presence of a connected joypad. As such, this property will be enabled
## when devices are connected and disabled otherwise.
@export var steam_input_enabled_property: StdSettingsPropertyBool = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _connected := PackedInt64Array()

var _logger := StdLogger.create("std/input/steam/joypad-monitor").with_process_frame()

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_device_id_for_slot returns the input device handle at the specified "slot" index.
func get_device_id_for_slot(slot: int) -> int:
	return _connected[slot] if (slot >= 0 and slot < _connected.size()) else 0


## get_slot_for_device_id returns the "slot" index of the specified input device handle.
func get_slot_for_device_id(device: int) -> int:
	return Steam.getConnectedControllers().find(device)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	# NOTE: Ensure this node can always process callbacks.
	process_mode = Node.PROCESS_MODE_ALWAYS

	Signals.connect_safe(Steam.input_action_event, _on_action_event)
	Signals.connect_safe(Steam.input_gamepad_slot_change, _on_gamepad_slot_change)
	Signals.connect_safe(Steam.input_device_disconnected, _on_device_disconnected)
	Signals.connect_safe(Steam.input_configuration_loaded, _on_configuration_loaded)

	if not Steam.inputInit():
		assert(false, "failed to initialize Steam Input")
		return

	Steam.enableActionEventCallbacks()
	Steam.enableDeviceCallbacks()

	_logger.info("Initialized Steam Input API.")


func _exit_tree() -> void:
	Steam.inputShutdown()

	Signals.disconnect_safe(Steam.input_action_event, _on_action_event)
	Signals.disconnect_safe(Steam.input_configuration_loaded, _on_configuration_loaded)
	Signals.disconnect_safe(Steam.input_device_disconnected, _on_device_disconnected)
	Signals.disconnect_safe(Steam.input_gamepad_slot_change, _on_gamepad_slot_change)

	_logger.info("Shut down Steam Input API.")


func _input(event: InputEvent) -> void:
	var is_joy_button: bool = event is InputEventJoypadButton
	var is_joy_motion: bool = event is InputEventJoypadMotion

	if not (is_joy_motion or is_joy_button) or _connected.is_empty():
		return

	if event.device >= 0 and event.device < _connected.size():
		get_viewport().set_input_as_handled()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _broadcast_connected_joypads() -> void:
	for device in _connected:
		var slot: int = get_slot_for_device_id(device)
		if slot == -1:
			assert(false, "invalid argument; failed to find slot for device")
			continue

		joy_connected.emit(slot)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _connect_device(device: int) -> void:
	# FIXME(https://github.com/godotengine/godot/issues/100580): Revert to `in`.
	if _connected.has(device):
		assert(false, "invalid argument: duplicate device")
		return

	var device_type := StdInputDevice.DEVICE_TYPE_GENERIC

	match Steam.getInputTypeForHandle(device):
		Steam.INPUT_TYPE_STEAM_CONTROLLER:
			device_type = StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER
		Steam.INPUT_TYPE_STEAM_DECK_CONTROLLER:
			device_type = StdInputDevice.DEVICE_TYPE_STEAM_DECK

		Steam.INPUT_TYPE_PS3_CONTROLLER, Steam.INPUT_TYPE_PS4_CONTROLLER:
			device_type = StdInputDevice.DEVICE_TYPE_PS_4
		Steam.INPUT_TYPE_PS5_CONTROLLER:
			device_type = StdInputDevice.DEVICE_TYPE_PS_5

		Steam.INPUT_TYPE_SWITCH_JOYCON_PAIR:
			device_type = StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_PAIR
		Steam.INPUT_TYPE_SWITCH_JOYCON_SINGLE:
			device_type = StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_SINGLE
		Steam.INPUT_TYPE_SWITCH_PRO_CONTROLLER:
			device_type = StdInputDevice.DEVICE_TYPE_SWITCH_PRO

		Steam.INPUT_TYPE_MOBILE_TOUCH:
			device_type = StdInputDevice.DEVICE_TYPE_TOUCH

		Steam.INPUT_TYPE_XBOX360_CONTROLLER:
			device_type = StdInputDevice.DEVICE_TYPE_XBOX_360
		Steam.INPUT_TYPE_XBOXONE_CONTROLLER:
			device_type = StdInputDevice.DEVICE_TYPE_XBOX_ONE

	_logger.info("Joypad connected.", {&"device": device, &"type": device_type})

	var slot: int = get_slot_for_device_id(device)
	if slot == -1:
		assert(false, "invalid argument; failed to find slot for device")
		return

	# Update this property first so that subsequent notifications are handled by Steam-
	# backed components.
	steam_input_enabled_property.set_value(true)

	_connected.append(device)
	joy_connected.emit(slot, device_type)


func _disconnect_device(device: int) -> void:
	# FIXME(https://github.com/godotengine/godot/issues/100580): Revert to `in`.
	if not _connected.has(device):
		assert(false, "invalid argument: missing device")
		return

	_logger.info("Joypad disconnected.", {&"device": device})

	var index := _connected.find(device)
	assert(index >= 0, "invalid state; missing device")

	var slot: int = _connected.find(device)
	if slot == -1:
		assert(false, "invalid argument; failed to find slot for device")
		return

	_connected.remove_at(index)
	joy_disconnected.emit(slot)

	if not _connected:
		steam_input_enabled_property.set_value(false)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_action_event(
	device: int,
	event_type: Steam.InputActionEventType,
	_action_handle: int,
	_is_active: bool,
	action_data: Dictionary,
) -> void:
	# FIXME(https://github.com/godotengine/godot/issues/100580): Revert to `in`.
	if not _connected.has(device):
		match event_type:
			Steam.INPUT_ACTION_EVENT_TYPE_ANALOG_ACTION:
				if not action_data["x"] and not action_data["y"]:
					return
			Steam.INPUT_ACTION_EVENT_TYPE_DIGITAL_ACTION:
				if not action_data["state"]:
					return

		_connect_device(device)
		return


func _on_configuration_loaded(app: int, device: int, cfg: Dictionary) -> void:
	(
		_logger
		. info(
			"Steam Input configuration loaded.",
			{&"app": app, &"device": device, &"cfg": str(cfg)},
		)
	)

	var uses_steam_input_api: bool = cfg.get("uses_steam_input_api", true)
	var device_in_connected := _connected.has(device)

	if not uses_steam_input_api and device_in_connected:
		_disconnect_device(device)
	elif uses_steam_input_api and not device_in_connected:
		_connect_device(device)


func _on_device_disconnected(device: int) -> void:
	_disconnect_device(device)


func _on_gamepad_slot_change(
	_app: int,
	device: int,
	_device_type: int,
	slot_prev: int,
	slot_next: int,
) -> void:
	# FIXME(https://github.com/godotengine/godot/issues/100580): Revert to `in`.
	if not _connected.has(device):
		assert(false, "invalid argument: unknown device")
		return

	if slot_prev >= _connected.size():
		assert(false, "invalid argument: unknown slot index")
		return

	if slot_next >= _connected.size():
		assert(false, "invalid argument: unknown slot index")
		return

	_connected[slot_prev] = _connected[slot_next]
	_connected[slot_next] = device

	var connected_godot := Input.get_connected_joypads()
	if slot_prev >= connected_godot.size() or slot_next >= connected_godot.size():
		assert(false, "invalid argument: unknown slot index")
		return
