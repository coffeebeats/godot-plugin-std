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

const DeviceType := StdInputDevice.DeviceType  # gdlint:ignore=constant-name

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

@export_group("Device types")

## claim_kbm_input defines whether this implementation should manage bindings for the
## keyboard and mouse input device.
@export var claim_kbm_input: bool = true:
	set(value):
		if value == claim_kbm_input:
			return

		claim_kbm_input = value

		reload()

## claim_joy_input defines whether this implementation should manage bindings for joypad
## input devices.
@export var claim_joy_input: bool = true:
	set(value):
		if value == claim_joy_input:
			return

		claim_joy_input = value

		reload()

# -- INITIALIZATION ------------------------------------------------------------------ #

## _action_set is the currently active action set.
static var _action_set: StdInputActionSet = null  # gdlint: ignore=class-definitions-order

## _action_set_layers is the stack of currently active action set layers.
static var _action_set_layers: Array[StdInputActionSetLayer] = []  # gdlint: ignore=class-definitions-order,max-line-length

## _bindings maps origins (integers) to the actions they are bound to.
static var _bindings: Dictionary = {}  # gdlint: ignore=class-definitions-order

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## reload refreshes the state of all input bindings for the specified device (defaults
## to updating all devices). This is helpful for rebuilding Godot's input map after
## configuration changes.
func reload(device: int = Binding.DEVICE_ID_ALL) -> void:
	var action_set := get_action_set(device)
	var layers := list_action_set_layers(device)

	_reset(device)

	if not action_set:
		assert(not layers, "invalid state; found dangling layers")
		return

	_load_action_set(device, action_set)

	for layer in layers:
		_enable_action_set_layer(device, layer)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(scope is StdSettingsScope, "invalid config; missing bindings scope")

	# Clear bindings upon initialization.
	reload(Binding.DEVICE_ID_ALL)


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

	_reset(Binding.DEVICE_ID_ALL)
	_action_set = action_set

	if claim_kbm_input:
		_apply_action_set(Binding.DEVICE_ID_ALL, DeviceType.KEYBOARD, action_set)
	if claim_joy_input:
		_apply_action_set(Binding.DEVICE_ID_ALL, DeviceType.GENERIC, action_set)

	return true


# Action set layers


## disable_action_set_layer removes the provided action set layer from the set of
## active layers *for the specified device*. If the action set layer is not active
## then no change occurs.
func _disable_action_set_layer(
	_device: int, action_set_layer: StdInputActionSetLayer
) -> bool:
	assert(action_set_layer is StdInputActionSetLayer, "missing argument: layer")

	if not _action_set is StdInputActionSet:
		assert(false, "invalid state: missing action set")
		return false

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

	reload(Binding.DEVICE_ID_ALL)

	return true


## enable_action_set_layer pushes the provided action set layer onto the stack of
## active layers *for the specified device*. If the action set layer is already
## active then no change occurs.
func _enable_action_set_layer(
	_device: int, action_set_layer: StdInputActionSetLayer
) -> bool:
	assert(action_set_layer is StdInputActionSetLayer, "missing argument: layer")

	if not _action_set is StdInputActionSet:
		assert(false, "invalid state: missing action set")
		return false

	assert(
		action_set_layer.parent == _action_set,
		"invalid argument: wrong parent action set",
	)

	if action_set_layer in _action_set_layers:
		return false

	_action_set_layers.append(action_set_layer)

	if claim_kbm_input:
		_apply_action_set(Binding.DEVICE_ID_ALL, DeviceType.KEYBOARD, action_set_layer)
	if claim_joy_input:
		_apply_action_set(Binding.DEVICE_ID_ALL, DeviceType.GENERIC, action_set_layer)

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

	event.device = device

	if not action_set.is_matching_event_origin(action, event):
		assert(false, "invalid state; wrong event type")
		return

	if origin in _bindings:
		InputMap.action_erase_event(_bindings[origin], event)
		assert(not InputMap.action_has_event(action, event), "failed to erase binding")

	InputMap.action_add_event(action, event)
	_bindings[origin] = action


func _get_action_origins(
	_device: int, device_type: DeviceType, action: StringName
) -> PackedInt64Array:
	var origins := PackedInt64Array()

	for event in (
		Binding.get_kbm(scope, action)
		if device_type == DeviceType.KEYBOARD
		else Binding.get_joy(scope, action)
	):
		var value_encoded: int = Origin.encode(event)
		if value_encoded < 0:
			continue

		origins.append(value_encoded)

	return origins


func _reset(_device: int) -> void:
	# Clear all existing bindings.
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)

	if _action_set:
		_action_set = null

	if _action_set_layers:
		_action_set_layers = []

	_bindings = {}
