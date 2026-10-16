##
## std/input/loader.gd
##
## StdInputActionSetLoader is a node which keeps an action set loaded and action set
## layers enabled while the rule in `active_while` holds and its screen is uncovered.
##
## NOTE: Loaders may share a layer. One disables it only when no other active loader
## for the same player lists it.
##

class_name StdInputActionSetLoader
extends Control

# -- DEFINITIONS --------------------------------------------------------------------- #

## ActiveWhile names the rule deciding when the action set and layers are active.
enum ActiveWhile {
	IN_TREE,  ## While this `Control` is in the scene tree.
	VISIBLE,  ## While this `Control` is visible in the scene tree.
	NEVER,  ## Not at all; the loader holds its sets and does nothing with them.
}

const _GROUP_INPUT_LOADER := &"std/input:loader"

# -- CONFIGURATION ------------------------------------------------------------------- #

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1

## active_while is the rule deciding when the action set is loaded and the layers are
## enabled.
@export var active_while: ActiveWhile = ActiveWhile.IN_TREE

## action_set is an `StdInputActionSet` loaded while the rule holds. It is never
## unloaded; a screen that takes over loads its own.
@export var action_set: StdInputActionSet = null

## action_set_layers are `StdInputActionSetLayer` resources enabled while the rule
## holds and disabled otherwise.
@export var action_set_layers: Array[StdInputActionSetLayer] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

## _covered is whether another screen covers the one holding this loader.
var _covered: bool = false

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## disable_action_set_layers disables the configured action set layers for the player,
## leaving on any that another active loader for the player lists.
func disable_action_set_layers() -> void:
	assert(
		not action_set_layers.is_empty(),
		"invalid state; missing layers",
	)

	var slot := StdInputSlot.for_player(player_id)
	assert(slot is StdInputSlot, "invalid state; missing input slot")

	var enabled := slot.list_action_set_layers()
	for layer in action_set_layers:
		if layer in enabled and not _is_layer_wanted_elsewhere(layer):
			slot.disable_action_set_layer(layer)


## enable_action_set_layers enables the configured action set layers for the player.
func enable_action_set_layers() -> void:
	assert(
		not action_set_layers.is_empty(),
		"invalid state; missing layers",
	)

	var slot := StdInputSlot.for_player(player_id)
	assert(slot is StdInputSlot, "invalid state; missing input slot")

	var enabled := slot.list_action_set_layers()
	for layer in action_set_layers:
		if layer not in enabled:
			slot.enable_action_set_layer(layer)


## load_action_set loads the configured action set for the the player.
func load_action_set() -> void:
	assert(action_set is StdInputActionSet, "invalid state; missing action set")

	var slot := StdInputSlot.for_player(player_id)
	assert(slot is StdInputSlot, "invalid state; missing input slot")

	slot.load_action_set(action_set)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	StdGroup.with_id(_GROUP_INPUT_LOADER).add_member(self)

	# NOTE: Deferred so that a parent handing this loader its sets as it enters, and a
	# parent's `_ready` hiding it, both run first.
	_sync.call_deferred()


func _exit_tree() -> void:
	StdGroup.with_id(_GROUP_INPUT_LOADER).remove_member(self)

	if active_while == ActiveWhile.NEVER or action_set_layers.is_empty():
		return

	# NOTE: At quit the slot may be gone already, and then nothing is left to disable.
	if not StdInputSlot.for_player(player_id):
		return

	disable_action_set_layers()


func _notification(what) -> void:
	match what:
		StdScreenManager.NOTIFICATION_SCREEN_COVERED:
			_covered = true
			_sync()

		StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED:
			_covered = false
			_sync()

		NOTIFICATION_VISIBILITY_CHANGED:
			if active_while == ActiveWhile.VISIBLE:
				_sync()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _is_active returns whether the rule holds, so this loader wants its action set
## loaded and its layers enabled.
func _is_active() -> bool:
	return (
		active_while != ActiveWhile.NEVER
		and is_inside_tree()
		and not _covered
		and (active_while != ActiveWhile.VISIBLE or is_visible_in_tree())
	)


## _is_layer_wanted_elsewhere returns whether another active loader for the player
## lists `layer`.
func _is_layer_wanted_elsewhere(layer: StdInputActionSetLayer) -> bool:
	for member in StdGroup.with_id(_GROUP_INPUT_LOADER).list_members():
		var other := member as StdInputActionSetLoader
		if (
			other != self
			and other.player_id == player_id
			and layer in other.action_set_layers
			and other._is_active()
		):
			return true

	return false


## _sync loads the action set and enables the layers if the rule holds, and disables
## the layers if it does not. Loading an active set and enabling an enabled layer change
## nothing, so this runs on every event that could change the rule's answer.
func _sync() -> void:
	if active_while == ActiveWhile.NEVER or not is_inside_tree():
		return

	if _is_active():
		if action_set:
			load_action_set()
		if not action_set_layers.is_empty():
			enable_action_set_layers()
	elif not action_set_layers.is_empty():
		disable_action_set_layers()
