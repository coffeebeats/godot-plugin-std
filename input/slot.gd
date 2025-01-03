##
## std/input/slot.gd
##
## StdInputSlot is an abstraction for managing the input of a single player within the
## game. Each `StdInputSlot` can be customized to control what input falls within its
## scope and which input devices are assigned to it.
##
## For a local multiplayer game, one `StdInputSlot` would be created for each possible
## player (and possibly one additional slot for keyboard and mouse controls if those
## aren't tied to one player). Single player games should have a single `StdInputSlot`
## which defines how to swap between various connected `StdInputDevice`s.
##
## TODO: For now, this class only supports single player because there's no way to
## filter out device indices. Given that Godot has limited-at-best support for local
## multiplayer, this is not a priority.
##

class_name StdInputSlot
extends StdInputDevice

# -- SIGNALS ------------------------------------------------------------------------- #

## device_activated is emitted when a new `StdInputDevice` becomes active.
signal device_activated(device: StdInputDevice)

## device_connected is emitted when a new `StdInputDevice` is connected.
##
## NOTE: This might not be emitted for devices already connected when the game starts.
## To change this behavior, alter the `JoypadMonitor` component's behavior.
signal device_connected(device: StdInputDevice)

## device_disconnected is emitted when a previously connected `StdInputDevice`
## disconnects.
signal device_disconnected(device: StdInputDevice)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")
const StdInputSlotDeviceActions := preload("slot_actions.gd")
const StdInputSlotDeviceGlyphs := preload("slot_glyphs.gd")
const StdInputSlotDeviceHaptics := preload("slot_haptics.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_INPUT_SLOT := &"std/input:slot"
const PROPERTY_STATUS_ON := StdInputActionSet.PROPERTY_STATUS_ON
const PROPERTY_STATUS_OFF := StdInputActionSet.PROPERTY_STATUS_OFF


## JoypadMonitor is an abstract inferface for a `Node` which tracks joypad activity
## (i.e. connects and disconnects).
##
## This should be implemented according to the library used for managing input devices
## (e.g. Steam Input or Godot) and set on the `StdInputSlot`.
class JoypadMonitor:
	extends Node

	@warning_ignore("UNUSED_SIGNAL")
	signal joy_connected(device_id: int, device_type: DeviceType)

	@warning_ignore("UNUSED_SIGNAL")
	signal joy_disconnected(device_id: int)

	## broadcast_connected_joypads requests the joypad monitor to emit connection
	## signals for all already connected devices.
	func broadcast_connected_joypads() -> void:
		return _broadcast_connected_joypads()

	func _broadcast_connected_joypads() -> void:
		assert(false, "unimplemented")


# -- CONFIGURATION ------------------------------------------------------------------- #

## player_id is the player identifier to which this `StdInputSlot` is assigned. Player
## IDs begin from `1` and go up to the maximum local multiplayer player count (e.g.
## `8`).
@export var player_id: int = 1

@export_group("Configuration")

## claim_kbm_input defines whether this `StdInputSlot` will consider keyboard and mouse
## input as belonging to itself. Depending on certain factors, this will generally
## activate the `StdInputDevice` belonging to the keyboard and mouse when that input is
## received.
##
## NOTE: If `true`, the keyboard and mouse device will be activated initially.
@export var claim_kbm_input: bool = true

## prefer_activate_joypad_on_ready defines whether a connected controller should be
## activated upon this `StdInputSlot` first loading (overriding an active keyboard).
## Note that the first joypad will always be selected at first.
@export var prefer_activate_joypad_on_ready: bool = true

@export_group("Properties")

## haptics_disabled_property is a settings property which controls whether haptics are
## completely disabled.
@export var haptics_disabled_property: StdSettingsPropertyBool = null

## haptics_strength_property is a settings property which controls the strength of
## triggered haptic effects.
@export var haptics_strength_property: StdSettingsPropertyFloatRange = null

@export_group("Components")

## cursor is a node which manages the visibility state of the game's cursor. This is an
## optional component, but only one `StdInputSlot` at most may have one.
@export var cursor: StdInputCursor = null

## joypad_monitor is a node which monitors joypad activity. This `StdInputSlot` node
## will manage active input devices based on the monitor's signals.
@export var joypad_monitor: JoypadMonitor = null:
	set = set_joypad_monitor

@export_subgroup("Keyboard and mouse")

## actions_kbm is the actions component for keyboard and mouse.
@export var actions_kbm: StdInputDeviceActions = null:
	set(value):
		actions_kbm = value

		if _kbm_device:
			_kbm_device.actions = value

## glyphs_kbm is the glyphs component for keyboard and mouse.
@export var glyphs_kbm: StdInputDeviceGlyphs = null:
	set(value):
		glyphs_kbm = value

		if _kbm_device:
			_kbm_device.glyphs = value

## haptics_kbm is the haptics component for keyboard and mouse.
@export var haptics_kbm: StdInputDeviceHaptics = null:
	set(value):
		haptics_kbm = value

		if _kbm_device:
			_kbm_device.haptics = value

@export_subgroup("Joypad")

## actions_joy is the actions component for joypads.
@export var actions_joy: StdInputDeviceActions = null:
	set(value):
		actions_joy = value

		for joypad in _joypad_devices:
			joypad.actions_joy = value

## glyphs_joy is the glyphs component for joypads.
@export var glyphs_joy: StdInputDeviceGlyphs = null:
	set(value):
		glyphs_joy = value

		for joypad in _joypad_devices:
			joypad.glyphs_joy = value

## haptics_joy is the haptics component for joypads.
@export var haptics_joy: StdInputDeviceHaptics = null:
	set(value):
		haptics_joy = value

		for joypad in _joypad_devices:
			joypad.haptics_joy = value

# -- INITIALIZATION ------------------------------------------------------------------ #

var _actions: Array[String] = []
var _active: StdInputDevice = null
var _cursor_activates_kbm: bool = false
var _joypad_devices: Array[StdInputDevice] = []
var _kbm_device: StdInputDevice = null
var _last_active_joypad: StdInputDevice = null
var _pressed: Array[String] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## all lists all `StdInputSlot` instances in the scene tree.
static func all() -> Array[StdInputSlot]:
	var members: Array[StdInputSlot] = []

	for member in StdGroup.with_id(GROUP_INPUT_SLOT).list_members():
		if not member is StdInputSlot:
			assert(false, "invalid state; wrong member type")
			continue

		members.append(member)

	return members


## for_player finds the `StdInputSlot` in the scene tree that's assigned to the specified
## player. Note that there can be only one `StdInputSlot` per player.
static func for_player(player: int) -> StdInputSlot:
	for member in StdGroup.with_id(GROUP_INPUT_SLOT).list_members():
		assert(member is StdInputSlot, "invalid state; wrong member type")

		if member.player_id == player:
			return member

	return null


# Devices


## get_active_device returns the currently (i.e. most recently) active input device. If
## no device is active, the returned value will be `null`.
func get_active_device() -> StdInputDevice:
	return _active


## get_last_active_joypad_device returns the last joypad device that was used. If no
## joypad device has been activated, then this will return `null`.
func get_last_active_joypad_device() -> StdInputDevice:
	return _last_active_joypad


## get_connected_devices returns a list of all connected devices. If `include_keyboard`
## is `true` (the default), then the keyboard and mouse `StdInputDevice` will be
## included.
func get_connected_devices(include_keyboard: bool = true) -> Array[StdInputDevice]:
	var devices := _joypad_devices.duplicate()

	if include_keyboard and _kbm_device:
		assert(_kbm_device is StdInputDevice, "invalid state; missing device")
		assert(
			_kbm_device.device_type == DEVICE_TYPE_KEYBOARD,
			"invalid state; invalid device type",
		)

		devices.push_front(_kbm_device)

	return devices


# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #

# Glyphs


## get_action_glyph returns a `Texture2D` containing the glyph of the primary (i.e.
## first) controller origin which will actuate the specified action.
func get_action_glyph(
	action_set: StdInputActionSet,
	action: StringName,
	index: int = 0,
	target_size: Vector2 = Vector2.ZERO,
	device_type_override: DeviceType = DEVICE_TYPE_UNKNOWN
) -> Texture2D:
	assert(glyphs is StdInputDeviceGlyphs, "invalid state; missing component")

	if device_type_override == DEVICE_TYPE_UNKNOWN:
		device_type_override = device_type

	return glyphs.get_action_glyph(
		device_id, device_type_override, action_set, action, index, target_size
	)


## get_action_origin_label returns the localized display name for the first origin bound
## to the specified action.
func get_action_origin_label(
	action_set: StdInputActionSet,
	action: StringName,
	index: int = 0,
	device_type_override: DeviceType = DEVICE_TYPE_UNKNOWN
) -> String:
	assert(glyphs is StdInputDeviceGlyphs, "invalid state; missing component")

	if device_type_override == DEVICE_TYPE_UNKNOWN:
		device_type_override = device_type

	return (
		glyphs
		. get_action_origin_label(
			device_id,
			device_type_override,
			action_set,
			action,
			index,
		)
	)


# Haptics


## start_vibrate_strong initiates an input device vibration for `duration` seconds using
## the device's strong vibration motor, if available.
func start_vibrate_strong(duration: float, strength: float = 1.0) -> void:
	assert(haptics is StdInputDeviceHaptics, "invalid state; missing component")

	if haptics_disabled_property.get_value():
		return

	if haptics_strength_property:
		strength *= haptics_strength_property.get_normalized_value()

	return haptics.start_vibrate_strong(device_id, duration, clampf(strength, 0.0, 1.0))


## start_vibrate_weak initiates an input device vibration for `duration` seconds using
## the device's weak vibration motor, if available.
func start_vibrate_weak(duration: float, strength: float = 1.0) -> void:
	assert(haptics is StdInputDeviceHaptics, "invalid state; missing component")

	if haptics_disabled_property.get_value():
		return

	if haptics_strength_property:
		strength *= haptics_strength_property.get_normalized_value()

	return haptics.start_vibrate_weak(device_id, duration, clampf(strength, 0.0, 1.0))


## stop_vibrate terminates all ongoing vibration for the input device.
func stop_vibrate() -> void:
	assert(haptics is StdInputDeviceHaptics, "invalid state; missing component")

	if haptics_disabled_property.get_value():
		return

	return haptics.stop_vibrate(device_id)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(
		not StdGroup.with_id(GROUP_INPUT_SLOT).list_members().any(
			func(m): return m.player_id == player_id
		),
		"invalid state; duplicate input slot found",
	)
	StdGroup.with_id(GROUP_INPUT_SLOT).add_member(self)

	assert(cursor is StdInputCursor, "invalid config; missing component")
	Signals.connect_safe(
		cursor.cursor_visibility_changed, _on_cursor_visibility_changed
	)

	assert(joypad_monitor is JoypadMonitor, "invalid config; missing component")
	Signals.connect_safe(joypad_monitor.joy_connected, _connect_joy_device)
	Signals.connect_safe(joypad_monitor.joy_disconnected, _disconnect_joy_device)

	Signals.connect_safe(
		action_configuration_changed, _on_Self_action_configuration_changed
	)
	Signals.connect_safe(device_activated, _on_Self_device_activated)
	Signals.connect_safe(device_connected, _on_Self_device_connected)
	Signals.connect_safe(device_disconnected, _on_Self_device_disconnected)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_INPUT_SLOT).remove_member(self)

	Signals.disconnect_safe(
		cursor.cursor_visibility_changed, _on_cursor_visibility_changed
	)
	Signals.disconnect_safe(
		action_configuration_changed, _on_Self_action_configuration_changed
	)
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
		kbm.queue_free()

	for joypad in _joypad_devices:
		_disconnect_joy_device(joypad.device_id)

	_joypad_devices = []

	# NOTE: Connect after initializing devices to avoid inadvertent device activation.
	assert(cursor is StdInputCursor, "invalid config; missing component")
	Signals.connect_safe(
		cursor.cursor_visibility_changed, _on_cursor_visibility_changed
	)


