##
## std/input/slot.gd
##
## InputSlot is an abstraction for managing the input of a single player within the
## game. Each `InputSlot` can be customized to control what input falls within its scope
## and which input devices are assigned to it.
##
## For a local multiplayer game, one `InputSlot` would be created for each possible
## player (and possibly one additional slot for keyboard and mouse controls if those
## aren't tied to one player). Single player games should have a single `InputSlot`
## which defines how to swap between various connected `InputDevice`s.
##
## TODO: For now, this class only supports single player because there's no way to
## filter out device indices. Given that Godot has limited-at-best support for local
## multiplayer, this is not a priority.
##

class_name InputSlot
extends InputDevice

# -- SIGNALS ------------------------------------------------------------------------- #

## device_activated is emitted when a new `InputDevice` becomes active.
signal device_activated(device: InputDevice)

## device_connected is emitted when a new `InputDevice` is connected.
##
## NOTE: This might not be emitted for devices already connected when the game starts.
## To change this behavior, alter the `JoypadMonitor` component's behavior.
signal device_connected(device: InputDevice)

## device_disconnected is emitted when a previously connected `InputDevice` disconnects.
signal device_disconnected(device: InputDevice)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

# InputSlot components


## JoypadMonitor is an abstract inferface for a `Node` which tracks joypad activity
## (i.e. connects and disconnects).
##
## This should be implemented according to the library used for managing input devices
## (e.g. Steam Input or Godot) and set on the `InputSlot`.
class JoypadMonitor:
	extends Node

	@warning_ignore("UNUSED_SIGNAL")
	signal joy_connected(index: int, device_type: InputDeviceType)

	@warning_ignore("UNUSED_SIGNAL")
	signal joy_disconnected(index: int)


# InputDevice components


## Bindings is an implementation of `InputDevice.Bindings` which delegates to all input
## devices associated with this `InputSlot`.
class Bindings:
	extends InputDevice.Bindings

	@export var active: InputDevice = null
	@export var connected: Array[InputDevice] = []

	@export var cursor: InputCursor = null

	# Action sets

	func load_action_set(action_set: InputActionSet) -> bool:
		# NOTE: Ignore the result; this just caches the action set.
		super.load_action_set(action_set)

		if not (
			connected
			. map(func(d): return d.load_action_set(action_set))
			. any(func(r): return r)
		):
			return false

		if cursor:
			cursor.update_configuration(_action_set, _action_set_layers)

		return true

	# Action set layers

	func enable_action_set_layer(action_set_layer: InputActionSetLayer) -> bool:
		# NOTE: Ignore the result; this just caches the layer.
		super.enable_action_set_layer(action_set_layer)

		if not (
			connected
			. map(func(d): return d.enable_action_set_layer(action_set_layer))
			. any(func(r): return r)
		):
			return false

		if cursor:
			cursor.update_configuration(_action_set, _action_set_layers)

		return true

	func disable_action_set_layer(action_set_layer: InputActionSetLayer) -> bool:
		# NOTE: Ignore the result; this just caches the layer.
		super.disable_action_set_layer(action_set_layer)

		if not (
			connected
			. map(func(d): return d.disable_action_set_layer(action_set_layer))
			. any(func(r): return r)
		):
			return false

		if cursor:
			cursor.update_configuration(_action_set, _action_set_layers)

		return true

	# Action origins

	func get_action_origins(action: StringName) -> PackedInt64Array:
		if not active:
			return PackedInt64Array()

		assert(device == active.index, "invalid argument; wrong device index")
		return active.get_action_origins(action)


## Glyphs is an implementation of `InputDevice.Glyphs` which delegates to the active
## input device associated with this `InputSlot`.
class Glyphs:
	extends InputDevice.Glyphs

	@export var active: InputDevice = null
	@export var glyph_type_override_property: StdSettingsPropertyInt = null

	func get_origin_glyph(device_type: InputDeviceType, origin: int) -> Texture2D:
		if not active:
			return null

		var effective_device_type := device_type

		if glyph_type_override_property:
			var value: InputDeviceType = glyph_type_override_property.get_value()
			if value != DEVICE_TYPE_UNKNOWN:
				effective_device_type = value

		assert(device == active.index, "invalid argument; wrong device index")
		return active.glyphs.get_origin_glyph(effective_device_type, origin)


## Haptics is an implementation of `InputDevice.Haptics` which delegates to the active
## input device associated with this `InputSlot`.
##
## NOTE: This is a naive implementation which doesn't track vibrations across device
## activations/deactivations. It's not a priority to fix as haptic feedback is short.
class Haptics:
	extends InputDevice.Haptics

	@export var active: InputDevice = null

	func start_vibrate_weak(duration: float) -> bool:
		if not active:
			return false

		assert(device == active.index, "invalid argument; wrong device index")
		return active.haptics.start_vibrate_weak(duration)

	func start_vibrate_strong(duration: float) -> bool:
		if not active:
			return false

		assert(device == active.index, "invalid argument; wrong device index")
		return active.haptics.start_vibrate_strong(duration)

	func stop_vibrate() -> void:
		if not active:
			return

		assert(device == active.index, "invalid argument; wrong device index")
		return active.haptics.stop_vibrate()


