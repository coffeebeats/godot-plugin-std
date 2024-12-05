##
## std/input/godot/device_bindings.gd
##
## An implemention of `InputDevice.Bindings` which uses Godot's built-in action map
## (plus custom action set handling) to manage available actions.
##
## NOTE: This implementation requires that all action sets/bindings apply to all input
## devices. Changing action sets for one device thus changes them for all devices.
##

extends InputDevice.Bindings

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Origin := preload("../origin.gd")
const Binding := preload("../binding.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

# -- INITIALIZATION ------------------------------------------------------------------ #

## _action_set is the currently active action set.
static var _action_set: InputActionSet = null

## _action_set_layers is the stack of currently active action set layers.
static var _action_set_layers: Array[InputActionSetLayer] = []

## _bindings maps origins (integers) to the actions they are bound to.
static var _bindings: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_action_set returns the currently active `InputActionSet` *for the specified
## device*, if.
func get_action_set(_device: int) -> InputActionSet:
	return _action_set


## load_action_set unloads the currently active `InputActionSet`, if any, and then
## activates the provided action set *for the specified device*. If the action set
## is already active for the device then no change occurs.
func load_action_set(
	device: int, device_type: InputDeviceType, action_set: InputActionSet
) -> bool:
	assert(action_set is InputActionSet, "missing argument: action set")
	assert(
		not action_set is InputActionSetLayer, "invalid argument: cannot use a layer"
	)

	if action_set == _action_set:
		return false

	_action_set = action_set
	_action_set_layers = []
	_bindings = {}

	# Clear all existing bindings.
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)

	_apply_action_set(device, device_type, action_set)

	return true


# Action set layers


## enable_action_set_layer pushes the provided action set layer onto the stack of
## active layers *for the specified device*. If the action set layer is already
## active then no change occurs.
func enable_action_set_layer(
	device: int, device_type: InputDeviceType, action_set_layer: InputActionSetLayer
) -> bool:
	assert(action_set_layer is InputActionSetLayer, "missing argument: layer")
	assert(_action_set is InputActionSet, "invalid state: missing action set")
	assert(
		action_set_layer.parent == _action_set,
		"invalid argument: wrong parent action set",
	)

	if action_set_layer in _action_set_layers:
		return false

	_action_set_layers.append(action_set_layer)

	_apply_action_set(device, device_type, action_set_layer)

	return true


## disable_action_set_layer removes the provided action set layer from the set of
## active layers *for the specified device*. If the action set layer is not active
## then no change occurs.
func disable_action_set_layer(
	device: int, device_type: InputDeviceType, action_set_layer: InputActionSetLayer
) -> bool:
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

	# TODO: Rather than completely rebuilding the action map, only bind/unbind the
	# necessary origins.
	load_action_set(device, device_type, get_action_set(device))
	for layer in _action_set_layers:
		enable_action_set_layer(device, device_type, layer)

	return true


## list_action_set_layers returns the stack of currently active action set layers
## *for the specified device*.
func list_action_set_layers(_device: int) -> Array[InputActionSetLayer]:
	return _action_set_layers.duplicate()


# Action origins


## get_action_origins returns the set of input origins which are bound to the
## specified action *for the specified device*.
func get_action_origins(
	_device: int, device_type: InputDeviceType, action: StringName
) -> PackedInt64Array:
	var origins := PackedInt64Array()

	for event in (
		Binding.get_kbm(scope, action)
		if device_type == InputDevice.DEVICE_TYPE_KEYBOARD
		else Binding.get_joy(scope, action)
	):
		var value_encoded: int = Origin.encode(event)
		if value_encoded < 0:
			continue

		origins.append(value_encoded)

	return origins


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(scope is StdSettingsScope, "invalid config; missing bindings scope")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _apply_action_set(
	device: int, device_type: InputDevice.InputDeviceType, action_set: InputActionSet
) -> void:
	for actions in [
		action_set.actions_analog_1d,
		action_set.actions_analog_2d,
		action_set.actions_digital,
	]:
		for action in actions:
			if not InputMap.has_action(action):
				assert(false, "invalid state; unknown action")
				InputMap.add_action(action)

			# FIXME: Apply *both* keyboard and mouse events/origins.

			for origin in get_action_origins(device, device_type, action):
				_bind_action_to_origin(action_set, action, origin)


func _bind_action_to_origin(
	action_set: InputActionSet, action: StringName, origin: int
) -> void:
	var event := Origin.decode(origin)
	assert(event is InputEvent, "invalid state; missing event")

	# NOTE: See https://github.com/godotengine/godot/pull/99449; this value may change
	# in the future.
	event.device = -1

	if not action_set.is_matching_event_origin(action, event):
		assert(false, "invalid state; wrong event type")
		return

	if origin in _bindings:
		InputMap.action_erase_event(_bindings[origin], event)

	InputMap.action_add_event(action, event)
	_bindings[origin] = action

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