func _input(event: InputEvent) -> void:
	if not event.is_action_type():
		return

	if not event.is_pressed():
		for action in _pressed:
			if not event.is_action_pressed(action):
				_pressed.erase(action)

		return

	# Swap to controller
	if (
		_active == null
		or (
			(
				_active.device_type == DEVICE_TYPE_KEYBOARD
				or _active.device_id != event.device
			)
			and (
				event is InputEventJoypadButton
				or event is InputEventJoypadMotion
				or event is InputEventAction
			)
		)
	):
		var is_match := false
		for action in _actions:
			if not event.is_action_pressed(action):
				continue

			if action not in _pressed:
				_pressed.append(action)
				is_match = true
				break

		if not is_match:
			return

		for joypad in _joypad_devices:
			if not joypad:
				assert(false, "invalid state; missing device")
				continue

			if event.device != joypad.device_id:
				continue

			_activate_device(joypad)
			break

	# Swap to keyboard + mouse
	elif (
		claim_kbm_input
		and (_active == null or _active.device_type != DEVICE_TYPE_KEYBOARD)
		# NOTE: Do not swap based on mouse motion as that might be emulated from a gyro sensor.
		and (event is InputEventKey or event is InputEventMouseButton)
		and (_actions.any(func(a): return Input.is_action_just_pressed(a)))
	):
		_activate_device(_kbm_device)