# -- CONFIGURATION ------------------------------------------------------------------- #

## claim_kbm_input defines whether this `InputSlot` will consider keyboard and mouse
## input as belonging to itself. Depending on certain factors, this will generally
## activate the `InputDevice` belonging to the keyboard and mouse when that input is
## received.
##
## NOTE: If `true`, the keyboard and mouse device will be activated initially.
@export var claim_kbm_input: bool = true

## prefer_activate_joypad_on_ready defines whether a connected controller should be
## activated upon this `InputSlot` first loading (overriding an active keyboard). Note
## that the first joypad will always be selected at first.
@export var prefer_activate_joypad_on_ready: bool = true

@export_group("Input devices")

## kbm_device_scene is a `PackedScene` which will be used as the `InputDevice`
## implementation for keyboard and mouse input.
##
## NOTE: If `claim_kbm_input` is set to `false` then this value will be ignored.
@export var kbm_device_scene: PackedScene = null

## joy_device_scene is a `PackedScene` which will be used as the `InputDevice`
## implementation for joypad input.
@export var joy_device_scene: PackedScene = null

@export_group("Components")

## cursor is a node which manages the visibility state of the game's cursor. This is an
## optional component, but only one `InputSlot` at most may have one.
@export var cursor: InputCursor = null

## joypad_monitor is a node which monitors joypad activity. This `InputSlot` node will
## manage active input devices based on the monitor's signals.
@export var joypad_monitor: JoypadMonitor = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _active: InputDevice = null

var _kbm_device: InputDevice = null
var _joypad_devices: Array[InputDevice] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_active_device returns the currently (i.e. most recently) active input device. If
## no device is active, the returned value will be `null`.
func get_active_device() -> InputDevice:
	return _active


## get_connected_devices returns a list of all connected devices. If `include_keyboard`
## is `true` (the default), then the keyboard and mouse `InputDevice` will be included.
func get_connected_devices(include_keyboard: bool = true) -> Array[InputDevice]:
	var devices := _joypad_devices.duplicate()

	if include_keyboard and _kbm_device:
		assert(_kbm_device is InputDevice, "invalid state; missing device")
		assert(
			_kbm_device.device_type == InputDevice.DEVICE_TYPE_KEYBOARD,
			"invalid state; invalid device type",
		)

		devices.push_front(_kbm_device)

	return devices


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(joypad_monitor is JoypadMonitor, "invalid config; missing component")

	Signals.connect_safe(device_activated, _on_Self_device_activated)
	Signals.connect_safe(device_connected, _on_Self_device_connected)
	Signals.connect_safe(device_disconnected, _on_Self_device_disconnected)
	Signals.connect_safe(joypad_monitor.joy_connected, _connect_joy_device)
	Signals.connect_safe(joypad_monitor.joy_disconnected, _disconnect_joy_device)


func _exit_tree() -> void:
	Signals.disconnect_safe(device_activated, _on_Self_device_activated)
	Signals.disconnect_safe(device_connected, _on_Self_device_connected)
	Signals.disconnect_safe(device_disconnected, _on_Self_device_disconnected)
	Signals.disconnect_safe(joypad_monitor.joy_connected, _connect_joy_device)
	Signals.disconnect_safe(joypad_monitor.joy_disconnected, _disconnect_joy_device)

	_active = null

	if _kbm_device:
		var kbm := _kbm_device
		_kbm_device = null

		device_disconnected.emit(kbm)

		remove_child(kbm)
		kbm.free()

	for joypad in _joypad_devices:
		_disconnect_joy_device(joypad.index)

	_joypad_devices = []


func _input(event: InputEvent) -> void:
	# Swap to controller
	if (
		_active == null
		or (
			(
				_active.device_type == DEVICE_TYPE_KEYBOARD
				or _active.index != event.device
			)
			and (event is InputEventJoypadButton or event is InputEventJoypadMotion)
		)
	):
		for joypad in _joypad_devices:
			if not joypad:
				assert(false, "invalid state; missing device")
				continue

			if event.device != joypad.index:
				continue

			_activate_device(joypad)
			break

	# Swap to keyboard + mouse
	elif (
		claim_kbm_input
		and (_active == null or _active.device_type != DEVICE_TYPE_KEYBOARD)
		# NOTE: Do not swap based on mouse motion as that might be emulated from a gyro sensor.
		and (event is InputEventKey or event is InputEventMouseButton)
	):
		_activate_device(_kbm_device)


