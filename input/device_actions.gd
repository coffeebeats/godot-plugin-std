##
## std/input/device_actions.gd
##
## StdInputDeviceActions is an abstract interface for an input device component which
## manages the applied action sets and action set layers for a device.
##

class_name StdInputDeviceActions
extends Node

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# Action sets


## get_action_set returns the currently active `StdInputActionSet` *for the specified
## device*.
func get_action_set(device: int) -> StdInputActionSet:
	return _get_action_set(device)


## load_action_set unbinds any actions currently bound (including activated layers) and
## then binds the actions defined within the action set. Does nothing if the action set
## is already activated.
func load_action_set(device: int, action_set: StdInputActionSet) -> bool:
	return _load_action_set(device, action_set)


# Action set layers


## disable_action_set_layer unbinds all of the actions defined within the layer. Does
## nothing if not activated.
##
## NOTE: The parent action set of the layer *must* be activated, otherwise no action is
## taken.
func disable_action_set_layer(device: int, layer: StdInputActionSetLayer) -> bool:
	return _disable_action_set_layer(device, layer)


## enable_action_set_layer binds all of the actions defined within the layer. All
## *conflicting* origins from either the base action set or prior layers will be
## overridden (unbound from prior actions and bound to the action in this layer). Does
## nothing if already activated.
##
## NOTE: The parent action set of the layer *must* be activated, otherwise no action is
## taken.
func enable_action_set_layer(device: int, layer: StdInputActionSetLayer) -> bool:
	return _enable_action_set_layer(device, layer)


## list_action_set_layers returns the stack of currently active action set layers
## *for the specified device*.
func list_action_set_layers(device: int) -> Array[StdInputActionSetLayer]:
	return _list_action_set_layers(device)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# Action sets


func _get_action_set(_device: int) -> StdInputActionSet:
	assert(false, "unimplemented")
	return null


func _load_action_set(_device: int, _action_set: StdInputActionSet) -> bool:
	assert(false, "unimplemented")
	return false


# Action set layers


func _disable_action_set_layer(_device: int, _layer: StdInputActionSetLayer) -> bool:
	assert(false, "unimplemented")
	return false


func _enable_action_set_layer(_device: int, _layer: StdInputActionSetLayer) -> bool:
	assert(false, "unimplemented")
	return false


func _list_action_set_layers(_device: int) -> Array[StdInputActionSetLayer]:
	assert(false, "unimplemented")
	return []
