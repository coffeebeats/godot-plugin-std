##
## std/input/device.gd
##
## InputDevice is a node which provides an interface for a single player input device.
## Implementations of various features can be specified by overriding its components.
##

class_name InputDevice
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

## InputDeviceType is an enumeration of the categories of player input devices.
enum InputDeviceType {
	UNKNOWN = 0,
	KEYBOARD = 1,
	XBOX = 2,
	PLAYSTATION = 3,
	NINTENDO = 4,
	STEAM_DECK = 5,
	STEAM_CONTROLLER = 6,
}

## DEVICE_TYPE_UNKNOWN defines an unknown device type (also represents an unspecified
## `InputDeviceType` value).
const DEVICE_TYPE_UNKNOWN := InputDeviceType.UNKNOWN

## DEVICE_TYPE_KEYBOARD defines a keyboard + mouse device type.
const DEVICE_TYPE_KEYBOARD := InputDeviceType.KEYBOARD

## DEVICE_TYPE_XBOX defines an Xbox joypad.
const DEVICE_TYPE_XBOX := InputDeviceType.XBOX

## DEVICE_TYPE_PLAYSTATION defines a PlayStation joypad.
const DEVICE_TYPE_PLAYSTATION := InputDeviceType.PLAYSTATION

## DEVICE_TYPE_NINTENDO defines a Nintendo joypad.
const DEVICE_TYPE_NINTENDO := InputDeviceType.NINTENDO

## DEVICE_TYPE_STEAM_DECK defines a Steam deck joypad.
const DEVICE_TYPE_STEAM_DECK := InputDeviceType.STEAM_DECK

## DEVICE_TYPE_STEAM_CONTROLLER defines a Steam controller joypad.
const DEVICE_TYPE_STEAM_CONTROLLER := InputDeviceType.STEAM_CONTROLLER

## Bindings is the interface for the input device bindings component. Set the input
## device's `bindings` property to an instance of `Bindings` to override.
class Bindings:
	extends Node

	# Action sets

	func load_action_set(_action_set: InputActionSet) -> bool:
		assert(false, "unimplemented")
		return true

	# Action set layers

	func enable_action_set_layer(_action_set_layer: InputActionSetLayer) -> bool:
		assert(false, "unimplemented")
		return true

	func disable_action_set_layer(_action_set_layer: InputActionSetLayer) -> bool:
		assert(false, "unimplemented")
		return true

	func list_action_set_layers() -> Array[InputActionSetLayer]:
		assert(false, "unimplemented")
		return []

	# Action origins

	func get_action_origins(_action: StringName) -> PackedInt64Array:
		return PackedInt64Array()

## Glyphs is the interface for the input device bindings component. Set the input
## device's `bindings` property to an instance of `Glyphs` to override.
class Glyphs:
	extends Node

	func get_origin_glyph(_device_type: InputDeviceType, _origin: int) -> Texture2D:
		return null

## Haptics is the interface for the input device bindings component. Set the input
## device's `bindings` property to an instance of `Haptics` to override.
class Haptics:
	extends Node

	func start_vibrate_weak(_device: int, _duration: float) -> bool:
		return false

	func start_vibrate_strong(_device: int, _duration: float) -> bool:
		return false

	func stop_vibrate(_device: int) -> void:
		pass

# -- CONFIGURATION ------------------------------------------------------------------- #

## device_type is the `InputDeviceType` of the `InputDevice`.
@export var device_type: InputDeviceType = InputDeviceType.UNKNOWN

## index is the device ID, which is unique to the input paradigm; touch, keyboard,
## mouse and joypads all have separate scopes for the device index.
##
## NOTE: Despite keyboard device IDs potentially conflicting with mouse IDs, this class
## cannot be used to represent a mouse. Instead, keyboard and mouse are grouped together
## under the keyboard+mouse paradigm. The `index` would refer to the keyboard's index in
## that case (which is expected to be `0` in all cases because Godot/Windows does not
## seem to distinguish between different keyboards).
@export var index: int = 0

@export_group("Configuration ")

## glyph_type_override_property is a settings property which specifies an override for
## the device type when determining which glyph set to display for an origin. Note that
## if set and its value is not 
@export var glyph_type_override_property: StdSettingsPropertyInt = null

@export_group("Components")

## bindings is the `InputDevice`'s bindings component which will be delegated to for
## reading/writing input bindings and managing action sets.
@export var bindings: Bindings

## bindings is the `InputDevice`'s glyph component which will be delegated to for
## fetching glyphs for action origins.
@export var glyphs: Glyphs

## haptics is the `InputDevice`'s haptics component which will be delegated to for
## initiating haptic feedback (i.e. vibrations).
@export var haptics: Haptics

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# Action sets

## load_action_set unbinds any actions currently bound (including activated layers) and
## then binds the actions defined within the action set. Does nothing if the action set
## is already activated.
func load_action_set(action_set: InputActionSet) -> bool:
	assert(action_set is InputActionSet, "missing argument: action set")
	assert(not action_set is InputActionSetLayer, "invalid argument: cannot be a layer")
	assert(bindings is Bindings, "invalid state; missing component")

	return bindings.load_action_set(action_set)

# Action set layers

## enable_action_set_layer binds all of the actions defined within the layer. All
## *conflicting* origins from either the base action set or prior layers will be
## overridden (unbound from prior actions and bound to the action in this layer). Does
## nothing if already activated.
##
## NOTE: The parent action set of the layer *must* be activated, otherwise no action is
## taken.
func enable_action_set_layer(layer: InputActionSetLayer) -> bool:
	assert(layer is InputActionSetLayer, "invalid argument: layer")
	assert(bindings is Bindings, "invalid state; missing component")

	return bindings.enable_action_set_layer(layer)

## disable_action_set_layer unbinds all of the actions defined within the layer. Does
## nothing if not activated.
##
## NOTE: The parent action set of the layer *must* be activated, otherwise no action is
## taken.
func disable_action_set_layer(layer: InputActionSetLayer) -> bool:
	assert(layer is InputActionSetLayer, "invalid argument: layer")
	assert(bindings is Bindings, "invalid state; missing component")

	return bindings.disable_action_set_layer(layer)

# Glyphs

## get_action_glyph returns a `Texture2D` containing the glyph of the primary (i.e.
## first) controller origin which will actuate the specified action.
func get_action_glyph(
	action: StringName,
	device_type_override: InputDeviceType = DEVICE_TYPE_UNKNOWN,
) -> Texture2D:
	assert(bindings is Bindings, "invalid state; missing component")
	assert(glyphs is Glyphs, "invalid state; missing component")

	var origins := bindings.get_action_origins(action)
	if not origins:
		return null

	return glyphs.get_origin_glyph(
		(
			device_type_override if
			device_type_override != DEVICE_TYPE_UNKNOWN else
			device_type
		),
		origins[0],
	)

# Haptics

## start_vibrate_weak initiates an input device vibration for `duration` seconds using
## the device's weak vibration motor, if available.
func start_vibrate_weak(duration: float) -> bool:
	assert(haptics is Haptics, "invalid state; missing component")

	return haptics.start_vibrate_weak(index, duration)

## start_vibrate_strong initiates an input device vibration for `duration` seconds using
## the device's strong vibration motor, if available.
func start_vibrate_strong(duration: float) -> bool:
	assert(haptics is Haptics, "invalid state; missing component")

	return haptics.start_vibrate_strong(index, duration)

## stop_vibrate terminates all ongoing vibration for the input device.
func stop_vibrate() -> void:
	assert(haptics is Haptics, "invalid state; missing component")

	return haptics.stop_vibrate(index)
