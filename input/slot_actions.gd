##
## std/input/slot_actions.gd
##
## StdInputSlotDeviceActions is an implementation of `StdInputDeviceActions` which
## delegates to the device type-specific component of a `StdInputSlot`.
##

extends StdInputDeviceActions

# -- INITIALIZATION ------------------------------------------------------------------ #

var slot: StdInputSlot = null

## _action_set is the currently active action set.
var _action_set: StdInputActionSet = null

## _action_set_layers is the stack of currently active action set layers.
var _action_set_layers: Array[StdInputActionSetLayer] = []

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_set(_device: int) -> StdInputActionSet:
	return _action_set


func _load_action_set(_device: int, action_set: StdInputActionSet) -> bool:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return false

	if (
		slot
		. get_connected_devices()
		. map(func(d): return d.load_action_set(action_set))
		. all(func(r): return not r)
	):
		return false

	if _action_set != action_set:
		_action_set = action_set
		_action_set_layers = []

	return true


func _disable_action_set_layer(_device: int, layer: StdInputActionSetLayer) -> bool:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return false

	if (
		slot
		. get_connected_devices()
		. map(func(d): return d.disable_action_set_layer(layer))
		. all(func(r): return not r)
	):
		return false

	_action_set_layers.erase(layer)

	return true


func _enable_action_set_layer(_device: int, layer: StdInputActionSetLayer) -> bool:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return false

	if (
		slot
		. get_connected_devices()
		. map(func(d): return d.enable_action_set_layer(layer))
		. all(func(r): return not r)
	):
		return false

	if not layer in _action_set_layers:
		_action_set_layers.append(layer)

	return true


func _list_action_set_layers(_device: int) -> Array[StdInputActionSetLayer]:
	return _action_set_layers.duplicate()
