##
## std/input/godot/device_bindings.gd
##
## An implemention of `StdInputDeviceActions` which uses Godot's built-in action map
## (plus custom action set handling) to manage available actions.
##
## NOTE: This implementation requires that all action sets/bindings apply to all input
## devices. Changing action sets for one device thus changes them for all devices.
##

extends StdInputDeviceActions

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Origin := preload("../origin.gd")
const Binding := preload("../binding.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DeviceType := StdInputDevice.DeviceType # gdlint:ignore=constant-name

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

# -- INITIALIZATION ------------------------------------------------------------------ #

## _action_set is the currently active action set.
static var _action_set: StdInputActionSet = null # gdlint: ignore=class-definitions-order

## _action_set_layers is the stack of currently active action set layers.
static var _action_set_layers: Array[StdInputActionSetLayer] = [] # gdlint: ignore=class-definitions-order,max-line-length

## _bindings maps origins (integers) to the actions they are bound to.
static var _bindings: Dictionary = {} # gdlint: ignore=class-definitions-order

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(scope is StdSettingsScope, "invalid config; missing bindings scope")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## get_action_set returns the currently active `InputActionSet` *for the specified
## device*, if.
func _get_action_set(_device: int) -> StdInputActionSet:
	return _action_set


## load_action_set unloads the currently active `StdInputActionSet`, if any, and then
## activates the provided action set *for the specified device*. If the action set
## is already active for the device then no change occurs.
func _load_action_set(_device: int, action_set: StdInputActionSet) -> bool:
	assert(action_set is StdInputActionSet, "missing argument: action set")
	assert(
		not action_set is StdInputActionSetLayer, "invalid argument: cannot use a layer"
	)

	if action_set == _action_set:
		return false

	_action_set = action_set
	_action_set_layers = []
	_bindings = {}

	# Clear all existing bindings.
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)

	_apply_action_set(-1, StdInputDevice.DEVICE_TYPE_UNKNOWN, action_set)
	_apply_action_set(-1, StdInputDevice.DEVICE_TYPE_KEYBOARD, action_set)

	return true


# Action set layers


## enable_action_set_layer pushes the provided action set layer onto the stack of
## active layers *for the specified device*. If the action set layer is already
## active then no change occurs.
func _enable_action_set_layer(
	_device: int, action_set_layer: StdInputActionSetLayer
) -> bool:
	assert(action_set_layer is StdInputActionSetLayer, "missing argument: layer")
	assert(_action_set is StdInputActionSet, "invalid state: missing action set")
	assert(
		action_set_layer.parent == _action_set,
		"invalid argument: wrong parent action set",
	)

	if action_set_layer in _action_set_layers:
		return false

	_action_set_layers.append(action_set_layer)

	_apply_action_set(-1, StdInputDevice.DEVICE_TYPE_UNKNOWN, action_set_layer)
	_apply_action_set(-1, StdInputDevice.DEVICE_TYPE_KEYBOARD, action_set_layer)

	return true


## disable_action_set_layer removes the provided action set layer from the set of
## active layers *for the specified device*. If the action set layer is not active
## then no change occurs.
func _disable_action_set_layer(
	_device: int, action_set_layer: StdInputActionSetLayer
) -> bool:
	assert(action_set_layer is StdInputActionSetLayer, "missing argument: layer")
	assert(_action_set is StdInputActionSet, "invalid state: missing action set")
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
	load_action_set(-1, get_action_set(-1))
	for layer in _action_set_layers:
		enable_action_set_layer(-1, layer)

	return true


## list_action_set_layers returns the stack of currently active action set layers
## *for the specified device*.
func _list_action_set_layers(_device: int) -> Array[StdInputActionSetLayer]:
	return _action_set_layers.duplicate()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _apply_action_set(
	device: int, device_type: DeviceType, action_set: StdInputActionSet
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

			for origin in _get_action_origins(device, device_type, action):
				_bind_action_to_origin(device, action_set, action, origin)


func _bind_action_to_origin(
	device: int, action_set: StdInputActionSet, action: StringName, origin: int
) -> void:
	var event := Origin.decode(origin)
	assert(event is InputEvent, "invalid state; missing event")

	# NOTE: See https://github.com/godotengine/godot/pull/99449; '-1' values may change
	# in the future.
	event.device = device

	if not action_set.is_matching_event_origin(action, event):
		assert(false, "invalid state; wrong event type")
		return

	if origin in _bindings:
		InputMap.action_erase_event(_bindings[origin], event)

	InputMap.action_add_event(action, event)
	_bindings[origin] = action


func _get_action_origins(
	_device: int, device_type: DeviceType, action: StringName
) -> PackedInt64Array:
	var origins := PackedInt64Array()

	for event in (
		Binding.get_kbm(scope, action)
		if device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
		else Binding.get_joy(scope, action)
	):
		var value_encoded: int = Origin.encode(event)
		if value_encoded < 0:
			continue

		origins.append(value_encoded)

	return origins
