# gdlint:disable=max-file-lines
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
## The slot accepts input from every connected device at all times; the active device
## only decides which glyphs are shown and which device haptics target. A press bound to
## an active action activates its device, as does a reveal-button click while
## `StdInputActionSet.cursor_click_activates_kbm` is on. A joypad connected before the
## player's first input is activated over the keyboard when preferred; one connected
## after that is only connected, so a hot-plug leaves the prompts alone while another
## device is active. Mouse motion never activates a device, since Steam Input emits it
## for gyro and trackpad input; see
## https://partner.steamgames.com/doc/steamhardware/recommendations.
##
## TODO: For now, this class only supports single player because there's no way to
## filter out device indices. Given that Godot has limited-at-best support for local
## multiplayer, this is not a priority.
##

class_name StdInputSlot
extends StdInputDevice

# -- SIGNALS ------------------------------------------------------------------------- #

## action_hold_cancelled is emitted when a hold ends before its fill, through the
## player's input or an interruption: a device swap, the loss of the joypad which
## tapped a toggle, focus loss, leaving the tree, or a change which alters the hold.
signal action_hold_cancelled(action: StringName)

## action_hold_progress_changed is emitted when `get_action_hold_progress` changes,
## which includes its drop to `0.0` as the hold ends. A prompt shows the fill here.
##
## NOTE: A prompt's button which raises the action through `StdInputActionTrigger` must
## use `BaseButton.ACTION_MODE_BUTTON_PRESS`, or a click can't fill a `MODE_HOLD` hold.
signal action_hold_progress_changed(action: StringName, progress: float)

## action_hold_started is emitted when a hold starts. Either `action_hold_triggered` or
## `action_hold_cancelled` follows.
signal action_hold_started(action: StringName)

## action_hold_triggered is emitted when a hold fills, which ends it. A handler acts on
## the hold here. In `MODE_PRESS` it's emitted on the press.
##
## NOTE: A hold consumes no input, so a handler connected here must not also act on the
## raw press in `_unhandled_input`.
signal action_hold_triggered(action: StringName)

## action_pressed is emitted on an active action's first press from any device, with the
## event's `device`, such as `InputEvent.DEVICE_ID_KEYBOARD` for a key. An input already
## down when its action became active, or when a swap ended its hold, needs a new press.
signal action_pressed(action: StringName, device: int)

## action_released is emitted when that hold ends, with the ID on the ending event, or
## the ID which started the hold when no event ended it.
signal action_released(action: StringName, device: int, held_seconds: float)

## cursor_visibility_changed is emitted when this slot's cursor visibility changes. This
## is only used if a `cursor` property is set.
signal cursor_visibility_changed(visible: bool)

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

## origin_labels_changed is emitted when the names of origins may have changed while
## their bindings didn't. That happens on a keyboard layout switch, which relabels
## keys, and on a locale change. A glyph which shows a label redraws on it.
signal origin_labels_changed

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")
const StdInputSlotDeviceActions := preload("slot_actions.gd")
const StdInputSlotDeviceGlyphs := preload("slot_glyphs.gd")
const StdInputSlotDeviceHaptics := preload("slot_haptics.gd")
const StdInputSlotGestures := preload("slot_gestures.gd")
const StdInputSlotHeldActions := preload("slot_held_actions.gd")

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
##
## NOTE: If `false`, a key or mouse button starts no hold, but `Input` still counts one
## that's down, so it prolongs a joypad's hold.
@export var claim_kbm_input: bool = true

## prefer_activate_joypad_on_ready defines whether a joypad connected before the
## player's first input is activated over the keyboard, which the slot activates when it
## loads. That input is a bound key press, a click which activates the keyboard, or a
## bound press on a connected joypad. Joypad monitors can report controllers a few
## frames after `_ready`, so the preference lasts until that input rather than until the
## slot is ready. A joypad connected later is only connected.
@export var prefer_activate_joypad_on_ready: bool = true

@export_group("Properties")

## haptics_disabled_property is a settings property which controls whether haptics are
## completely disabled.
@export var haptics_disabled_property: StdSettingsPropertyBool = null

