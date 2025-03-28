##
## std/input/device.gd
##
## StdInputDevice is a node which provides an interface for a single player input
## device. Implementations of various features can be specified by overriding its
## components.
##

class_name StdInputDevice
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## action_configuration_changed is emitted any time an action set-related change occurs.
signal action_configuration_changed

## action_set_loaded is emitted any time an action set is loaded (i.e. activated).
signal action_set_loaded(action_set: StdInputActionSet)

## action_set_layer_enabled is emitted when an action set layer is enabled.
signal action_set_layer_enabled(action_set_layer: StdInputActionSetLayer)

## action_set_layer_disabled is emitted when an action set layer is disabled.
signal action_set_layer_disabled(action_set_layer: StdInputActionSetLayer)

# -- DEFINITIONS --------------------------------------------------------------------- #

## DeviceType is an enumeration of the categories of player input devices.
enum DeviceType {
	UNKNOWN = 0,
	GENERIC = 1,
	KEYBOARD = 2,  # Includes mouse devices.
	PS_4 = 3,
	PS_5 = 4,
	STEAM_CONTROLLER = 5,
	STEAM_DECK = 6,
	SWITCH_JOY_CON_PAIR = 7,
	SWITCH_JOY_CON_SINGLE = 8,
	SWITCH_PRO = 9,
	TOUCH = 10,
	XBOX_360 = 11,
	XBOX_ONE = 12,
}

## DEVICE_TYPE_UNKNOWN defines an unknown device type.
const DEVICE_TYPE_UNKNOWN := DeviceType.UNKNOWN

## DEVICE_TYPE_GENERIC defines an unspecified joypad device type (suitable for XInput
## devices and as a fallback).
const DEVICE_TYPE_GENERIC := DeviceType.GENERIC

## DEVICE_TYPE_KEYBOARD defines a keyboard + mouse device type.
const DEVICE_TYPE_KEYBOARD := DeviceType.KEYBOARD

## DEVICE_TYPE_PS_4 defines a PlayStation 4 joypad.
const DEVICE_TYPE_PS_4 := DeviceType.PS_4

## DEVICE_TYPE_PS_5 defines a PlayStation 5 joypad.
const DEVICE_TYPE_PS_5 := DeviceType.PS_5

## DEVICE_TYPE_STEAM_CONTROLLER defines a Steam controller joypad.
const DEVICE_TYPE_STEAM_CONTROLLER := DeviceType.STEAM_CONTROLLER

## DEVICE_TYPE_STEAM_DECK defines a Steam deck joypad.
const DEVICE_TYPE_STEAM_DECK := DeviceType.STEAM_DECK

## DEVICE_TYPE_SWITCH_JOY_CON_PAIR defines a pair of Nintendo Switch Joy-Con devices.
const DEVICE_TYPE_SWITCH_JOY_CON_PAIR := DeviceType.SWITCH_JOY_CON_PAIR

## DEVICE_TYPE_SWITCH_JOY_CON_SINGLE defines a single Nintendo Switch Joy-Con device.
const DEVICE_TYPE_SWITCH_JOY_CON_SINGLE := DeviceType.SWITCH_JOY_CON_SINGLE

## DEVICE_TYPE_SWITCH_PRO defines a Nintendo Switch Pro controller.
const DEVICE_TYPE_SWITCH_PRO := DeviceType.SWITCH_PRO

## DEVICE_TYPE_TOUCH defines touchscreen input.
const DEVICE_TYPE_TOUCH := DeviceType.TOUCH

## DEVICE_TYPE_XBOX_360 defines an Xbox 360 joypad.
const DEVICE_TYPE_XBOX_360 := DeviceType.XBOX_360

## DEVICE_TYPE_XBOX_ONE defines an Xbox ONE joypad.
const DEVICE_TYPE_XBOX_ONE := DeviceType.XBOX_ONE

## DEVICE_ID_ALL is a special identifier for matching all device ID's within InputMap.
##
## NOTE: See https://github.com/godotengine/godot/pull/99449; '-1' values may change in
## the future.
const DEVICE_ID_ALL := -1

# -- CONFIGURATION ------------------------------------------------------------------- #

