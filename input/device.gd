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
	NINTENDO_SWITCH = 2,
	PLAYSTATION = 3,
	STEAM_DECK = 4,
	STEAM_CONTROLLER = 5,
	XBOX = 6,
}

## DEVICE_TYPE_UNKNOWN defines an unknown device type (also represents an unspecified
## `InputDeviceType` value).
const DEVICE_TYPE_UNKNOWN := InputDeviceType.UNKNOWN

## DEVICE_TYPE_KEYBOARD defines a keyboard + mouse device type.
const DEVICE_TYPE_KEYBOARD := InputDeviceType.KEYBOARD

## DEVICE_TYPE_NINTENDO_SWITCH defines a Nintendo Switch joypad (e.g. pro controller or
## joycons).
const DEVICE_TYPE_NINTENDO_SWITCH := InputDeviceType.NINTENDO_SWITCH

## DEVICE_TYPE_PLAYSTATION defines a PlayStation joypad.
const DEVICE_TYPE_PLAYSTATION := InputDeviceType.PLAYSTATION

## DEVICE_TYPE_STEAM_DECK defines a Steam deck joypad.
const DEVICE_TYPE_STEAM_DECK := InputDeviceType.STEAM_DECK

## DEVICE_TYPE_STEAM_CONTROLLER defines a Steam controller joypad.
const DEVICE_TYPE_STEAM_CONTROLLER := InputDeviceType.STEAM_CONTROLLER

## DEVICE_TYPE_XBOX defines an Xbox joypad.
const DEVICE_TYPE_XBOX := InputDeviceType.XBOX


## Bindings is the interface for the input device bindings component. Set the input
## device's `bindings` property to an instance of `Bindings` to override.
##
## NOTE: All of the methods defined in this class must be cheap to call and idempotent.
class Bindings:
	extends Node

	## device is the device ID to which these methods apply.
	var device: int = 0

	## _action_set is the currently active action set.
	var _action_set: InputActionSet = null

	## _action_set_layers is the stack of currently active action set layers.
	var _action_set_layers: Array[InputActionSetLayer] = []

	# Action sets

	## get_action_set returns the currently active `InputActionSet`, if any.
	func get_action_set() -> InputActionSet:
		return _action_set

	## load_action_set unloads the currently active `InputActionSet`, if any, and then
	## activates the provided action set *for the specified device*. If the action set
	## is already active for the device then no change occurs.
	func load_action_set(action_set: InputActionSet) -> bool:
		assert(action_set is InputActionSet, "missing argument: action set")
		assert(
			not action_set is InputActionSetLayer,
			"invalid argument: cannot use a layer"
		)

		if action_set == _action_set:
			return false

		_action_set = action_set

		while true:
			var action_set_layer: InputActionSetLayer = _action_set_layers.pop_back()
			if not action_set_layer:
				break

			disable_action_set_layer(action_set_layer)

		return true

	# Action set layers

	## enable_action_set_layer pushes the provided action set layer onto the stack of
	## active layers *for the device*. If the action set layer is already active then no
	## change occurs.
	func enable_action_set_layer(action_set_layer: InputActionSetLayer) -> bool:
		assert(action_set_layer is InputActionSetLayer, "missing argument: layer")
		assert(_action_set is InputActionSet, "invalid state: missing action set")
		assert(
			action_set_layer.parent == _action_set,
			"invalid argument: wrong parent action set",
		)

		if action_set_layer in _action_set_layers:
			return false

		_action_set_layers.append(action_set_layer)

		return true

	## disable_action_set_layer removes the provided action set layer from the set of
	## active layers *for the device*. If the action set layer is not active then no
	## change occurs.
	func disable_action_set_layer(action_set_layer: InputActionSetLayer) -> bool:
		assert(action_set_layer is InputActionSetLayer, "missing argument: layer")
		assert(_action_set is InputActionSet, "invalid state: missing action set")
		assert(
			action_set_layer.parent == _action_set,
			"invalid argument: wrong parent action set",
		)

		if action_set_layer not in _action_set_layers:
			return false

		_action_set_layers.erase(action_set_layer)
		assert(action_set_layer not in _action_set_layers, "found duplicate layer")

		return true

	## list_action_set_layers returns the stack of currently active action set layers
	## *for the device*.
	func list_action_set_layers() -> Array[InputActionSetLayer]:
		return _action_set_layers

	# Action origins

	## get_action_origins returns the set of input origins which are bound to the
	## specified action *for the device*.
	func get_action_origins(_action: StringName) -> PackedInt64Array:
		return PackedInt64Array()