## haptics_strength_property is a settings property which controls the strength of
## triggered haptic effects.
@export var haptics_strength_property: StdSettingsPropertyFloatRange = null

## hold_duration_scale_property is an optional settings property whose value multiplies
## each hold's `duration`. A value of `0` or less is ignored.
@export var hold_duration_scale_property: StdSettingsPropertyFloatRange = null:
	set(value):
		hold_duration_scale_property = value
		_gestures.set_properties(hold_mode_property, hold_duration_scale_property)

## hold_mode_property is an optional settings property which, while it holds anything
## but `MODE_INHERIT`, chooses the `StdInputActionHold.Mode` of each hold, unless that
## hold's `mode_override` chooses first.
##
## NOTE: It should default to `MODE_INHERIT` and offer it, since any other default
## overrides each hold's `mode`.
@export var hold_mode_property: StdSettingsPropertyInt = null:
	set(value):
		hold_mode_property = value
		_gestures.set_properties(hold_mode_property, hold_duration_scale_property)

@export_group("Components")

## cursor is a node which manages the visibility state of the game's cursor. This is an
## optional component, but only one `StdInputSlot` at most may have one.
@export var cursor: StdInputCursor = null

## joypad_monitor is a node which monitors joypad activity. This `StdInputSlot` node
## will manage active input devices based on the monitor's signals.
@export var joypad_monitor: JoypadMonitor = null

@export_subgroup("Keyboard and mouse")

## actions_kbm is the actions component for keyboard and mouse.
@export var actions_kbm: StdInputDeviceActions = null

## glyphs_kbm is the glyphs component for keyboard and mouse.
@export var glyphs_kbm: StdInputDeviceGlyphs = null

## haptics_kbm is the haptics component for keyboard and mouse.
@export var haptics_kbm: StdInputDeviceHaptics = null

@export_subgroup("Joypad")

## actions_joy is the actions component for joypads.
@export var actions_joy: StdInputDeviceActions = null

## glyphs_joy is the glyphs component for joypads.
@export var glyphs_joy: StdInputDeviceGlyphs = null

## haptics_joy is the haptics component for joypads.
@export var haptics_joy: StdInputDeviceHaptics = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _actions: Array[String] = []
var _active: StdInputDevice = null
var _cursor_click_activates_kbm: bool = false

## _gestures runs the holds the active sets declare.
var _gestures: StdInputSlotGestures = null

var _has_player_input: bool = false
var _joypad_devices: Array[StdInputDevice] = []
var _kbm_device: StdInputDevice = null

## _keyboard_layout is the index of the keyboard layout at the last poll.
var _keyboard_layout: int = DisplayServer.keyboard_get_current_layout()

var _last_active_joypad: StdInputDevice = null

## _pressed maps each joypad's device ID to the active actions it holds, so a hold can't
## activate that joypad again and ends only with that joypad's own release.
var _pressed: Dictionary[int, Array] = {}

## _held_actions times the active actions held on every device.
var _held_actions: StdInputSlotHeldActions = null

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


## for_player finds the `StdInputSlot` in the scene tree that's assigned to the
## specified player. Note that there can be only one `StdInputSlot` per player.
static func for_player(player: int) -> StdInputSlot:
	for member in StdGroup.with_id(GROUP_INPUT_SLOT).list_members():
		assert(member is StdInputSlot, "invalid state; wrong member type")

		if member.player_id == player:
			return member

	return null


## get_action_held_seconds returns the wall clock seconds since `action` was first
## pressed on any device, or `0.0` while it isn't held. A hold also ends when its action
## leaves the active sets, on a joypad component swap, and on leaving the tree.
##
## NOTE: `Input` can read `action` as pressed while this is `0.0`; see `action_pressed`.
func get_action_held_seconds(action: StringName) -> float:
	return _held_actions.get_held_seconds(action)


# Holds


## get_action_hold returns the hold an active set declares on `action`, or `null` when
## `action` is no hold. A layer's hold replaces one from anything enabled before it.
func get_action_hold(action: StringName) -> StdInputActionHold:
	return _gestures.get_hold(action)


