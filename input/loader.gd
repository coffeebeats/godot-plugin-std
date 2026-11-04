##
## std/input/loader.gd
##
## StdInputActionSetLoader is a node which keeps an action set loaded and action set
## layers enabled while the rule in `active_while` holds and its screen is uncovered.
## It first acts at the end of the frame it enters the tree in, once its parents have
## set it up. The `VISIBLE` rule follows the nearest `CanvasItem`, `CanvasLayer` or
## `Window` above it, and a loader under that rule is a panel's, so on entering and on
## an uncover it syncs at the end of the frame, after the player's plain loaders.
##
## NOTE: The loaded set follows from the active loaders. When one holding a set goes
## inactive or leaves the tree, the player's others re-sync in tree order, so the last
## of them holding a set wins and their layers stack in that order.
##
## NOTE: Loaders may share a layer. One disables it only when no other active loader
## for the same player lists it.
##

class_name StdInputActionSetLoader
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

## ActiveWhile names the rule deciding when the action set and layers are active.
enum ActiveWhile {
	IN_TREE,  ## While this node is in the scene tree.
	VISIBLE,  ## While the nearest `CanvasItem`, `CanvasLayer` or `Window` above is shown.
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

## action_set is an `StdInputActionSet` loaded while the rule holds. Once the rule
## stops holding, the player's other active loaders re-sync in tree order, so the last
## of them holding a set wins.
@export var action_set: StdInputActionSet = null

## action_set_layers are `StdInputActionSetLayer` resources enabled while the rule
## holds and disabled otherwise.
@export var action_set_layers: Array[StdInputActionSetLayer] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

## _visibility_source is the node whose visibility the `VISIBLE` rule follows, or
## `null` when there is none and the rule holds.
var _visibility_source: Node = null

## _covered is whether another screen covers the one holding this loader.
var _covered: bool = false

## _synced is whether the first sync since entering the tree has run. Notifications
## before it record what they report and leave the syncing to it.
var _synced: bool = false

## _held is whether the rule held at the last sync, so that the sync finding it no
## longer holds is the one to re-sync the player's other loaders.
var _held: bool = false

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

	_visibility_source = _find_visibility_source()
	if _visibility_source:
		_visibility_source.connect(&"visibility_changed", _on_visibility_changed)

	_synced = false

	# NOTE: Deferred so that a parent handing this loader its sets as it enters, and a
	# parent's `_ready` hiding it, both run first.
	_sync_on_enter.call_deferred()


func _exit_tree() -> void:
	StdGroup.with_id(_GROUP_INPUT_LOADER).remove_member(self)

	if _visibility_source:
		_visibility_source.disconnect(&"visibility_changed", _on_visibility_changed)
		_visibility_source = null

	# NOTE: At quit the slot may be gone already, and then nothing is left to disable.
	if active_while == ActiveWhile.NEVER or not StdInputSlot.for_player(player_id):
		return

	if not action_set_layers.is_empty():
		disable_action_set_layers()

	# NOTE: The others re-sync once this loader has left the tree, when every loader
	# leaving with it has left too, so that none still leaving loads its set.
	if _held and action_set:
		tree_exited.connect(_on_tree_exited, CONNECT_ONE_SHOT)

	_held = false


func _notification(what) -> void:
	match what:
		StdScreenManager.NOTIFICATION_SCREEN_COVERED:
			_covered = true
			_sync()

		StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED:
			_covered = false
			_sync_in_turn()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _find_visibility_source returns the nearest `CanvasItem`, `CanvasLayer` or `Window`
## above this loader, or `null` when there is none or another `Viewport` comes first.
func _find_visibility_source() -> Node:
	var node := get_parent()
	while node:
		if node is CanvasItem or node is CanvasLayer or node is Window:
			return node
		if node is Viewport:
			return null
		node = node.get_parent()
	return null


## _is_active returns whether the rule holds, so this loader wants its action set
## loaded and its layers enabled.
func _is_active() -> bool:
	return (
		active_while != ActiveWhile.NEVER
		and is_inside_tree()
		and not _covered
		and (active_while != ActiveWhile.VISIBLE or _is_source_visible())
	)


## _is_layer_wanted_elsewhere returns whether another active loader for the player
## lists `layer`.
func _is_layer_wanted_elsewhere(layer: StdInputActionSetLayer) -> bool:
	for other in _list_peers():
		if layer in other.action_set_layers and other._is_active():
			return true

	return false


## _is_source_visible returns whether the node the `VISIBLE` rule follows is shown, or
## `true` when there is none.
func _is_source_visible() -> bool:
	if _visibility_source is CanvasItem:
		return (_visibility_source as CanvasItem).is_visible_in_tree()
	if _visibility_source is CanvasLayer:
		return (_visibility_source as CanvasLayer).visible
	if _visibility_source is Window:
		return (_visibility_source as Window).visible
	return true


## _list_peers returns the player's other loaders in the tree, in tree order.
func _list_peers() -> Array[StdInputActionSetLoader]:
	var peers: Array[StdInputActionSetLoader] = []
	for member in StdGroup.with_id(_GROUP_INPUT_LOADER).list_members():
		var other := member as StdInputActionSetLoader
		if other != self and other.player_id == player_id:
			peers.append(other)

	peers.sort_custom(func(a: Node, b: Node) -> bool: return b.is_greater_than(a))
	return peers


## _resync_peers syncs the player's other active loaders in tree order.
func _resync_peers() -> void:
	for other in _list_peers():
		if other._is_active():
			other._sync_in_turn()


## _sync_on_enter runs the first sync since this loader entered the tree, after which
## notifications sync it too.
func _sync_on_enter() -> void:
	# NOTE: A call queued before this loader left the tree in the same frame must not
	# mark it synced, or its next entry would sync early.
	if not is_inside_tree():
		return

	_synced = true
	_sync_in_turn()


## _sync loads the action set and enables the layers if the rule holds, and disables
## the layers if it does not. Loading an active set and enabling an enabled layer change
## nothing, so this runs on every event that could change the rule's answer.
func _sync() -> void:
	if active_while == ActiveWhile.NEVER or not is_inside_tree() or not _synced:
		return

	var held := _held
	_held = _is_active()

	if _held:
		if action_set:
			load_action_set()
		if not action_set_layers.is_empty():
			enable_action_set_layers()
		return

	if not action_set_layers.is_empty():
		disable_action_set_layers()

	# NOTE: A covered loader's active peers are the covering screen's, which sync on
	# their own, so only an uncovered loader re-syncs them.
	if held and action_set and not _covered:
		_resync_peers()


## _sync_in_turn syncs this loader now under a plain rule, and at the end of the frame
## under `VISIBLE`, once the player's plain loaders have run, so a panel's set and
## layers land above its scene's whatever the tree order.
func _sync_in_turn() -> void:
	if active_while == ActiveWhile.VISIBLE:
		_sync.call_deferred()
	else:
		_sync()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_tree_exited() -> void:
	# NOTE: The slot may have left the tree with this loader, leaving nothing to sync.
	if StdInputSlot.for_player(player_id):
		_resync_peers()


func _on_visibility_changed() -> void:
	if active_while == ActiveWhile.VISIBLE:
		_sync()
