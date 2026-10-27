##
## std/input/steam/joypad_monitor.gd
##
## An implementation of `StdInputSlot.JoypadMonitor` that uses the Steam Input API.
##
## NOTE: This implementation requires the `GodotSteam` extension as a peer dependency.
##

extends StdInputSlot.JoypadMonitor

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GodotJoypadMonitor := preload("../godot/joypad_monitor.gd")
const Signals := preload("../../event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _BINDING_SETTLE_MSEC is how long a device's binding is read again on each frame after
## Steam reports the device or loads a configuration for it, since its origins can
## report the previous configuration for a few frames, which Valve doesn't document.
const _BINDING_SETTLE_MSEC := 1000

## _LIST_TIMEOUT_MSEC is how long a device Steam reported waits for Steam to list it and
## load its binding before it connects anyway, since Valve doesn't document whether one
## can remain unlisted.
const _LIST_TIMEOUT_MSEC := 1000

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_sets are the game's action sets and layers, every one its Steam Input manifest
## lists. A controller uses the Steam Input API only while its binding gives one of
## their actions an origin, or as its configuration reports while this is empty.
##
## NOTE: A set left out can make a controller whose binding gives only that set's
## actions an origin look opted out, so it gets no Steam actions.
@export var action_sets: Array[StdInputActionSet] = []

## godot_joypad_monitor is an optional Godot joypad monitor, which this one has stop
## reporting Steam's virtual gamepads once Steam Input starts, except for a controller
## whose configuration opts out, so each controller reaches a slot through one monitor.
##
## NOTE: This monitor refers to the Godot one, rather than the reverse, since the Godot
## monitor loads without the GodotSteam extension.
@export var godot_joypad_monitor: StdInputSlot.JoypadMonitor = null

## steam_input_enabled_property is a settings property the joypad monitor turns on while
## a controller whose configuration uses the Steam Input API is connected, and off
## otherwise.
@export var steam_input_enabled_property: StdSettingsPropertyBool = null

# -- INITIALIZATION ------------------------------------------------------------------ #

## _connected holds the device handle in each slot, or `0` for a slot whose device
## disconnected; it never ends in `0`.
var _connected := PackedInt64Array()

var _logger := StdLogger.create("std/input/steam/joypad-monitor").with_process_frame()

## _opted_out holds the handle of each device whose binding or configuration opts out of
## the Steam Input API, so a later connect report doesn't connect it and
## `godot_joypad_monitor` reports its virtual gamepad instead.
var _opted_out := PackedInt64Array()

## _settling maps each device whose binding is read on each frame to the time, in
## milliseconds since launch, at which the reads stop.
var _settling: Dictionary[int, int] = {}

## _types holds the Steam Input type read as each connected device connected. Valve
## documents the type as the controller's model, so it's read once per connection.
var _types: Dictionary[int, int] = {}

## _waiting holds the time, in milliseconds since launch, at which Steam first reported
## each device it doesn't list yet or whose binding it hasn't loaded. Steam's callbacks
## can arrive before it lists the device, and until then it reports no type for it.
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
	assert(
		not godot_joypad_monitor or godot_joypad_monitor is GodotJoypadMonitor,
		"invalid config; wrong joypad monitor",
	)

	process_mode = Node.PROCESS_MODE_ALWAYS

	Signals.connect_safe(Steam.input_device_connected, _on_device_connected)
	Signals.connect_safe(Steam.input_device_disconnected, _on_device_disconnected)
	Signals.connect_safe(Steam.input_configuration_loaded, _on_configuration_loaded)

	if not Steam.inputInit():
		assert(false, "failed to initialize Steam Input")
		return

	_hold_virtual_gamepads()

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

	# NOTE: The Godot monitor keeps holding Steam's virtual gamepads, as this monitor
	# doesn't report its own controllers disconnected, so quitting reports neither.

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
	# A waiting controller isn't in `_connected` and publishes no Steam actions until it
	# connects, so its virtual gamepad's events pass through as its only input.
	if _is_virtual_gamepad(event.device):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# NOTE: Bindings are read first, so a waiting device whose binding has just loaded
	# without the game's actions opts out before it can connect.
	_read_settling_bindings(Time.get_ticks_msec())
	_poll_waiting_devices()


func _ready() -> void:
	_update_processing()


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


## _can_read_binding returns whether `action_sets` are set and Steam has loaded
## `device`'s binding, so the binding can be read for their actions.
func _can_read_binding(device: int) -> bool:
	if not action_sets:
		return false

	# NOTE: Valve documents that the revision can't be read while the binding loads.
	return not Steam.getDeviceBindingRevision(device).is_empty()


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
## once Steam loads its binding, or which has waited `_LIST_TIMEOUT_MSEC` by `now`, in
## milliseconds since launch.
func _connect_waiting_devices(listed: Array, now: int) -> void:
	for device: int in _waiting.keys():
		var waited: int = now - _waiting[device]

		# NOTE: A device whose binding hasn't loaded can still turn out to opt out.
		var is_ready := (
			device in listed and (not action_sets or _can_read_binding(device))
		)

		if not is_ready:
			if waited < _LIST_TIMEOUT_MSEC:
				continue

			# NOTE: A controller which does nothing is worse than one with the wrong
			# glyphs.
			(
				_logger
				. warn(
					"Joypad not ready in Steam; connecting it anyway.",
					{
						&"device": device,
						&"listed": device in listed,
						&"waited_msec": waited,
					},
				)
			)

		_waiting.erase(device)
		_connect_device(device)

	_update_processing()


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


## _has_bound_action returns whether `device`'s binding gives an origin to one of
## `action_set`'s actions in the manifest's set or layer `action_set_handle`.
static func _has_bound_action(
	device: int, action_set_handle: int, action_set: StdInputActionSet
) -> bool:
	for action in action_set.actions_digital:
		# NOTE: A stick's directional actions have no Steam action of their own.
		if action_set.get_analog_2d_action(action):
			continue

		var handle := Steam.getDigitalActionHandle(action)
		if handle and Steam.getDigitalActionOrigins(device, action_set_handle, handle):
			return true

	var analog := action_set.actions_analog_1d + action_set.actions_analog_2d
	if action_set.action_absolute_mouse:
		analog.append(action_set.action_absolute_mouse)

	for action in analog:
		var handle := Steam.getAnalogActionHandle(action)
		if handle and Steam.getAnalogActionOrigins(device, action_set_handle, handle):
			return true

	return false


## _has_connected_type returns whether the connected `device` connected with Steam
## Input type `input_type`.
func _has_connected_type(device: int, input_type: int) -> bool:
	return device in _types and _types[device] == input_type


## _hold_virtual_gamepads has `godot_joypad_monitor`, when it's set, hold each Steam
## virtual gamepad except those of the devices whose configuration opts out, since this
## monitor reports every other device once Steam lists it.
func _hold_virtual_gamepads() -> void:
	if godot_joypad_monitor:
		godot_joypad_monitor.hold_steam_virtual_gamepads(_opted_out)


## _is_binding_opted_out returns whether `device`'s binding gives none of the actions in
## `action_sets` an origin, so its configuration doesn't use the Steam Input API. It's
## called only once `_can_read_binding` returns `true`.
func _is_binding_opted_out(device: int) -> bool:
	for action_set in action_sets:
		if not action_set:
			continue

		for action_set_name in _list_manifest_names(action_set, action_sets):
			var handle := Steam.getActionSetHandle(action_set_name)
			if handle and _has_bound_action(device, handle, action_set):
				return false

	return true


## _is_tracked returns whether `device` is connected, waiting or opted out.
func _is_tracked(device: int) -> bool:
	return device in _connected or device in _opted_out or device in _waiting


## _is_virtual_gamepad returns whether Godot's joypad `device` is the virtual gamepad
## Steam runs for a controller this monitor connected. It's matched by Steam handle,
## since SDL reports the physical controller's vendor and product IDs for it.
func _is_virtual_gamepad(device: int) -> bool:
	# NOTE: An injected event can name a joypad Godot hasn't opened, whose info would
	# raise an error.
	if device not in Input.get_connected_joypads():
		return false

	var handle := GodotJoypadMonitor.get_steam_handle(Input.get_joy_info(device))

	return handle != 0 and handle in _connected


## _list_manifest_names returns the names the Steam Input manifest gives `action_set`.
## The manifest writes a layer with no parent under each set in `sets`, as
## `<Layer>_<Set>`.
static func _list_manifest_names(
	action_set: StdInputActionSet, sets: Array[StdInputActionSet]
) -> PackedStringArray:
	if not action_set is StdInputActionSetLayer or action_set.parent:
		return PackedStringArray([action_set.name])

	var names := PackedStringArray()
	for parent in sets:
		if parent and not parent is StdInputActionSetLayer:
			names.append("%s_%s" % [action_set.name, parent.name])

	return names


## _poll_waiting_devices connects each waiting device Steam now lists. Steam's list is
## read only while a device waits, since GodotSteam prints a line on each read.
func _poll_waiting_devices() -> void:
	var listed: Array = Steam.getConnectedControllers() if _waiting else []
	_connect_waiting_devices(listed, Time.get_ticks_msec())


## _read_binding opts `device` out of the Steam Input API while its binding gives none
## of the actions in `action_sets` an origin, and back in once it gives one an origin.
## Nothing changes until Steam loads the binding.
func _read_binding(device: int) -> void:
	if not _can_read_binding(device):
		return

	var opted_out := _is_binding_opted_out(device)
	if opted_out != (device in _opted_out):
		(
			_logger
			. info(
				(
					"Joypad binding has no Steam Input actions."
					if opted_out
					else "Joypad binding has Steam Input actions."
				),
				{&"device": device},
			)
		)

	_route_device(device, opted_out)


## _read_settling_bindings reads the binding of each device in `_settling`, dropping a
## device once its reads stop by `now`, in milliseconds since launch.
func _read_settling_bindings(now: int) -> void:
	for device: int in _settling.keys():
		if now >= _settling[device]:
			_settling.erase(device)
			continue

		_read_binding(device)

	_update_processing()


## _route_device opts `device` out of the Steam Input API, disconnecting it so that
## `godot_joypad_monitor` reports its virtual gamepad, or back in, waiting for Steam to
## list it.
func _route_device(device: int, opted_out: bool) -> void:
	_set_opted_out(device, opted_out)

	if not opted_out:
		_wait_for_device(device, Time.get_ticks_msec())
		return

	_waiting.erase(device)

	if device in _connected:
		_disconnect_device(device)


## _set_opted_out records whether `device`'s configuration opts out of the Steam Input
## API, handing each change to `godot_joypad_monitor`.
func _set_opted_out(device: int, opted_out: bool) -> void:
	var index := _opted_out.find(device)
	if opted_out == (index != -1):
		return

	if opted_out:
		_opted_out.append(device)
	else:
		_opted_out.remove_at(index)

	_hold_virtual_gamepads()


## _settle_binding reads `device`'s binding now and on each frame until
## `_BINDING_SETTLE_MSEC` after `now`, in milliseconds since launch. Without
## `action_sets`, no binding is read.
func _settle_binding(device: int, now: int) -> void:
	if not action_sets:
		return

	_settling[device] = now + _BINDING_SETTLE_MSEC
	_read_binding(device)
	_update_processing()


## _update_processing runs processing only while a device waits for Steam or has its
## binding read on each frame.
func _update_processing() -> void:
	set_process(not _waiting.is_empty() or not _settling.is_empty())


## _wait_for_device starts waiting for Steam to list `device`, which Steam reported at
## `now` in milliseconds since launch, unless it's connected, waiting or opted out.
func _wait_for_device(device: int, now: int) -> void:
	if _is_tracked(device):
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

	# NOTE: Its binding isn't read, since it can still show the previous configuration,
	# and a configuration without the Steam Input API binds none of the game's actions.
	var uses_steam_input_api: bool = cfg.get("uses_steam_input_api", true)
	if not uses_steam_input_api:
		_settling.erase(device)
		_route_device(device, true)
		_poll_waiting_devices()
		return

	if device in _connected:
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

	# NOTE: Steam reports a configuration carrying the game's action sets as using the
	# Steam Input API even when it binds none of their actions, so a tracked device
	# keeps its routing until its binding decides.
	if not action_sets or not _is_tracked(device):
		_route_device(device, false)

	_settle_binding(device, Time.get_ticks_msec())
	_poll_waiting_devices()


func _on_device_connected(device: int) -> void:
	# NOTE: No configuration loads at launch, so a device Steam reports is read from its
	# binding, unless a configuration load reported it first, as on a replug.
	if not _is_tracked(device):
		var now := Time.get_ticks_msec()
		_wait_for_device(device, now)
		_settle_binding(device, now)

	_poll_waiting_devices()


func _on_device_disconnected(device: int) -> void:
	# NOTE: The device's configuration is loaded again when it reconnects.
	_set_opted_out(device, false)

	_settling.erase(device)
	_waiting.erase(device)

	# NOTE: A configuration which doesn't use the Steam Input API can disconnect the
	# device first.
	if device in _connected:
		_disconnect_device(device)

	_poll_waiting_devices()
