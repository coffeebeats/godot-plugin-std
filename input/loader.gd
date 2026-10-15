##
## std/input/loader.gd
##
## StdInputActionSetLoader is a node which keeps an action set loaded and action set
## layers enabled for as long as one rule holds, chosen by `active_while`: while this
## `Control` is in the tree, or only while it is visible there. Either way the layers
## go off while the screen holding this loader is covered by another and come back
## when it is uncovered, and the action set is loaded again then, since the covering
## screen loaded its own.
##
## NOTE: Every change re-syncs from that rule rather than toggling, and the input slot
## holds a layer by owner, so two loaders may enable one layer and each may re-sync as
## often as it likes.
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


## disable_action_set_layers disables the configured action set layers for the player.
func disable_action_set_layers() -> void:
	assert(
		not action_set_layers.is_empty(),
		"invalid state; missing layers",
	)

	var slot := StdInputSlot.for_player(player_id)
	assert(slot is StdInputSlot, "invalid state; missing input slot")

	var enabled := slot.list_action_set_layers()
	for layer in action_set_layers:
		if layer in enabled:
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
	# NOTE: Deferred so that a parent handing this loader its sets as it enters, and a
	# parent's `_ready` hiding it, both run first.
	_sync.call_deferred()


func _exit_tree() -> void:
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


## _sync loads the action set and enables the layers if the rule holds, and disables
## the layers if it does not. Loading an active set and enabling a held layer change
## nothing, so this runs on every event that could change the rule's answer.
func _sync() -> void:
	if active_while == ActiveWhile.NEVER or not is_inside_tree():
		return

	var active := (
		not _covered and (active_while != ActiveWhile.VISIBLE or is_visible_in_tree())
	)

	if active:
		if action_set:
			load_action_set()
		if not action_set_layers.is_empty():
			enable_action_set_layers()
	elif not action_set_layers.is_empty():
		disable_action_set_layers()
