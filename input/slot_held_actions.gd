##
## std/input/slot_held_actions.gd
##
## StdInputSlotHeldActions times the actions a `StdInputSlot` holds, on every device, as
## one hold from the first press to the last release. A hold starts only on a change
## from up to down, so an input still down when its hold ended starts nothing.
##
## NOTE: An action outside the `InputMap` can't be read from `Input`, so only its
## release event ends it.
##

extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## action_pressed is emitted when a hold starts. See `StdInputSlot.action_pressed`.
signal action_pressed(action: StringName, device: int)

## action_released is emitted when a hold ends. See `StdInputSlot.action_released`.
## `is_interrupted` is `true` when `poll` ended it, since no release event reached it.
signal action_released(
	action: StringName, device: int, held_seconds: float, is_interrupted: bool
)

# -- INITIALIZATION ------------------------------------------------------------------ #

## _actions lists the actions which can be held.
var _actions: Array[StringName] = []

## _held_devices maps each held action to the device ID its release reports.
var _held_devices: Dictionary[StringName, int] = {}

## _held_since maps each held action to the ticks, in microseconds, of its first press.
var _held_since: Dictionary[StringName, int] = {}

## _reports maps each device's axis or injected action to its latest report, since these
## report a press again on every change rather than once.
var _reports: Dictionary[Array, InputEvent] = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_held_seconds returns the wall clock seconds since `action` was first pressed, or
## `0.0` while it isn't held.
func get_held_seconds(action: StringName) -> float:
	if not _held_since.has(action):
		return 0.0

	return (Time.get_ticks_usec() - _held_since[action]) / 1_000_000.0


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


## is_tracking returns whether any action is held.
func is_tracking() -> bool:
	return not _held_since.is_empty()


## poll ends the hold of each action `Input` no longer reads as down. It must be called
## each frame while `is_tracking` returns `true`.
##
## NOTE: An upstream `_input` can hide a release from the slot, and a disconnected
## joypad or a window losing focus changes `Input` with no event at all.
func poll() -> void:
	for action: StringName in _held_since.keys():
		if InputMap.has_action(action) and not Input.is_action_pressed(action):
			_end_hold(action, true)


## release_all ends every hold.
func release_all() -> void:
	for action: StringName in _held_since.keys():
		_end_hold(action)


## set_actions sets the actions which can be held, ending the hold of each action left
## out.
##
## NOTE: `action_released` is emitted last, so a listener which loads a set sees this
## change finished.
func set_actions(actions: Array[StringName]) -> void:
	_actions = actions

	for action: StringName in _held_since.keys():
		if action not in _actions:
			_end_hold(action)


## update starts the hold of each action which `event` presses, and ends the hold of
## each which it releases on every device. `pressed` maps each device ID to the actions
## its injected presses hold, the only record of an action outside the `InputMap`.
func update(event: InputEvent, pressed: Dictionary[int, Array]) -> void:
	var key := _get_report_key(event)
	var previous: InputEvent = _reports.get(key) if key else null
	var is_first_report := not key.is_empty() and previous == null

	if key:
		_reports[key] = event

	# NOTE: A listener can load a set, which replaces `_actions` but not this array.
	for action in _actions:
		if not _held_since.has(action):
			if (
				_is_press(event, action, previous, is_first_report)
				and action in _actions
			):
				_held_devices[action] = event.device
				_held_since[action] = Time.get_ticks_usec()
				action_pressed.emit(action, event.device)
			continue

		# NOTE: `Input` tracks every bound event of every device and updates before it
		# dispatches, so it still reads pressed while anything else holds the action.
		if is_action_released(event, action) and not _is_down(action, pressed):
			_held_devices[action] = event.device
			_end_hold(action)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _end_hold ends the hold of `action`, if any, and reports it.
func _end_hold(action: StringName, is_interrupted: bool = false) -> void:
	if not _held_since.has(action):
		return

	var device: int = _held_devices.get(action, 0)
	var held_seconds := get_held_seconds(action)

	_held_devices.erase(action)
	_held_since.erase(action)

	action_released.emit(action, device, held_seconds, is_interrupted)


## _get_report_key returns the key under which `event`'s source is recorded in
## `_reports`, or an empty array for an event which reports a press only once.
func _get_report_key(event: InputEvent) -> Array:
	if event is InputEventJoypadMotion:
		return [event.device, event.axis]

	if event is InputEventAction:
		return [event.device, event.action]

	return []


## _is_down returns whether anything still holds `action`.
func _is_down(action: StringName, pressed: Dictionary[int, Array]) -> bool:
	if InputMap.has_action(action):
		return Input.is_action_pressed(action)

	for held: Array in pressed.values():
		if String(action) in held:
			return true

	return false


## _is_press returns whether `event` moves `action` from up to down. A source which
## reports on every change is judged against `previous`, its last report, or against
## `Input` on its first report, since `Input` saw every event this didn't.
func _is_press(
	event: InputEvent, action: StringName, previous: InputEvent, is_first_report: bool
) -> bool:
	if not is_action_pressed(event, action):
		return false

	if previous:
		return not is_action_pressed(previous, action)

	if is_first_report and InputMap.has_action(action):
		return Input.is_action_just_pressed(action)

	return true


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


## _on_joy_connection_changed forgets a disconnected joypad's axes, since Godot clears
## them with no event and a joypad reconnecting at rest reports nothing.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return

	for key: Array in _reports.keys():
		if key[0] == device and key[1] is int:
			_reports.erase(key)
