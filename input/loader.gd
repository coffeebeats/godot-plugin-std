##
## std/input/loader.gd
##
## StdInputActionSetLoader is a node which facilitates loading and unloading actions
## sets and layers based on scene tree state.
##

class_name StdInputActionSetLoader
extends Control

# -- CONFIGURATION ------------------------------------------------------------------- #

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1

@export_group("Action set")

## action_set is an `StdInputActionSet` that will be loaded by the configured hooks.
@export var action_set: StdInputActionSet = null

@export_subgroup("Scene tree")

## load_on_enter controls whether the action set is loaded when this `Control` enters
## the scene tree.
@export var load_on_enter: bool = true

## load_on_ready controls whether the action set is loaded when this `Control` is ready.
@export var load_on_ready: bool = false

@export_subgroup("Visibility")

## load_on_visible controls whether the action set is loaded when this `Control` becomes
## visible.
##
## NOTE: Only one of `load_on_visible` and `load_on_hidden` may be specified.
@export var load_on_visible: bool = false:
	set(value):
		load_on_visible = value
		if load_on_hidden == value:
			load_on_hidden = not value

## load_on_hidden controls whether the action set is loaded when this `Control` becomes
## hidden. This can be used to swap action sets when a menu is hidden, for example.
##
## NOTE: Only one of `load_on_visible` and `load_on_hidden` may be specified.
@export var load_on_hidden: bool = false:
	set(value):
		load_on_hidden = value
		if load_on_visible == value:
			load_on_visible = not value

@export_group("Action set layer")

## action_set_layer is an `StdInputActionSetLayer` that will be enabled by the
## configured hooks.
@export var action_set_layer: StdInputActionSet = null

@export_subgroup("Scene tree")

## enable_on_enter controls whether the layer is enabled when this `Control` enters the
## scene tree.
@export var enable_on_enter: bool = true

## enable_on_ready controls whether the layer is enabled when this `Control` is ready.
@export var enable_on_ready: bool = false

## disable_on_exit controls whether the layer is disabled when this `Control` exits the
## scene tree.
@export var disable_on_exit: bool = true

@export_subgroup("Visibility")

## disable_on_hidden controls whether the layer is disabled when this `Control` becomes
## hidden.
##
## NOTE: Only one of `disable_on_hidden` and `enable_on_hidden` may be specified.
@export var disable_on_hidden: bool = false:
	set(value):
		disable_on_hidden = value
		if enable_on_hidden == value:
			enable_on_hidden = not value

## disable_on_visible controls whether the layer is disabled when this `Control` becomes
## visible.
##
## NOTE: Only one of `enable_on_visible` and `disable_on_visible` may be specified.
@export var disable_on_visible: bool = false:
	set(value):
		disable_on_visible = value
		if enable_on_visible == value:
			enable_on_visible = not value

## enable_on_hidden controls whether the layer is enabled when this `Control` is hidden
## in the scene.
##
## NOTE: Only one of `disable_on_hidden` and `enable_on_hidden` may be specified.
@export var enable_on_hidden: bool = false:
	set(value):
		enable_on_hidden = value
		if disable_on_hidden == value:
			disable_on_hidden = not value

## enable_on_visible controls whether the layer is enabled when this `Control` becomes
## visible in the scene.
##
## NOTE: Only one of `enable_on_visible` and `disable_on_visible` may be specified.
@export var enable_on_visible: bool = false:
	set(value):
		enable_on_visible = value
		if disable_on_visible == value:
			disable_on_visible = not value

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## disable_action_set_layer disables the configured action set layer for the the player.
func disable_action_set_layer() -> void:
	assert(action_set_layer is StdInputActionSetLayer, "invalid state; missing layer")

	var slot := StdInputSlot.for_player(player_id)
	assert(slot is StdInputSlot, "invalid state; missing input slot")

	if not _is_action_set_layer_enabled():
		return

	slot.disable_action_set_layer(action_set_layer)


## enable_action_set_layer enables the configured action set layer for the the player.
func enable_action_set_layer() -> void:
	assert(action_set_layer is StdInputActionSetLayer, "invalidstate; missinglayer")

	var slot := StdInputSlot.for_player(player_id)
	assert(slot is StdInputSlot, "invalidstate; missinginputslot")

	if _is_action_set_layer_enabled():
		return

	slot.enable_action_set_layer(action_set_layer)


## load_action_set loads the configured action set for the the player.
func load_action_set() -> void:
	assert(action_set is StdInputActionSet, "invalid state; missing action set")

	var slot := StdInputSlot.for_player(player_id)
	assert(slot is StdInputSlot, "invalid state; missing input slot")

	slot.load_action_set(action_set)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if action_set and load_on_enter:
		load_action_set.call_deferred()
	if action_set_layer and enable_on_enter:
		enable_action_set_layer.call_deferred()


func _exit_tree() -> void:
	if action_set_layer and disable_on_exit:
		disable_action_set_layer()


func _notification(what) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if is_visible_in_tree():
				if action_set and load_on_visible:
					load_action_set()

				if action_set_layer:
					if enable_on_visible:
						enable_action_set_layer()
					elif disable_on_visible:
						disable_action_set_layer()
			else:
				if action_set and load_on_hidden:
					load_action_set()

				if action_set_layer:
					if disable_on_hidden:
						disable_action_set_layer()
					elif enable_on_hidden:
						enable_action_set_layer()


func _ready() -> void:
	if action_set and load_on_ready:
		load_action_set.call_deferred()
	if action_set_layer and enable_on_ready:
		enable_action_set_layer.call_deferred()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _is_action_set_layer_enabled() -> bool:
	assert(action_set_layer is StdInputActionSetLayer, "invalidstate; missingactionset")

	var slot := StdInputSlot.for_player(player_id)
	assert(slot is StdInputSlot, "invalidstate; missinginputslot")

	return action_set_layer in slot.list_action_set_layers()