func _ready() -> void:
	assert(
		haptics_disabled_property is StdSettingsPropertyBool,
		"invalid config; missing property",
	)
	assert(
		haptics_strength_property is StdSettingsPropertyFloatRange,
		"invalid config; missing property",
	)

	if not actions:
		actions = StdInputSlotDeviceActions.new()
		actions.slot = self
		add_child(actions, false, INTERNAL_MODE_BACK)

	if not glyphs:
		glyphs = StdInputSlotDeviceGlyphs.new()
		glyphs.slot = self
		add_child(glyphs, false, INTERNAL_MODE_BACK)

	if not haptics:
		haptics = StdInputSlotDeviceHaptics.new()
		haptics.slot = self
		add_child(haptics, false, INTERNAL_MODE_BACK)

	# NOTE: This must be called after adding components, otherwise no-op components will
	# be created by the super's implementation.
	super._ready()

	_logger = _logger.named(&"std/input/slot")

	assert(
		joypad_monitor is JoypadMonitor,
		"invalid config; missing joypad connection monitor"
	)

	joypad_monitor.broadcast_connected_joypads()

	if claim_kbm_input:
		var kbm := _make_kbm()

		assert(not _kbm_device, "invalid state; found dangling device")
		_kbm_device = kbm

		add_child(kbm, false, INTERNAL_MODE_BACK)
		device_connected.emit(kbm)

		if not _active or not prefer_activate_joypad_on_ready:
			_activate_device(kbm)
			cursor.call_deferred(&"show_cursor")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _activate_device(device: StdInputDevice) -> bool:
	assert(device is StdInputDevice, "missing argument: device")

	if device and device.device_type != DEVICE_TYPE_KEYBOARD:
		_last_active_joypad = device

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

		_logger.info(
			"Activated keyboard device.",
			{&"device": _active.device_id, &"type": _active.device_type}
		)

		return true

	for joypad in _joypad_devices:
		if not joypad or joypad.device_id != device.device_id:
			assert(joypad, "invalid state; missing device")
			continue

		if joypad != device:
			assert(false, "invalid argument; conflicting device")
			return false

		_active = joypad
		device_activated.emit(joypad)

		_logger.info(
			"Activated joypad device.",
			{&"device": _active.device_id, &"type": _active.device_type}
		)

		return true

	return false