func _ready() -> void:
	if not bindings:
		bindings = Bindings.new()
		bindings.active = get_active_device()
		bindings.connected = get_connected_devices()
		bindings.cursor = cursor
		add_child(bindings, false, INTERNAL_MODE_BACK)

	if not glyphs:
		glyphs = Glyphs.new()
		glyphs.active = get_active_device()
		glyphs.glyph_type_override_property = glyph_type_override_property
		add_child(glyphs, false, INTERNAL_MODE_BACK)

	if not haptics:
		haptics = Haptics.new()
		haptics.active = get_active_device()
		add_child(haptics, false, INTERNAL_MODE_BACK)

	# NOTE: This must be called after adding components, otherwise no-op components will
	# be created by the super's implementation.
	super._ready()

	assert(joy_device_scene, "invalid config; missing joypad device scene")
	assert(
		joypad_monitor is JoypadMonitor,
		"invalid config; missing joypad connection monitor"
	)

	if claim_kbm_input:
		assert(kbm_device_scene, "invalid config; missing kbm scene")
		var kbm: InputDevice = kbm_device_scene.instantiate()
		kbm.index = 0
		kbm.device_type = DEVICE_TYPE_KEYBOARD

		assert(not _kbm_device, "invalid state; found dangling device")
		_kbm_device = kbm

		add_child(kbm, false, INTERNAL_MODE_BACK)
		device_connected.emit(kbm)

		if not _active or not prefer_activate_joypad_on_ready:
			_activate_device(kbm)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _activate_device(device: InputDevice) -> bool:
	assert(device is InputDevice, "missing argument: device")

	if device and _active == device:
		return false

	if device.device_type == DEVICE_TYPE_KEYBOARD:
		if not claim_kbm_input or not _kbm_device or _kbm_device != device:
			assert(claim_kbm_input, "invalid config; keyboard not claimed")
			assert(_kbm_device, "invalid state; device not connected")
			assert(_kbm_device == device, "invalid argument; conflicting device")

			return false

		_active = _kbm_device
		device_activated.emit(_kbm_device)

		return true

	for joypad in _joypad_devices:
		if not joypad or joypad.index != device.index:
			assert(joypad, "invalid state; missing device")
			continue

		if joypad != device:
			assert(false, "invalid argument; conflicting device")
			return false

		_active = joypad
		device_activated.emit(joypad)

		return true

	return false


func _connect_joy_device(
	device: int, joy_device_type: InputDeviceType = DEVICE_TYPE_UNKNOWN
) -> bool:
	assert(device >= 0, "invalid argument; device must be >= 0")

	@warning_ignore("SHADOWED_VARIABLE")  # NOTE: Shadowing here prevents using wrong type.
	var device_type := joy_device_type

	if device_type == DEVICE_TYPE_KEYBOARD:
		assert(false, "invalid argument: cannot use keyboard")
		return false

	if _joypad_devices.any(func(d): return device == d.index):
		return false

	assert(joy_device_scene, "invalid config; missing joypad device scene")
	var joypad: InputDevice = joy_device_scene.instantiate()
	assert(joypad is InputDevice, "invalid state; missing device")

	joypad.index = device
	joypad.device_type = device_type

	_joypad_devices.append(joypad)

	add_child(joypad, false, INTERNAL_MODE_BACK)
	device_connected.emit(joypad)

	if not _active:
		_active = joypad
		device_activated.emit(joypad)

	return true


func _disconnect_joy_device(device: int) -> bool:
	assert(device >= 0, "invalid argument; device must be >= 0")

	for i in len(_joypad_devices):
		var joypad: InputDevice = _joypad_devices[i]
		assert(joypad is InputDevice, "invalid state; missing device")

		if joypad.index != device:
			continue

		_joypad_devices.remove_at(i)
		device_disconnected.emit(joypad)

		remove_child(joypad)
		joypad.free()

		return true

	return false


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Self_device_activated(device: InputDevice) -> void:
	index = device.index
	device_type = device.device_type

	assert(bindings is Bindings, "invalid state; missing component")
	bindings.active = device

	assert(glyphs is Glyphs, "invalid state; missing component")
	glyphs.active = device

	assert(haptics is Haptics, "invalid state; missing component")
	haptics.active = device


func _on_Self_device_connected(device: InputDevice) -> void:
	assert(bindings is Bindings, "invalid state; missing component")
	bindings.connected = get_connected_devices()

	var action_set := bindings.get_action_set()
	if not action_set:
		assert(
			bindings.list_action_set_layers().is_empty(),
			"invalid state; found dangling layers",
		)

	device.load_action_set(action_set)

	for layer in bindings.list_action_set_layers():
		device.enable_action_set_layer(layer)


func _on_Self_device_disconnected(_device: InputDevice) -> void:
	assert(bindings is Bindings, "invalid state; missing component")
	bindings.connected = get_connected_devices()

	# No need to disable action sets/layers here - the device may reconnect.
