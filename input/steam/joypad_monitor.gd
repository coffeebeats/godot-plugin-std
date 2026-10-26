##
## std/input/steam/joypad_monitor.gd
##
## An implementation of `StdInputSlot.JoypadMonitor` that uses the Steam Input API.
##
## NOTE: This implementation requires the `GodotSteam` extension as a peer dependency.
##

extends StdInputSlot.JoypadMonitor

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../../event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _LIST_TIMEOUT_MSEC is how long a device Steam reported waits for Steam to list it
## before it connects anyway, since Valve doesn't document whether one can remain
## unlisted.
const _LIST_TIMEOUT_MSEC := 1000

# -- CONFIGURATION ------------------------------------------------------------------- #

## steam_input_enabled_property is a settings property the joypad monitor turns on while
## a controller whose configuration uses the Steam Input API is connected, and off
## otherwise.
@export var steam_input_enabled_property: StdSettingsPropertyBool = null

# -- INITIALIZATION ------------------------------------------------------------------ #

## _connected holds the device handle in each slot, or `0` for a slot whose device
## disconnected; it never ends in `0`.
var _connected := PackedInt64Array()

var _logger := StdLogger.create("std/input/steam/joypad-monitor").with_process_frame()

## _opted_out holds the handle of each device whose configuration doesn't use the Steam
## Input API, so a later connect report doesn't connect it.
var _opted_out := PackedInt64Array()

## _types holds the Steam Input type read as each connected device connected. Valve
## documents the type as the controller's model, so it's read once per connection.
var _types: Dictionary[int, int] = {}

## _waiting holds the time, in milliseconds since launch, at which Steam first reported
## each device it doesn't list yet. Steam's callbacks can arrive before it lists the
## device, and until then it reports no type for it.
var _waiting: Dictionary[int, int] = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_device_id_for_slot returns the input device handle at the specified "slot" index,
## or `-1` when no connected device occupies it.
func get_device_id_for_slot(slot: int) -> int:
	if slot < 0 or slot >= _connected.size() or not _connected[slot]:
		return -1

	return _connected[slot]


## get_device_type maps a Steam Input device type to the `StdInputDevice` family it
## belongs to; types without a family of their own are generic.
static func get_device_type(input_type: int) -> StdInputDevice.DeviceType:
	match input_type:
		Steam.INPUT_TYPE_STEAM_CONTROLLER:
			return StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER
		Steam.INPUT_TYPE_STEAM_DECK_CONTROLLER:
			return StdInputDevice.DEVICE_TYPE_STEAM_DECK

		Steam.INPUT_TYPE_PS3_CONTROLLER, Steam.INPUT_TYPE_PS4_CONTROLLER:
			return StdInputDevice.DEVICE_TYPE_PS_4
		Steam.INPUT_TYPE_PS5_CONTROLLER:
			return StdInputDevice.DEVICE_TYPE_PS_5

		Steam.INPUT_TYPE_SWITCH_JOYCON_PAIR:
			return StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_PAIR
		Steam.INPUT_TYPE_SWITCH_JOYCON_SINGLE:
			return StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_SINGLE
		Steam.INPUT_TYPE_SWITCH_PRO_CONTROLLER:
			return StdInputDevice.DEVICE_TYPE_SWITCH_PRO

		Steam.INPUT_TYPE_MOBILE_TOUCH:
			return StdInputDevice.DEVICE_TYPE_TOUCH

		Steam.INPUT_TYPE_XBOX360_CONTROLLER:
			return StdInputDevice.DEVICE_TYPE_XBOX_360
		Steam.INPUT_TYPE_XBOXONE_CONTROLLER:
			return StdInputDevice.DEVICE_TYPE_XBOX_ONE

	return StdInputDevice.DEVICE_TYPE_GENERIC


