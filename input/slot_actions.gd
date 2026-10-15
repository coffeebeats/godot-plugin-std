##
## std/input/slot_actions.gd
##
## StdInputSlotDeviceActions is an implementation of `StdInputDeviceActions` which
## delegates to the device type-specific component of a `StdInputSlot`. It records the
## slot's intent, the loaded set and the enabled layers, whatever its devices answer,
## so a device that connects later is brought up to date.
##
## Each enabled layer is held by one or more owners, the objects that enabled it, and
## it stays enabled until the last owner lets go. Two loaders may thus share a layer
## without undoing each other.
##

extends StdInputDeviceActions

# -- INITIALIZATION ------------------------------------------------------------------ #

var slot: StdInputSlot = null

## _action_set is the currently active action set.
var _action_set: StdInputActionSet = null

## _owners maps each enabled layer to the instance ids of the owners holding it. Its
## keys, in insertion order, are the stack of enabled layers.
var _owners: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## add_owner records `holder` as holding `layer` enabled. Returns whether the layer was
## not enabled before, meaning the devices now need it bound.
func add_owner(layer: StdInputActionSetLayer, holder: Object) -> bool:
	assert(layer is StdInputActionSetLayer, "missing argument: layer")
	assert(holder is Object, "missing argument: owner")

	var is_new := layer not in _owners
	if is_new:
		_owners[layer] = [] as Array[int]

	var owners: Array[int] = _owners[layer]
	if holder.get_instance_id() not in owners:
		owners.append(holder.get_instance_id())

	return is_new


## remove_owner forgets `holder`'s hold on `layer`. Returns whether that was the last
## hold, meaning the devices now need it unbound. An owner that was freed without
## letting go does not count as a hold.
func remove_owner(layer: StdInputActionSetLayer, holder: Object) -> bool:
	assert(layer is StdInputActionSetLayer, "missing argument: layer")
	assert(holder is Object, "missing argument: owner")

	if layer not in _owners:
		return false

	var owners: Array[int] = _owners[layer]
	owners.erase(holder.get_instance_id())

	return (
		owners
		. filter(func(id: int) -> bool: return instance_from_id(id) != null)
		. is_empty()
	)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_set(_device: int) -> StdInputActionSet:
	return _action_set


func _load_action_set(_device: int, action_set: StdInputActionSet) -> bool:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return false

	for device in slot.get_connected_devices():
		device.load_action_set(action_set)

	if _action_set == action_set:
		return false

	_action_set = action_set
	_owners = {}

	return true


func _disable_action_set_layer(_device: int, layer: StdInputActionSetLayer) -> bool:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return false

	for device in slot.get_connected_devices():
		device.disable_action_set_layer(layer)

	return _owners.erase(layer)


func _enable_action_set_layer(_device: int, layer: StdInputActionSetLayer) -> bool:
	if not slot:
		assert(false, "invalid state; missing input slot")
		return false

	for device in slot.get_connected_devices():
		device.enable_action_set_layer(layer)

	# NOTE: A caller that reaches this component directly, rather than through the
	# slot, holds the layer as the slot itself.
	if layer not in _owners:
		add_owner(layer, slot)

	return true


func _list_action_set_layers(_device: int) -> Array[StdInputActionSetLayer]:
	var layers: Array[StdInputActionSetLayer] = []
	layers.assign(_owners.keys())
	return layers
