##
## std/input/loader.gd
##
## InputActionSetLoader is a node which facilitates loading and unloading actions sets
## and layers based on scene tree state.
##

class_name InputActionSetLoader
extends Control

# -- CONFIGURATION ------------------------------------------------------------------- #

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `InputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1:
	set(value):
		player_id = value

		if is_inside_tree():
			_slot = InputSlot.for_player(player_id)

@export_group("Action set")

## action_set is an `InputActionSet` that will be loaded by the configured hooks.
@export var action_set: InputActionSet = null

@export_subgroup("Scene tree")

## load_on_enter controls whether the action set is loaded when this `Node` enters the
## scene tree.
@export var load_on_enter: bool = true

## load_on_ready controls whether the action set is loaded when this `Node` is ready.
@export var load_on_ready: bool = false

@export_subgroup("Visibility")

## load_on_visible controls whether the action set is loaded when this `Node` becomes
## visible.
@export var load_on_visible: bool = false

@export_group("Action set layer")

## action_set_layer is an `InputActionSetLayer` that will be enabled by the configured
## hooks.
@export var action_set_layer: InputActionSet = null

@export_subgroup("Scene tree")

## enable_on_enter controls whether the layer is enabled when this `Node` enters the
## scene tree.
@export var enable_on_enter: bool = true

## enable_on_ready controls whether the layer is enabled when this `Node` is ready.
@export var enable_on_ready: bool = false

## disable_on_exit controls whether the layer is disabled when this `Node` exits the
## scene tree.
@export var disable_on_exit: bool = true

@export_subgroup("Visibility")

## enable_on_visible controls whether the layer is enabled when the target `Control`
## becomes visible in the scene.
@export var enable_on_visible: bool = false

## disable_on_hidden controls whether the layer is disabled when this `Node` becomes
## hidden.
@export var disable_on_hidden: bool = false

# -- INITIALIZATION ------------------------------------------------------------------ #

var _slot: InputSlot = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## disable_action_set_layer disables the configured action set layer for the the player.
func disable_action_set_layer() -> bool:
	assert(_slot is InputSlot, "invalid state; missing input slot")
	assert(action_set_layer is InputActionSetLayer, "invalid state; missing layer")

	return _slot.disable_action_set_layer(action_set_layer)


## enable_action_set_layer enables the configured action set layer for the the player.
func enable_action_set_layer() -> bool:
	assert(_slot is InputSlot, "invalid state; missing input slot")
	assert(action_set_layer is InputActionSetLayer, "invalid state; missing layer")

	return _slot.enable_action_set_layer(action_set_layer)


## load_action_set loads the configured action set for the the player.
func load_action_set() -> bool:
	assert(_slot is InputSlot, "invalid state; missing input slot")
	assert(action_set is InputActionSet, "invalid state; missing action set")

	return _slot.load_action_set(action_set_layer)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	_slot = InputSlot.for_player(player_id)
	assert(_slot is InputSlot, "invalid state; missing input slot")

	if action_set and load_on_enter:
		load_action_set()
	elif action_set_layer and enable_on_enter:
		enable_action_set_layer()


func _exit_tree() -> void:
	if action_set_layer and disable_on_exit:
		disable_action_set_layer()


func _notification(what) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if visible:
				if action_set and load_on_visible:
					load_action_set()
				elif action_set_layer and enable_on_visible:
					enable_action_set_layer()
			else:
				if action_set_layer and disable_on_hidden:
					disable_action_set_layer()


func _ready() -> void:
	if action_set and load_on_ready:
		load_action_set()
	elif action_set_layer and enable_on_ready:
		enable_action_set_layer()