## get_slot_for_device_id returns the "slot" index of the specified input device handle,
## or `-1` when the device isn't connected.
##
## NOTE: A device keeps its slot until it disconnects, and a new device takes the lowest
## free slot, as Godot numbers joypads.
func get_slot_for_device_id(device: int) -> int:
	return _connected.find(device) if device else -1


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	Signals.connect_safe(Steam.input_device_connected, _on_device_connected)
	Signals.connect_safe(Steam.input_device_disconnected, _on_device_disconnected)
	Signals.connect_safe(Steam.input_configuration_loaded, _on_configuration_loaded)

	if not Steam.inputInit():
		assert(false, "failed to initialize Steam Input")
		return

	Steam.enableActionEventCallbacks()

	# NOTE: Enabling device callbacks reports each controller already connected, so a
	# controller plugged in at launch connects without waiting for input.
	Steam.enableDeviceCallbacks()

	_logger.info("Initialized Steam Input API.")


func _exit_tree() -> void:
	Steam.inputShutdown()

	Signals.disconnect_safe(Steam.input_configuration_loaded, _on_configuration_loaded)
	Signals.disconnect_safe(Steam.input_device_connected, _on_device_connected)
	Signals.disconnect_safe(Steam.input_device_disconnected, _on_device_disconnected)

	_logger.info("Shut down Steam Input API.")


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return

	# NOTE: Raw joypad events arrive many times a frame, so the joypad's info isn't
	# looked up while no Steam controller is connected.
	if _connected.is_empty():
		return

	# NOTE: Godot opens the virtual gamepad Steam runs for a layout binding a gamepad
	# button; its controller's input arrives as Steam actions, so its events are dropped.
	# A controller waiting for Steam to list it isn't in `_connected` and publishes no
	# Steam actions until it connects, so its virtual gamepad's events pass through as
	# its only input.
	if _is_virtual_gamepad(event.device):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_poll_waiting_devices()


func _ready() -> void:
	# NOTE: Processing runs only while a device waits for Steam to list it.
	set_process(not _waiting.is_empty())


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _broadcast_connected_joypads() -> void:
	for slot in _connected.size():
		var device := _connected[slot]
		if not device:
			continue

		# NOTE: The type is reported here too, so a pad connected before a slot listened
		# gets its family's glyphs rather than generic ones.
		var input_type: int = _types.get(device, Steam.INPUT_TYPE_UNKNOWN)
		joy_connected.emit(slot, get_device_type(input_type))


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _claim_slot places `device` in the lowest free slot and returns that slot.
func _claim_slot(device: int) -> int:
	var slot := _connected.find(0)
	if slot == -1:
		slot = _connected.size()
		_connected.append(device)
	else:
		_connected[slot] = device

	return slot


func _connect_device(device: int) -> void:
	if device in _connected:
		assert(false, "invalid argument: duplicate device")
		return

	var input_type := Steam.getInputTypeForHandle(device)
	var device_type := get_device_type(input_type)

	_logger.info("Joypad connected.", {&"device": device, &"type": device_type})

	_types[device] = input_type

	# NOTE: The property is set first, so Steam-backed components handle the
	# notifications that follow.
	steam_input_enabled_property.set_value(true)

	joy_connected.emit(_claim_slot(device), device_type)


## _connect_waiting_devices connects each waiting device which Steam lists in `listed`,
## or which has waited `_LIST_TIMEOUT_MSEC` by `now`, in milliseconds since launch.
## Processing runs while any device still waits.
func _connect_waiting_devices(listed: Array, now: int) -> void:
	for device: int in _waiting.keys():
		var waited: int = now - _waiting[device]

		if device not in listed:
			if waited < _LIST_TIMEOUT_MSEC:
				continue

			# NOTE: A controller which does nothing is worse than one with the wrong
			# glyphs.
			(
				_logger
				. warn(
					"Joypad unlisted by Steam; connecting it anyway.",
					{&"device": device, &"waited_msec": waited},
				)
			)

		_waiting.erase(device)
		_connect_device(device)

	set_process(not _waiting.is_empty())