## device_id is the device ID, which is unique to the input paradigm; touch, keyboard,
## mouse and joypads all have separate scopes for the device index.
##
## NOTE: Despite keyboard device IDs potentially conflicting with mouse IDs, this class
## cannot be used to represent a mouse. Instead, keyboard and mouse are grouped together
## under the keyboard+mouse paradigm. The `index` would refer to the keyboard's index in
## that case (which is expected to be `0` in all cases because Godot/Windows does not
## seem to distinguish between different keyboards).
@export var device_id: int = 0

## device_type is the `DeviceType` of the `StdInputDevice`.
@export var device_type: DeviceType = DEVICE_TYPE_UNKNOWN

## device_category is a `DeviceType` representing which category of controller the input
## device falls under. This can be one of `DEVICE_TYPE_KEYBOARD`, `DEVICE_TYPE_GENERIC`,
## or `DEVICE_TYPE_UNKNOWN`.
@export var device_category: DeviceType:
	get = _get_device_category

@export_group("Components")

## actions is the input device's component which manages loaded/enabled action sets.
@export var actions: StdInputDeviceActions = null

## glyphs is the input device's component which fetches origin glyphs.
@export var glyphs: StdInputDeviceGlyphs = null

## haptics is the input device's component which provides haptic feedback (i.e.
## vibrations).
@export var haptics: StdInputDeviceHaptics = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create("std/input/device")

# -- PUBLIC METHODS ------------------------------------------------------------------ #

@warning_ignore("SHADOWED_VARIABLE")


## get_device_category returns the category of input device for the specified device
## type. This can be one of `DEVICE_TYPE_KEYBOARD`, `DEVICE_TYPE_GENERIC`, or
## `DEVICE_TYPE_UNKNOWN`.
static func get_device_category(
	device_type: DeviceType,
) -> DeviceType:
	if device_type == DEVICE_TYPE_UNKNOWN:
		return DEVICE_TYPE_UNKNOWN

	if device_type == DEVICE_TYPE_KEYBOARD:
		return DEVICE_TYPE_KEYBOARD

	return DEVICE_TYPE_GENERIC


# Events


## is_matching_event_origin returns whether the provided input event originated from
## this input device.
func is_matching_event_origin(event: InputEvent) -> bool:
	match device_type:
		DEVICE_TYPE_UNKNOWN:
			assert(false, "invalid state; missing device type")
			return false
		DEVICE_TYPE_KEYBOARD:
			assert(event.device == device_id, "invalid state; conflicting device ID")

			return event is InputEventKey or event is InputEventMouse
		DEVICE_TYPE_TOUCH:
			assert(event.device == device_id, "invalid state; conflicting device ID")

			return (
				event is InputEventScreenTouch
				or event is InputEventScreenDrag
				or event is InputEventGesture
			)
		_:
			return (
				event.device == device_id
				and (event is InputEventJoypadButton or event is InputEventJoypadMotion)
			)


# Action sets


## load_action_set unbinds any actions currently bound (including activated layers) and
## then binds the actions defined within the action set. Does nothing if the action set
## is already activated.
func load_action_set(action_set: StdInputActionSet) -> bool:
	assert(action_set is StdInputActionSet, "missing argument: action set")
	assert(
		not action_set is StdInputActionSetLayer, "invalid argument: cannot be a layer"
	)
	assert(actions is StdInputDeviceActions, "invalid state; missing component")

	var layers := actions.list_action_set_layers(device_id)

	if not actions.load_action_set(device_id, action_set):
		return false

	assert(actions.get_action_set(device_id), "invalid state; missing action set")
	assert(
		not actions.list_action_set_layers(device_id), "invalid state; dangling layers"
	)

	layers.reverse()
	for layer in layers:
		action_set_layer_disabled.emit(layer)

	action_set_loaded.emit(action_set)
	action_configuration_changed.emit()

	_logger.info(
		"Loaded action set.",
		{&"device": device_id, &"type": device_type, &"set": action_set.name}
	)

	return true


# Action set layers


