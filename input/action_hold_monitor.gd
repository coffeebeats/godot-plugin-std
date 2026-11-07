##
## std/input/action_hold_monitor.gd
##
## StdInputActionHoldMonitor publishes the state a prompt for one action shows: the mode
## its hold runs in, whether a tapped toggle runs, and how far the hold has filled. It
## holds no text and draws nothing, so a game builds its own prompt over it.
##
## NOTE: The player's `StdInputSlot` must be in the tree when the monitor is ready,
## which it becomes on each entry.
##

class_name StdInputActionHoldMonitor
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## changed is emitted when `get_mode`, `is_toggle_running` or `get_progress` changes.
signal changed

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const MODE_INHERIT := StdInputActionHold.MODE_INHERIT
const MODE_TOGGLE := StdInputActionHold.MODE_TOGGLE

# -- CONFIGURATION ------------------------------------------------------------------- #

## action is the input action whose hold the monitor reports.
@export var action: StringName = &"":
	set(value):
		action = value
		_refresh()

## player_id is the player whose `StdInputSlot` runs the hold.
@export var player_id: int = 1:
	set(value):
		player_id = value
		_update_slot()

# -- INITIALIZATION ------------------------------------------------------------------ #

## _mode is the mode `action`'s hold runs in, or `MODE_INHERIT` when it's no hold.
var _mode: StdInputActionHold.Mode = MODE_INHERIT

## _mode_properties are the settings properties which choose `_mode`, connected since
## the slot reports no change to them while no hold runs.
var _mode_properties: Array[StdSettingsPropertyInt] = []

## _progress is how far the running hold has filled, from `0.0` to `1.0`.
var _progress: float = 0.0

## _slot is the slot of `player_id`, whose hold the monitor reports.
var _slot: StdInputSlot = null

## _toggle_running is whether a tap started a toggle which hasn't ended.
var _toggle_running: bool = false

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_mode returns the mode `action`'s hold runs in, or `MODE_INHERIT` when `action` is
## no hold or no slot is bound.
func get_mode() -> StdInputActionHold.Mode:
	return _mode


## get_progress returns how far `action`'s hold has filled, from `0.0` to `1.0`, or
## `0.0` while it isn't running.
func get_progress() -> float:
	return _progress


## is_toggle_running returns whether a tap started `action`'s `MODE_TOGGLE` hold, which
## fills on its own until it triggers or a second tap or an interruption cancels it.
func is_toggle_running() -> bool:
	return _toggle_running


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	# NOTE: A slot later in the scene enters after this node, so the bind waits for
	# `_ready`, which `request_ready` makes run again on the next entry.
	request_ready()

	_set_slot(null)


func _ready() -> void:
	_update_slot()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _refresh reads `action`'s hold state from the slot and emits `changed` if it differs.
func _refresh() -> void:
	var hold: StdInputActionHold = null
	if _slot and action:
		hold = _slot.get_action_hold(action)

	var properties: Array[StdSettingsPropertyInt] = []
	if hold:
		for property in [_slot.hold_mode_property, hold.mode_override]:
			if property and property not in properties:
				properties.append(property)

	_set_mode_properties(properties)

	var mode := MODE_INHERIT
	var progress := 0.0
	var toggle_running := false

	if hold:
		mode = _slot.get_action_hold_mode(action)
		progress = _slot.get_action_hold_progress(action)
		toggle_running = mode == MODE_TOGGLE and _slot.is_action_hold_active(action)

	if mode == _mode and progress == _progress and toggle_running == _toggle_running:
		return

	_mode = mode
	_progress = progress
	_toggle_running = toggle_running

	changed.emit()


## _set_mode_properties connects the monitor to `properties` in place of those it was
## connected to.
func _set_mode_properties(properties: Array[StdSettingsPropertyInt]) -> void:
	if properties == _mode_properties:
		return

	for property in _mode_properties:
		Signals.disconnect_safe(property.value_changed, _on_mode_property_value_changed)

	_mode_properties = properties

	for property in _mode_properties:
		Signals.connect_safe(property.value_changed, _on_mode_property_value_changed)


## _set_slot connects the monitor to the signals of `slot` in place of the slot it was
## connected to, and reports that slot's hold.
func _set_slot(slot: StdInputSlot) -> void:
	if slot == _slot:
		return

	# NOTE: A slot freed before the monitor, as a tree is freed, has no signals left.
	if is_instance_valid(_slot):
		_set_slot_connected(_slot, false)

	_slot = slot

	if _slot:
		_set_slot_connected(_slot, true)

	_refresh()


## _set_slot_connected connects the monitor to the signals of `slot` which change the
## hold it reports, or disconnects it from them.
func _set_slot_connected(slot: StdInputSlot, connected: bool) -> void:
	for pair in [
		[slot.action_configuration_changed, _refresh],
		[slot.action_hold_cancelled, _on_slot_action_hold_changed],
		[slot.action_hold_progress_changed, _on_slot_action_hold_progress_changed],
		[slot.action_hold_started, _on_slot_action_hold_changed],
		[slot.action_hold_triggered, _on_slot_action_hold_changed],
		[slot.hold_mode_property_changed, _refresh],
		[slot.tree_exiting, _on_slot_tree_exiting],
	]:
		if connected:
			Signals.connect_safe(pair[0], pair[1])
		else:
			Signals.disconnect_safe(pair[0], pair[1])


## _update_slot binds the monitor to the slot of `player_id` while it's in the tree.
func _update_slot() -> void:
	_set_slot(StdInputSlot.for_player(player_id) if is_inside_tree() else null)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_mode_property_value_changed(_value: Variant) -> void:
	_refresh()


func _on_slot_action_hold_changed(hold_action: StringName) -> void:
	if hold_action == action:
		_refresh()


func _on_slot_action_hold_progress_changed(
	hold_action: StringName, _progress_value: float
) -> void:
	if hold_action == action:
		_refresh()


func _on_slot_tree_exiting() -> void:
	_set_slot(null)