## Glyphs is the interface for the input device bindings component. Set the input
## device's `bindings` property to an instance of `Glyphs` to override.
class Glyphs:
	extends Node

	## device is the device ID to which these methods apply.
	var device: int = 0

	## get_origin_glyph returns a `Texture2D` containing an input origin glyph icon *for
	## the specified device*.
	func get_origin_glyph(_device_type: InputDeviceType, _origin: int) -> Texture2D:
		return null


## Haptics is the interface for the input device bindings component. Set the input
## device's `bindings` property to an instance of `Haptics` to override.
class Haptics:
	extends Node

	## device is the device ID to which these methods apply.
	var device: int = 0

	## start_vibrate_weak executes a weak vibration effect for the provided duration
	## and device.
	func start_vibrate_weak(_duration: float) -> bool:
		return false

	## start_vibrate_strong executes a strong vibration effect for the provided duration
	## and device
	func start_vibrate_strong(_duration: float) -> bool:
		return false

	## stop_vibrate stops all ongoing vibration effects *for the device*.
	func stop_vibrate() -> void:
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
@export var index: int = 0:
	set = set_index

@export_group("Configuration ")

## glyph_type_override_property is a settings property which specifies an override for
## the device type when determining which glyph set to display for an origin. Note that
## if set and its value is not
@export var glyph_type_override_property: StdSettingsPropertyInt = null

@export_group("Components")

## bindings is the `InputDevice`'s bindings component which will be delegated to for
## reading/writing input bindings and managing action sets.
@export var bindings: Bindings = null

## bindings is the `InputDevice`'s glyph component which will be delegated to for
## fetching glyphs for action origins.
@export var glyphs: Glyphs = null

## haptics is the `InputDevice`'s haptics component which will be delegated to for
## initiating haptic feedback (i.e. vibrations).
@export var haptics: Haptics = null

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

	var effective_device_type := device_type

	if glyph_type_override_property:
		var value := glyph_type_override_property.get_value() as InputDeviceType
		if value != DEVICE_TYPE_UNKNOWN:
			effective_device_type = value

	if device_type_override != DEVICE_TYPE_UNKNOWN:
		effective_device_type = device_type_override

	return glyphs.get_origin_glyph(effective_device_type, origins[0])


# Haptics


## start_vibrate_weak initiates an input device vibration for `duration` seconds using
## the device's weak vibration motor, if available.
func start_vibrate_weak(duration: float) -> bool:
	assert(haptics is Haptics, "invalid state; missing component")

	return haptics.start_vibrate_weak(duration)


## start_vibrate_strong initiates an input device vibration for `duration` seconds using
## the device's strong vibration motor, if available.
func start_vibrate_strong(duration: float) -> bool:
	assert(haptics is Haptics, "invalid state; missing component")

	return haptics.start_vibrate_strong(duration)


## stop_vibrate terminates all ongoing vibration for the input device.
func stop_vibrate() -> void:
	assert(haptics is Haptics, "invalid state; missing component")

	return haptics.stop_vibrate()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	if not bindings:
		bindings = Bindings.new()
		add_child(bindings, false, INTERNAL_MODE_BACK)

	if not glyphs:
		glyphs = Glyphs.new()
		add_child(glyphs, false, INTERNAL_MODE_BACK)

	if not haptics:
		haptics = Haptics.new()
		add_child(haptics, false, INTERNAL_MODE_BACK)

	set_index(index)  # NOTE: Ensure device ID is set on these components.


# -- SETTERS/GETTERS ----------------------------------------------------------------- #


## set_index updates the `InputDevice`'s device ID. This value is also set on the input
## device's components, if they exist.
func set_index(value: int) -> void:
	index = value

	if bindings:
		bindings.device = value
	if glyphs:
		glyphs.device = value
	if haptics:
		haptics.device = value