## disable_action_set_layer unbinds all of the actions defined within the layer. Does
## nothing if not activated.
##
## NOTE: The parent action set of the layer *must* be activated, otherwise no action is
## taken.
func disable_action_set_layer(layer: StdInputActionSetLayer) -> bool:
	assert(layer is StdInputActionSetLayer, "invalid argument: layer")
	assert(actions is StdInputDeviceActions, "invalid state; missing component")

	if not actions.disable_action_set_layer(device_id, layer):
		return false

	# NOTE: Some implementations (e.g. Steam) may not have their state updated until
	# player input is received, so do not assert the layer is removed.

	action_set_layer_disabled.emit(layer)
	action_configuration_changed.emit()

	_logger.info(
		"Disabled action set layer.",
		{&"device": device_id, &"type": device_type, &"layer": layer.name}
	)

	return true


## enable_action_set_layer binds all of the actions defined within the layer. All
## *conflicting* origins from either the base action set or prior layers will be
## overridden (unbound from prior actions and bound to the action in this layer). Does
## nothing if already activated.
##
## NOTE: The parent action set of the layer *must* be activated, otherwise no action is
## taken.
func enable_action_set_layer(layer: StdInputActionSetLayer) -> bool:
	assert(layer is StdInputActionSetLayer, "invalid argument: layer")
	assert(actions is StdInputDeviceActions, "invalid state; missing component")

	if not actions.enable_action_set_layer(device_id, layer):
		return false

	# NOTE: Some implementations (e.g. Steam) may not have their state updated until
	# player input is received, so do not assert the layer is present.

	action_set_layer_enabled.emit(layer)
	action_configuration_changed.emit()

	_logger.info(
		"Enabled action set layer.",
		{&"device": device_id, &"type": device_type, &"layer": layer.name}
	)

	return true


## list_action_set_layers returns a list of enabled action set layers for the device.
func list_action_set_layers() -> Array[StdInputActionSetLayer]:
	assert(actions is StdInputDeviceActions, "invalid state; missing component")
	return actions.list_action_set_layers(device_id)


# Glyphs


## get_action_glyph returns a `Texture2D` containing the glyph of the primary (i.e.
## first) controller origin which will actuate the specified action.
func get_action_glyph(
	action_set: StdInputActionSet,
	action: StringName,
	index: int = 0,
	target_size: Vector2 = Vector2.ZERO,
	device_type_override: DeviceType = DEVICE_TYPE_UNKNOWN,
) -> Texture2D:
	assert(glyphs is StdInputDeviceGlyphs, "invalid state; missing component")

	if device_type_override == DEVICE_TYPE_UNKNOWN:
		device_type_override = device_type

	return glyphs.get_action_glyph(
		device_id, device_type_override, action_set, action, index, target_size
	)


## get_action_origin_label returns a localized display name for the first origin bound
## to the specified action.
func get_action_origin_label(
	action_set: StdInputActionSet,
	action: StringName,
	index: int = 0,
	device_type_override: DeviceType = DEVICE_TYPE_UNKNOWN,
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

	return haptics.start_vibrate_strong(device_id, duration, clampf(strength, 0.0, 1.0))


## start_vibrate_weak initiates an input device vibration for `duration` seconds using
## the device's weak vibration motor, if available.
func start_vibrate_weak(duration: float, strength: float = 1.0) -> void:
	assert(haptics is StdInputDeviceHaptics, "invalid state; missing component")

	return haptics.start_vibrate_weak(device_id, duration, clampf(strength, 0.0, 1.0))


## stop_vibrate terminates all ongoing vibration for the input device.
func stop_vibrate() -> void:
	assert(haptics is StdInputDeviceHaptics, "invalid state; missing component")

	return haptics.stop_vibrate(device_id)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	if not haptics:
		haptics = StdInputDeviceHaptics.NoOp.new()
		add_child(haptics, false, INTERNAL_MODE_BACK)

	assert(actions is StdInputDeviceActions, "invalid config; missing component")
	assert(glyphs is StdInputDeviceGlyphs, "invalid config; missing component")
	assert(haptics is StdInputDeviceHaptics, "invalid config; missing component")


# -- SETTERS/GETTERS ----------------------------------------------------------------- #


func _get_device_category() -> StdInputDevice.DeviceType:
	return get_device_category(device_type)