func _connect_joy_device(
	device: int, joy_device_type: DeviceType = DEVICE_TYPE_GENERIC
) -> bool:
	assert(device >= 0, "invalid argument; device must be >= 0")

	# NOTE: Shadowing here prevents using wrong type.
	@warning_ignore("SHADOWED_VARIABLE")
	var device_type := joy_device_type

	if device_type == DEVICE_TYPE_KEYBOARD:
		assert(false, "invalid argument: cannot use keyboard")
		return false

	if _joypad_devices.any(func(d): return device == d.device_id):
		return false

	var joypad := _make_joy(device, device_type)

	_joypad_devices.append(joypad)

	add_child(joypad, false, INTERNAL_MODE_BACK)
	device_connected.emit(joypad)

	if not _active or (_active == _kbm_device and prefer_activate_joypad_on_ready):
		_activate_device(joypad)
		cursor.call_deferred(&"hide_cursor")

	return true


func _disconnect_joy_device(device: int) -> bool:
	assert(device >= 0, "invalid argument; device must be >= 0")

	for i in len(_joypad_devices):
		var joypad: StdInputDevice = _joypad_devices[i]
		assert(joypad is StdInputDevice, "invalid state; missing device")

		if joypad.device_id != device:
			continue

		_joypad_devices.remove_at(i)
		device_disconnected.emit(joypad)

		remove_child(joypad)
		joypad.queue_free()

		return true

	return false


func _list_action_sets(
	device: int = DEVICE_ID_ALL, reverse: bool = false
) -> Array[StdInputActionSet]:
	var out: Array[StdInputActionSet] = []

	for layer in actions.list_action_set_layers(device):
		out.append(layer)

	if reverse:
		out.reverse()

	var action_set := actions.get_action_set(device)
	if action_set:
		if reverse:
			out.append(action_set)
		else:
			out.push_front(action_set)

	return out as Array[StdInputActionSet]


