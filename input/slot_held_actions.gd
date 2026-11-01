##
## std/input/slot_held_actions.gd
##
## StdInputSlotHeldActions times the actions a `StdInputSlot` holds, on every device, as
## one hold from the first press to the last release. An action already down when a set
## brings it in or a joypad swap ends its hold is blocked until released everywhere.
##
## NOTE: `Input` decides what's down, so a hold restarts on the next motion report of a
## stick still down when `Input` forgets it, as on a window losing focus.
##
## NOTE: An action outside the `InputMap` can't be read from `Input`, so only its
## release event ends it and it's never blocked; a stick still down can restart it.
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## action_pressed is emitted when a hold starts. See `StdInputSlot.action_pressed`.
signal action_pressed(action: StringName, device: int)

## action_released is emitted when a hold ends. See `StdInputSlot.action_released`.
signal action_released(action: StringName, device: int, held_seconds: float)

# -- DEFINITIONS --------------------------------------------------------------------- #

## _BLOCKED marks a blocked action in `_held_since`. It's far enough from any clock
## reading that a test moving a hold's stamp back can't reach it.
const _BLOCKED: int = -(1 << 62)

# -- INITIALIZATION ------------------------------------------------------------------ #

## _actions lists the actions which can be held.
var _actions: Array[StringName] = []

## _held_devices maps each held action to the device ID its release reports.
var _held_devices: Dictionary[StringName, int] = {}

## _held_since maps each action that isn't up to the ticks, in microseconds, of its
## first press, or to `_BLOCKED`.
var _held_since: Dictionary[StringName, int] = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_held_seconds returns the wall clock seconds since `action` was first pressed, or
## `0.0` while it isn't held.
func get_held_seconds(action: StringName) -> float:
	var since: int = _held_since.get(action, _BLOCKED)
	if since == _BLOCKED:
		return 0.0

	return (Time.get_ticks_usec() - since) / 1_000_000.0


## is_action_pressed returns whether `event` is a press of `action`. An injected action
## is matched by name, and a key, button, or motion only against an action the
## `InputMap` knows, since Steam publishes actions the map needn't define.
static func is_action_pressed(event: InputEvent, action: StringName) -> bool:
	if event is InputEventAction:
		return event.action == action and event.pressed

	return InputMap.has_action(action) and event.is_action_pressed(action)


## is_action_released returns whether `event` is a release of `action`, matched as
## `is_action_pressed` does.
static func is_action_released(event: InputEvent, action: StringName) -> bool:
	if event is InputEventAction:
		return event.action == action and not event.pressed

	return InputMap.has_action(action) and event.is_action_released(action)


## release_all ends every hold, blocking each action still down.
func release_all() -> void:
	for action: StringName in _held_since.keys():
		if _held_since.get(action, _BLOCKED) != _BLOCKED:
			_end_hold(action, _is_polled_down(action))


## set_actions sets the actions which can be held, ending the hold of each action left
## out and blocking each new action which is already down.
##
## NOTE: `action_released` is emitted last, so a listener which loads a set sees this
## change finished.
func set_actions(actions: Array[StringName]) -> void:
	var previous := _actions
	_actions = actions

	for action in actions:
		if (
			action not in previous
			and not _held_since.has(action)
			and _is_polled_down(action)
		):
			_held_since[action] = _BLOCKED

	set_process(not _held_since.is_empty())

	for action: StringName in _held_since.keys():
		if action not in _actions:
			_end_hold(action)


## update starts the hold of each action which `event` presses, and ends the hold of
## each which it releases on every device. `pressed` maps each device ID to the actions
## its injected presses hold, the only record of an action outside the `InputMap`.
func update(event: InputEvent, pressed: Dictionary[int, Array]) -> void:
	# NOTE: A listener can load a set, which replaces `_actions` but not this array.
	for action in _actions:
		var since: Variant = _held_since.get(action)

		if since == null:
			if is_action_pressed(event, action) and action in _actions:
				_held_devices[action] = event.device
				_held_since[action] = Time.get_ticks_usec()
				set_process(true)
				action_pressed.emit(action, event.device)
			continue

		# NOTE: `Input` tracks every bound event of every device and updates before it
		# dispatches, so it still reads pressed while anything else holds the action.
		if is_action_released(event, action) and not _is_down(action, pressed):
			if since != _BLOCKED:
				_held_devices[action] = event.device
			_end_hold(action)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _process(_delta: float) -> void:
	# NOTE: An upstream `_input` can hide a release from the slot, and a disconnected
	# joypad or a window losing focus changes `Input` with no event at all.
	for action: StringName in _held_since.keys():
		if InputMap.has_action(action) and not Input.is_action_pressed(action):
			_end_hold(action)


func _ready() -> void:
	set_process(not _held_since.is_empty())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _end_hold returns `action` to up, or to blocked if `block` is set, and reports the
## end of its hold if it had one.
func _end_hold(action: StringName, block: bool = false) -> void:
	var since: Variant = _held_since.get(action)
	if since == null:
		return

	var device: int = _held_devices.get(action, 0)
	var held_seconds := get_held_seconds(action)

	_held_devices.erase(action)

	if block:
		_held_since[action] = _BLOCKED
	else:
		_held_since.erase(action)

	set_process(not _held_since.is_empty())

	if since != _BLOCKED:
		action_released.emit(action, device, held_seconds)


## _is_down returns whether anything still holds `action`.
func _is_down(action: StringName, pressed: Dictionary[int, Array]) -> bool:
	if InputMap.has_action(action):
		return Input.is_action_pressed(action)

	for held: Array in pressed.values():
		if String(action) in held:
			return true

	return false


## _is_polled_down returns whether `Input` reads `action` as pressed.
func _is_polled_down(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)