## get_action_hold_mode returns the mode `action`'s hold runs in, which is never
## `MODE_INHERIT`, or `MODE_PRESS` when `action` is no hold.
##
## NOTE: A setting can change this while nothing is running, with no signal from here.
func get_action_hold_mode(action: StringName) -> StdInputActionHold.Mode:
	return _gestures.get_mode(action)


## get_action_hold_progress returns how far `action`'s hold has filled, from `0.0` to
## `1.0`, or `0.0` while it isn't active.
func get_action_hold_progress(action: StringName) -> float:
	return _gestures.get_progress(action)


## is_action_hold_active returns whether `action`'s hold has started and hasn't ended. A
## `MODE_TOGGLE` hold stays active after its press is released.
func is_action_hold_active(action: StringName) -> bool:
	return _gestures.is_active(action)


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


## get_joypad_device_type returns the type of joypad whose glyphs should stand for "a
## controller": the last active joypad's, else the first connected joypad's, else
## `DEVICE_TYPE_GENERIC` when none is connected.
func get_joypad_device_type() -> DeviceType:
	if _last_active_joypad:
		return _last_active_joypad.device_type

	if _joypad_devices:
		return _joypad_devices[0].device_type

	return DEVICE_TYPE_GENERIC


## swap_joypad_components swaps in the joypad monitor and device components provided,
## which disconnects every joypad until the new monitor reports it. It then emits
## `action_configuration_changed`, so glyphs redraw from the new components.
##
## NOTE: This method will *not* remove the prior `JoypadMonitor` from the scene nor add
## the new one to the scene.
func swap_joypad_components(
	next_joypad_monitor: JoypadMonitor,
	next_device_actions: StdInputDeviceActions,
	next_device_glyphs: StdInputDeviceGlyphs,
	next_device_haptics: StdInputDeviceHaptics,
) -> void:
	assert(next_joypad_monitor, "missing argument")
	assert(next_device_actions, "missing argument")
	assert(next_device_glyphs, "missing argument")
	assert(next_device_haptics, "missing argument")

	_logger.debug("Swapping device components for input slot.", {&"player": player_id})

	var action_sets := _list_action_sets()

	if joypad_monitor:
		# NOTE: Disconnecting removes from the list, so a copy is iterated.
		for joypad in _joypad_devices.duplicate():
			_disconnect_joy_device(joypad.device_id)

		Signals.disconnect_safe(joypad_monitor.joy_connected, _connect_joy_device)
		Signals.disconnect_safe(
			joypad_monitor.joy_disconnected, _on_joypad_monitor_joy_disconnected
		)

	# NOTE: An action held on a joypad the old monitor never reported may never release,
	# and would block a press from the joypad the next monitor gives its device ID.
	_pressed.clear()

	# NOTE: The keyboard may share the joypad's actions component, in which case its
	# connection must survive the swap.
	if actions_joy and actions_joy != actions_kbm:
		Signals.disconnect_safe(
			actions_joy.bindings_changed, _on_component_bindings_changed
		)

	actions_joy = next_device_actions
	glyphs_joy = next_device_glyphs
	haptics_joy = next_device_haptics
	joypad_monitor = next_joypad_monitor

	Signals.connect_safe(joypad_monitor.joy_connected, _connect_joy_device)
	Signals.connect_safe(
		joypad_monitor.joy_disconnected, _on_joypad_monitor_joy_disconnected
	)
	Signals.ensure_connected(
		actions_joy.bindings_changed, _on_component_bindings_changed
	)

	joypad_monitor.broadcast_connected_joypads()

	for joypad in _joypad_devices:
		for action_set in action_sets:
			if action_set is StdInputActionSetLayer:
				joypad.enable_action_set_layer(action_set)
				continue

			joypad.load_action_set(action_set)

	# NOTE: These come last, since a listener can load a set, which every joypad must
	# then keep rather than have `action_sets` replace. Gestures are cancelled first, so
	# the release can't trigger a fill no frame has reported.
	_gestures.cancel_all()
	_held_actions.release_all()

	action_configuration_changed.emit()


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
	# NOTE: A hold's prompt can sit in a pause menu, so input runs in a paused tree.
	process_mode = Node.PROCESS_MODE_ALWAYS

	assert(
		not StdGroup.with_id(GROUP_INPUT_SLOT).list_members().any(
			func(m): return m.player_id == player_id
		),
		"invalid state; duplicate input slot found",
	)
	StdGroup.with_id(GROUP_INPUT_SLOT).add_member(self)

	assert(joypad_monitor is JoypadMonitor, "invalid config; missing component")
	Signals.connect_safe(joypad_monitor.joy_connected, _connect_joy_device)
	Signals.connect_safe(
		joypad_monitor.joy_disconnected, _on_joypad_monitor_joy_disconnected
	)

	# NOTE: The keyboard and joypads may share one actions component, which is then
	# connected once.
	for component in [actions_kbm, actions_joy]:
		if component is StdInputDeviceActions:
			Signals.ensure_connected(
				component.bindings_changed, _on_component_bindings_changed
			)

	Signals.connect_safe(
		action_configuration_changed, _on_Self_action_configuration_changed
	)
	Signals.connect_safe(device_activated, _on_Self_device_activated)
	Signals.connect_safe(device_connected, _on_Self_device_connected)
	Signals.connect_safe(device_disconnected, _on_Self_device_disconnected)

	# NOTE: Connect after initializing devices to avoid inadvertent device activation.
	assert(cursor is StdInputCursor, "invalid config; missing component")
	Signals.connect_safe(
		cursor.cursor_visibility_changed, _on_cursor_visibility_changed
	)


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
	Signals.disconnect_safe(
		joypad_monitor.joy_disconnected, _on_joypad_monitor_joy_disconnected
	)

	for component in [actions_kbm, actions_joy]:
		if component is StdInputDeviceActions:
			Signals.disconnect_safe(
				component.bindings_changed, _on_component_bindings_changed
			)

	_active = null

	if _kbm_device:
		var kbm := _kbm_device
		_kbm_device = null

		device_disconnected.emit(kbm)

		remove_child(kbm)
		kbm.queue_free()

	# NOTE: Disconnecting removes from the list, so a copy is iterated.
	for joypad in _joypad_devices.duplicate():
		_disconnect_joy_device(joypad.device_id)

	_joypad_devices = []

	# NOTE: Gestures are cancelled first, so the release can't trigger an unreported fill.
	_gestures.cancel_all()
	_held_actions.release_all()