func _disconnect_device(device: int) -> void:
	if device not in _connected:
		assert(false, "invalid argument: missing device")
		return

	_logger.info("Joypad disconnected.", {&"device": device})

	# NOTE: The slot is emptied rather than removed, so no other device's slot changes
	# under the components which keep state per slot.
	var slot := _connected.find(device)
	_connected[slot] = 0
	_types.erase(device)

	while _connected and not _connected[_connected.size() - 1]:
		_connected.resize(_connected.size() - 1)

	joy_disconnected.emit(slot)

	if not _connected:
		steam_input_enabled_property.set_value(false)


## _get_steam_handle returns the Steam handle of the controller behind a joypad whose
## info Godot reports as `info`, or `0` for a joypad Steam doesn't drive. Godot's SDL
## driver records the handle, as a string, for each virtual gamepad Steam runs.
static func _get_steam_handle(info: Dictionary) -> int:
	return String(info.get("steam_input_index", "")).to_int()


## _has_connected_type returns whether the connected `device` connected with Steam
## Input type `input_type`.
func _has_connected_type(device: int, input_type: int) -> bool:
	return device in _types and _types[device] == input_type


## _is_virtual_gamepad returns whether Godot's joypad `device` is the virtual gamepad
## Steam runs for a controller this monitor connected. It's matched by Steam handle,
## since SDL reports the physical controller's vendor and product IDs for it.
func _is_virtual_gamepad(device: int) -> bool:
	# NOTE: An injected event can name a joypad Godot hasn't opened, whose info would
	# raise an error.
	if device not in Input.get_connected_joypads():
		return false

	var handle := _get_steam_handle(Input.get_joy_info(device))

	return handle != 0 and handle in _connected


## _poll_waiting_devices connects each waiting device Steam now lists. Steam's list is
## read only while a device waits, since GodotSteam prints a line on each read.
func _poll_waiting_devices() -> void:
	var listed: Array = Steam.getConnectedControllers() if _waiting else []
	_connect_waiting_devices(listed, Time.get_ticks_msec())


## _wait_for_device starts waiting for Steam to list `device`, which Steam reported at
## `now` in milliseconds since launch, unless it's connected, waiting or opted out.
func _wait_for_device(device: int, now: int) -> void:
	if device in _connected or device in _opted_out or device in _waiting:
		return

	_waiting[device] = now


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_configuration_loaded(app: int, device: int, cfg: Dictionary) -> void:
	(
		_logger
		. info(
			"Steam Input configuration loaded.",
			{&"app": app, &"device": device, &"cfg": str(cfg)},
		)
	)

	var uses_steam_input_api: bool = cfg.get("uses_steam_input_api", true)

	var opted_out_index := _opted_out.find(device)
	if uses_steam_input_api and opted_out_index != -1:
		_opted_out.remove_at(opted_out_index)
	elif not uses_steam_input_api and opted_out_index == -1:
		_opted_out.append(device)

	if not uses_steam_input_api:
		_waiting.erase(device)

		if device in _connected:
			_disconnect_device(device)

	elif device in _connected:
		# NOTE: Valve documents a controller's type as its model, so a type which
		# changes on a live handle is logged rather than applied.
		var input_type := Steam.getInputTypeForHandle(device)
		if not _has_connected_type(device, input_type):
			(
				_logger
				. warn(
					"Steam reports a new type for a connected joypad.",
					{
						&"device": device,
						&"type": input_type,
						&"connected_type": _types.get(device),
					},
				)
			)

	else:
		_wait_for_device(device, Time.get_ticks_msec())

	_poll_waiting_devices()


func _on_device_connected(device: int) -> void:
	# NOTE: A configuration load can report the device first, or report first that
	# the device doesn't use the Steam Input API, as on a replug.
	_wait_for_device(device, Time.get_ticks_msec())
	_poll_waiting_devices()


func _on_device_disconnected(device: int) -> void:
	# NOTE: The device's configuration is loaded again when it reconnects.
	var opted_out_index := _opted_out.find(device)
	if opted_out_index != -1:
		_opted_out.remove_at(opted_out_index)

	_waiting.erase(device)

	# NOTE: A configuration which doesn't use the Steam Input API can disconnect the
	# device first.
	if device in _connected:
		_disconnect_device(device)

	_poll_waiting_devices()