func _make_joy(device: int, joy_device_type: DeviceType) -> StdInputDevice:
	# NOTE: Shadowing here prevents using wrong type.
	@warning_ignore("SHADOWED_VARIABLE")
	var device_type := joy_device_type

	var joy := StdInputDevice.new()

	# Device info
	joy.device_id = device
	joy.device_type = device_type

	# Components
	joy.actions = actions_joy
	joy.glyphs = glyphs_joy
	joy.haptics = haptics_joy

	return joy


func _make_kbm(device: int = 0) -> StdInputDevice:
	var kbm := StdInputDevice.new()

	# Device info
	kbm.device_id = device
	kbm.device_type = DEVICE_TYPE_KEYBOARD

	# Components
	kbm.actions = actions_kbm
	kbm.glyphs = glyphs_kbm
	kbm.haptics = haptics_kbm

	return kbm


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_cursor_visibility_changed(visible: bool) -> void:
	if not visible:
		return

	if not claim_kbm_input or not _cursor_activates_kbm or _active == _kbm_device:
		return

	assert(_kbm_device, "invalid state; missing input device")
	_activate_device(_kbm_device)


func _on_Self_action_configuration_changed() -> void:
	var action_sets := _list_action_sets(device_id, false)

	_actions = []
	_cursor_activates_kbm = false

	# NOTE: These must be iterated in forward order so that later action set layers can
	# override properties set in earlier action sets.
	for action_set in action_sets:
		# Update cursor properties.

		_cursor_activates_kbm = (
			false
			if action_set.cursor_activates_kbm == PROPERTY_STATUS_OFF
			else (
				_cursor_activates_kbm
				or action_set.cursor_activates_kbm == PROPERTY_STATUS_ON
			)
		)

		# Update active actions.

		for action in action_set.actions_analog_1d:
			assert(action not in _actions, "found duplicate action")
			_actions.append(action)
		for action in action_set.actions_analog_2d:
			assert(action not in _actions, "found duplicate action")
			_actions.append(action)
		for action in action_set.actions_digital:
			assert(action not in _actions, "found duplicate action")
			_actions.append(action)

	if cursor is StdInputCursor:
		cursor.update_configuration(action_sets)

	# NOTE: It's possible that removed action set layers had changed the cursor/keyboard
	# activation state; reconcile that now.
	if (
		# The cursor is visible despite the keyboard not being active; a layer was
		# removed that previously disabled 'cursor_activates_kbm'.
		_cursor_activates_kbm
		and device_type != DEVICE_TYPE_KEYBOARD
		and cursor.get_is_visible()
	):
		cursor.call_deferred(&"hide_cursor")


func _on_Self_device_activated(device: StdInputDevice) -> void:
	device_id = device.device_id
	device_type = device.device_type


func _on_Self_device_connected(device: StdInputDevice) -> void:
	var action_set := actions.get_action_set(device_id)
	if not action_set:
		return

	if not device.load_action_set(action_set):
		return

	for layer in actions.list_action_set_layers(device_id):
		device.enable_action_set_layer(layer)


func _on_Self_device_disconnected(_device: StdInputDevice) -> void:
	pass  # No need to disable action sets/layers here - the device may reconnect.


# -- SETTERS/GETTERS ----------------------------------------------------------------- #


## set_joypad_monitor swaps the joypad monitor implementation to the one provided. This
## will cause all connected joypads to disconnect, at which point they should be
## reconnected once the new joypad monitor is ready.
##
## NOTE: This method will *not* remove the prior `JoypadMonitor` from the scene nor add
## the new one to the scene.
func set_joypad_monitor(node: JoypadMonitor) -> void:
	assert(node is JoypadMonitor, "invalid argument; wrong type")

	if node == joypad_monitor:
		return

	if joypad_monitor:
		for joypad in _joypad_devices:
			if joypad == _active:
				_active = null

			_disconnect_joy_device(joypad.device_id)

		Signals.disconnect_safe(joypad_monitor.joy_connected, _connect_joy_device)
		Signals.disconnect_safe(joypad_monitor.joy_disconnected, _disconnect_joy_device)

	joypad_monitor = node

	if is_inside_tree():
		Signals.connect_safe(node.joy_connected, _connect_joy_device)
		Signals.connect_safe(node.joy_disconnected, _disconnect_joy_device)

		node.broadcast_connected_joypads()