func _init() -> void:
	_gestures = StdInputSlotGestures.new()
	_held_actions = StdInputSlotHeldActions.new()

	Signals.connect_safe(_held_actions.action_pressed, action_pressed.emit)
	Signals.connect_safe(_held_actions.action_released, action_released.emit.unbind(1))

	# NOTE: These follow the connections above, so a gesture's signal follows the raw
	# press or release it comes from.
	Signals.connect_safe(_held_actions.action_pressed, _gestures.press)
	Signals.connect_safe(
		_held_actions.action_released, _on_held_actions_action_released
	)

	Signals.connect_safe(_gestures.action_hold_cancelled, action_hold_cancelled.emit)
	Signals.connect_safe(
		_gestures.action_hold_progress_changed, action_hold_progress_changed.emit
	)
	Signals.connect_safe(_gestures.action_hold_started, action_hold_started.emit)
	Signals.connect_safe(_gestures.action_hold_triggered, action_hold_triggered.emit)


func _input(event: InputEvent) -> void:
	if not event.is_action_type():
		return

	# NOTE: A pressed event can release a tracked action too, as a stick flicked from
	# one side to the other releases the first direction without a centered event.
	var held: Array = _pressed.get(event.device, [])
	for action in held.duplicate():
		if StdInputSlotHeldActions.is_action_released(event, action):
			held.erase(action)

	if event.is_pressed() and not _try_activate_joypad(event):
		_try_activate_kbm(event)

	var is_kbm := event is InputEventKey or event is InputEventMouseButton

	# NOTE: This follows activation, so a listener reads the device which just pressed.
	if claim_kbm_input or not is_kbm:
		_held_actions.update(event, _pressed)
		_update_processing()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# NOTE: Losing focus interrupts every gesture, including a toggle, which
			# ignores the releases Godot makes as it happens.
			_gestures.cancel_all()

		NOTIFICATION_INTERNAL_PROCESS:
			_poll_keyboard_layout()

		NOTIFICATION_TRANSLATION_CHANGED:
			# NOTE: A node entering the tree gets this before it's ready, with no change
			# of locale behind it.
			if is_node_ready():
				origin_labels_changed.emit()


