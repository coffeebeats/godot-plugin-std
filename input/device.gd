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

# action_set_loaded is emitted any time an action set is loaded (i.e. activated).
signal action_set_loaded(action_set: StdInputActionSet)

## action_set_layer_enabled is emitted when an action set layer is enabled.
signal action_set_layer_enabled(action_set_layer: StdInputActionSetLayer)

## action_set_layer_disabled is emitted when an action set layer is disabled.
signal action_set_layer_disabled(action_set_layer: StdInputActionSetLayer)

# -- DEFINITIONS --------------------------------------------------------------------- #

## DeviceType is an enumeration of the categories of player input devices.
enum DeviceType {
	UNKNOWN = 0,
	KEYBOARD = 1,
	NINTENDO_SWITCH = 2,
	PLAYSTATION = 3,
	STEAM_DECK = 4,
	STEAM_CONTROLLER = 5,
	XBOX = 6,
}

## DEVICE_TYPE_UNKNOWN defines an unknown device type (also represents an unspecified
## `InputDeviceType` value).
const DEVICE_TYPE_UNKNOWN := DeviceType.UNKNOWN

## DEVICE_TYPE_KEYBOARD defines a keyboard + mouse device type.
const DEVICE_TYPE_KEYBOARD := DeviceType.KEYBOARD

## DEVICE_TYPE_NINTENDO_SWITCH defines a Nintendo Switch joypad (e.g. pro controller or
## joycons).
const DEVICE_TYPE_NINTENDO_SWITCH := DeviceType.NINTENDO_SWITCH

## DEVICE_TYPE_PLAYSTATION defines a PlayStation joypad.
const DEVICE_TYPE_PLAYSTATION := DeviceType.PLAYSTATION

## DEVICE_TYPE_STEAM_DECK defines a Steam deck joypad.
const DEVICE_TYPE_STEAM_DECK := DeviceType.STEAM_DECK

## DEVICE_TYPE_STEAM_CONTROLLER defines a Steam controller joypad.
const DEVICE_TYPE_STEAM_CONTROLLER := DeviceType.STEAM_CONTROLLER

## DEVICE_TYPE_XBOX defines an Xbox joypad.
const DEVICE_TYPE_XBOX := DeviceType.XBOX

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

@export_group("Components")

## actions is the input device's component which manages loaded/enabled action sets.
@export var actions: StdInputDeviceActions = null

## glyphs is the input device's component which fetches origin glyphs.
@export var glyphs: StdInputDeviceGlyphs = null

## haptics is the input device's component which provides haptic feedback (i.e.
## vibrations).
@export var haptics: StdInputDeviceHaptics = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #

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

	assert(
		not actions.list_action_set_layers(device_id), "invalid state; dangling layers"
	)

	layers.reverse()
	for layer in layers:
		action_set_layer_disabled.emit(layer)

	action_set_loaded.emit(action_set)

	return true


# Action set layers


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

	assert(
		layer in actions.list_action_set_layers(device_id),
		"invalid state; missing layer"
	)

	action_set_layer_enabled.emit(layer)

	return true


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

	assert(
		layer not in actions.list_action_set_layers(device_id),
		"invalid state; dangling layer"
	)

	action_set_layer_disabled.emit(layer)

	return true


# Glyphs


## get_action_glyph returns a `Texture2D` containing the glyph of the primary (i.e.
## first) controller origin which will actuate the specified action.
func get_action_glyph(
	action_set: StringName,
	action: StringName,
	device_type_override: DeviceType = DEVICE_TYPE_UNKNOWN,
) -> StdInputDeviceGlyphs.GlyphData:
	assert(glyphs is StdInputDeviceGlyphs, "invalid state; missing component")

	if device_type_override == DEVICE_TYPE_UNKNOWN:
		device_type_override = device_type

	return glyphs.get_action_glyph(device_id, device_type_override, action_set, action)


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