func _process(_delta: float) -> void:
	_held_actions.poll()
	_gestures.poll()
	_update_processing()


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

	# NOTE: No engine signal reports a keyboard layout switch, so it's polled each frame.
	# Internal processing keeps this apart from `_process`, which runs only during holds.
	set_process_internal(true)

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

		_logger.debug(
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

		_logger.debug(
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
	@warning_ignore("SHADOWED_VARIABLE_BASE_CLASS")
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

	if (
		not _active
		or (
			_active == _kbm_device
			and prefer_activate_joypad_on_ready
			and not _has_player_input
		)
	):
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

		# NOTE: The slot's device ID and type keep depicting the removed joypad until
		# the next deliberate input, but a glyph refreshed meanwhile is looked up with
		# no joypad, which leaves one from a per-device component like Steam's empty.
		if _active == joypad:
			_active = null
		if _last_active_joypad == joypad:
			_last_active_joypad = null

		device_disconnected.emit(joypad)

		remove_child(joypad)
		joypad.queue_free()

		# NOTE: An action held on the removed joypad would never be released.
		_pressed.erase(device)

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
	@warning_ignore("SHADOWED_VARIABLE_BASE_CLASS")
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


## _poll_keyboard_layout emits `origin_labels_changed` if the keyboard layout switched
## since the last poll.
##
## NOTE: This compares the layout rather than its language, since a key's label comes
## from the layout, and two layouts of one language can label keys differently.
func _poll_keyboard_layout() -> void:
	var layout := DisplayServer.keyboard_get_current_layout()
	if layout == _keyboard_layout:
		return

	_keyboard_layout = layout
	origin_labels_changed.emit()


## _try_activate_joypad activates the joypad which just pressed one of the active
## actions and returns whether it did. Key and mouse button events are ignored.
func _try_activate_joypad(event: InputEvent) -> bool:
	if not (
		event is InputEventJoypadButton
		or event is InputEventJoypadMotion
		or event is InputEventAction
	):
		return false

	# NOTE: Every action an event presses is tracked, even on the active joypad, so an
	# input held across a switch to the keyboard can't switch back until released.
	var held: Array = _pressed.get_or_add(event.device, [])
	var is_held := false
	var is_match := false
	for action in _actions:
		if not StdInputSlotHeldActions.is_action_pressed(event, action):
			continue

		if action in held:
			is_held = true
			continue

		held.append(action)
		is_match = true

	# NOTE: A held or new press counts as player input only from a reported joypad, so
	# one pressed before its monitor reports it still activates once it connects.
	var is_reported := _joypad_devices.any(func(d): return d.device_id == event.device)
	if (is_held or is_match) and is_reported:
		_has_player_input = true

	if is_held or not is_match:
		return false

	if (
		_active
		and _active.device_type != DEVICE_TYPE_KEYBOARD
		and _active.device_id == event.device
	):
		return false

	for joypad in _joypad_devices:
		if not joypad:
			assert(false, "invalid state; missing device")
			continue

		if event.device != joypad.device_id:
			continue

		return _activate_device(joypad)

	return false


## _try_activate_kbm activates the keyboard and mouse device on a key or mouse button
## press of an active action, or on a reveal-button click while
## `cursor_click_activates_kbm` is on, and returns whether it did.
##
## NOTE: A mouse button which Godot emulates from a touch is skipped, since a touch
## comes from a touchscreen rather than a mouse.
func _try_activate_kbm(event: InputEvent) -> bool:
	if not claim_kbm_input:
		return false

	if not (event is InputEventKey or event is InputEventMouseButton):
		return false

	if (
		event is InputEventMouseButton
		and event.device == InputEvent.DEVICE_ID_EMULATION
	):
		return false

	var is_match: bool = (
		_cursor_click_activates_kbm
		and event is InputEventMouseButton
		and event.button_index in cursor.get_reveal_mouse_buttons()
	)

	if not is_match:
		for action in _actions:
			if StdInputSlotHeldActions.is_action_pressed(event, action):
				is_match = true
				break

	if not is_match:
		return false

	# NOTE: A bound press counts as the player's first input even while the keyboard is
	# already active, so a joypad connected afterwards is only connected.
	_has_player_input = true

	if _active and _active.device_type == DEVICE_TYPE_KEYBOARD:
		return false

	return _activate_device(_kbm_device)


## _update_processing runs `_process` only while it has something to do. A `MODE_TOGGLE`
## gesture can outlive its action's hold.
func _update_processing() -> void:
	set_process(_held_actions.is_tracking() or _gestures.is_tracking())


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_component_bindings_changed() -> void:
	# NOTE: A component can reload before the slot is ready, such as when a scene change
	# creates a new component while the active set survives in its static state, and
	# the slot has no configuration to recompute until it loads a set itself.
	if not is_node_ready():
		return

	action_configuration_changed.emit()


func _on_cursor_visibility_changed(visible: bool) -> void:
	cursor_visibility_changed.emit(visible)


func _on_held_actions_action_released(
	action: StringName, _device: int, _held_seconds: float, is_interrupted: bool
) -> void:
	_gestures.release(action, is_interrupted)


func _on_joypad_monitor_joy_disconnected(device: int) -> void:
	if not _disconnect_joy_device(device):
		return

	# NOTE: A hold ends once no device holds its action, but a toggle fills with nothing
	# held, so the loss of the joypad which tapped it must end it.
	_gestures.cancel_toggles(device)


func _on_Self_action_configuration_changed() -> void:
	# NOTE: This comes first, so a hold the change drops is cancelled rather than ended by
	# the release below. A listener can load a set, so the sets are listed after it.
	_gestures.configure(_list_action_sets(device_id, false))

	var action_sets := _list_action_sets(device_id, false)

	_actions = []
	_cursor_click_activates_kbm = false

	var hold_actions: Array[StringName] = []

	# NOTE: These must be iterated in forward order so that later action set layers can
	# override properties set in earlier action sets.
	for action_set in action_sets:
		# Update cursor properties.
		_cursor_click_activates_kbm = (
			false
			if action_set.cursor_click_activates_kbm == PROPERTY_STATUS_OFF
			else (
				_cursor_click_activates_kbm
				or action_set.cursor_click_activates_kbm == PROPERTY_STATUS_ON
			)
		)

		# Update active actions.

		# NOTE: Steam publishes the absolute mouse action as joypad activity, so a
		# trackpad or gyro in use counts as the joypad being used.
		for action in action_set.list_action_names(true):
			assert(action not in _actions, "found duplicate action")
			_actions.append(action)

		# NOTE: The absolute mouse action only marks joypad activity, so it's never held.
		for action in action_set.list_action_names():
			hold_actions.append(StringName(action))

	# NOTE: A set change can erase the origins of a held action, so its release could
	# never match; an action the active sets no longer bind is dropped instead.
	for held in _pressed.values():
		for action in held.duplicate():
			if action not in _actions:
				held.erase(action)

	if cursor is StdInputCursor:
		cursor.update_configuration(action_sets)

	# NOTE: This comes last, since a listener can load a set, whose configuration must
	# then outlive this one.
	_held_actions.set_actions(hold_actions)
	_update_processing()


func _on_Self_device_activated(device: StdInputDevice) -> void:
	device_id = device.device_id
	device_type = device.device_type


func _on_Self_device_connected(device: StdInputDevice) -> void:
	var action_set := actions.get_action_set(device_id)
	if not action_set:
		return

	# NOTE: The layers are enabled even when the set reports no change, since a
	# component which already holds the set needn't hold its layers.
	device.load_action_set(action_set)

	# NOTE: A component can refuse the set, as Steam's does for one missing from its
	# manifest, which leaves no set for the layers to go on.
	if device.actions.get_action_set(device.device_id) != action_set:
		return

	for layer in actions.list_action_set_layers(device_id):
		device.enable_action_set_layer(layer)


func _on_Self_device_disconnected(_device: StdInputDevice) -> void:
	pass  # No need to disable action sets/layers here - the device may reconnect.
