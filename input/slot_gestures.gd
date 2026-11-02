##
## std/input/slot_gestures.gd
##
## StdInputSlotGestures runs the holds which a `StdInputSlot`'s loaded set and enabled
## layers declare, as gestures over each action's press and release. It consumes no
## input, so a game can still read the raw press.
##
## A handler of a hold's action connects the slot's `action_hold_*` signals, filtered by
## its action, and doesn't act on the raw press in `_unhandled_input`. A confirm at the
## fill connects `action_hold_triggered`. A confirm on release or a charge connects
## `action_hold_completed`. A sustained action starts on `action_hold_started` and stops
## on `action_hold_completed` or `action_hold_cancelled`.
##
## NOTE: A hold fills on the wall clock, so it goes on filling in a paused tree, and a
## paused handler misses its signals. A menu which wants a clean break leaves the action
## out of its set.
##

extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## action_hold_cancelled is emitted as a hold is cancelled. See `StdInputSlot`.
signal action_hold_cancelled(action: StringName)

## action_hold_completed is emitted as a filled hold ends. See `StdInputSlot`.
signal action_hold_completed(action: StringName, held_seconds: float)

## action_hold_progress_changed is emitted as a hold's progress changes. See
## `StdInputSlot`.
signal action_hold_progress_changed(action: StringName, progress: float)

## action_hold_started is emitted as a hold starts. See `StdInputSlot`.
signal action_hold_started(action: StringName)

## action_hold_triggered is emitted as a hold fills. See `StdInputSlot`.
signal action_hold_triggered(action: StringName)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const MODE_HOLD := StdInputActionHold.MODE_HOLD
const MODE_INHERIT := StdInputActionHold.MODE_INHERIT
const MODE_PRESS := StdInputActionHold.MODE_PRESS
const MODE_TOGGLE := StdInputActionHold.MODE_TOGGLE


## _Gesture is a hold running from its start until it's completed or cancelled.
class _Gesture:
	## fill_seconds is how long the hold takes to fill, which is `0.0` if it fills at once.
	var fill_seconds: float = 0.0

	## hold is the declaration being run.
	var hold: StdInputActionHold = null

	## mode is the mode the hold resolved to when it started.
	var mode: StdInputActionHold.Mode = MODE_HOLD

	## progress is how far the hold has filled, as last reported.
	var progress: float = 0.0

	## started_usec is the ticks, in microseconds, at which the hold started.
	var started_usec: int = 0

	## get_elapsed_seconds returns the wall clock seconds since the hold started.
	func get_elapsed_seconds() -> float:
		return (Time.get_ticks_usec() - started_usec) / 1_000_000.0

	## is_filled returns whether the hold has reached its fill.
	func is_filled() -> bool:
		return progress >= 1.0


# -- INITIALIZATION ------------------------------------------------------------------ #

## _completing lists the actions whose `action_hold_completed` is being emitted, so a
## handler reads them as triggered though their gestures have ended.
var _completing: Array[StringName] = []

var _confirm_mode_property: StdSettingsPropertyInt = null
var _duration_scale_property: StdSettingsPropertyFloatRange = null

## _gestures maps each action to its running gesture.
var _gestures: Dictionary[StringName, _Gesture] = {}

## _holds maps each action to the hold which runs it.
var _holds: Dictionary[StringName, StdInputActionHold] = {}

var _logger := StdLogger.create("std/input/slot_gestures")
var _sustain_mode_property: StdSettingsPropertyInt = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## cancel_all cancels every running gesture. It's called before anything but the
## player's release ends the actions' holds, which would complete a filled gesture.
func cancel_all() -> void:
	for gesture: _Gesture in _gestures.values():
		_end(gesture, false)


## configure reads the holds of `action_sets`, ordered from the base set up, so the last
## to declare a hold on an action wins. It cancels each gesture whose hold is dropped.
func configure(action_sets: Array[StdInputActionSet]) -> void:
	var holds: Dictionary[StringName, StdInputActionHold] = {}
	var names := PackedStringArray()

	for action_set in action_sets:
		names.append_array(action_set.list_action_names())

		for hold in action_set.holds:
			if not hold:
				assert(false, "invalid config; missing hold")
				continue

			holds[hold.action] = hold

	for hold: StdInputActionHold in holds.values():
		assert(hold.action in names, "invalid config; hold's action isn't declared")
		assert(
			not hold.cancel_action or hold.cancel_action in names,
			"invalid config; hold's cancel action isn't declared",
		)
		assert(hold.duration >= 0.0, "invalid config; hold's duration is negative")

		if hold.mode_override:
			Signals.ensure_connected(
				hold.mode_override.value_changed, _on_property_value_changed
			)

	_holds = holds

	# NOTE: A listener can load a set, which replaces `_holds` but not this array.
	for gesture: _Gesture in _gestures.values():
		if _holds.get(gesture.hold.action) != gesture.hold:
			_end(gesture, false)


## get_hold returns the hold which runs `action`, or `null` when `action` is no hold.
func get_hold(action: StringName) -> StdInputActionHold:
	return _holds.get(action)


## get_mode returns the mode `action`'s hold resolves to, or `MODE_PRESS` when `action`
## is no hold, since it acts on the press.
func get_mode(action: StringName) -> StdInputActionHold.Mode:
	var hold: StdInputActionHold = _holds.get(action)
	return _resolve_mode(hold) if hold else MODE_PRESS


## get_progress returns how far `action`'s running gesture has filled, from `0.0` to
## `1.0`, or `0.0` when none is running.
func get_progress(action: StringName) -> float:
	var gesture: _Gesture = _gestures.get(action)
	return gesture.progress if gesture else 0.0


## is_active returns whether `action`'s gesture is running.
func is_active(action: StringName) -> bool:
	return _gestures.has(action)


## is_tracking returns whether any gesture is running.
func is_tracking() -> bool:
	return not _gestures.is_empty()


## is_triggered returns whether `action`'s running gesture has filled, which stays true
## through its `action_hold_completed`.
func is_triggered(action: StringName) -> bool:
	if action in _completing:
		return true

	var gesture: _Gesture = _gestures.get(action)
	return gesture.is_filled() if gesture else false


## poll moves each running gesture on. It must be called each frame while `is_tracking`
## returns `true`.
func poll() -> void:
	for gesture: _Gesture in _gestures.values():
		_advance(gesture)


## press handles the start of `action`'s hold on the slot. It ends each active toggle
## this taps, and otherwise starts `action`'s gesture.
##
## NOTE: A toggle filled at a duration of `0` is the player's to end, so it completes.
func press(action: StringName) -> void:
	var is_running := _gestures.has(action)

	for gesture: _Gesture in _gestures.values():
		if (
			gesture.mode == MODE_TOGGLE
			and action in [gesture.hold.action, gesture.hold.cancel_action]
		):
			_end(gesture, gesture.is_filled())

	var hold: StdInputActionHold = _holds.get(action)
	if hold and not is_running:
		_start(hold)


## release handles the end of `action`'s hold on the slot, which ends a `MODE_HOLD`
## gesture. It completes if it's filled, even if no frame has yet reported that.
func release(action: StringName) -> void:
	var gesture: _Gesture = _gestures.get(action)
	if not gesture or gesture.mode != MODE_HOLD:
		return

	_advance(gesture)
	_end(gesture, gesture.is_filled())


## set_properties sets the settings properties which holds resolve against. Any of them
## can be `null`.
func set_properties(
	confirm_mode_property: StdSettingsPropertyInt,
	sustain_mode_property: StdSettingsPropertyInt,
	duration_scale_property: StdSettingsPropertyFloatRange,
) -> void:
	_confirm_mode_property = confirm_mode_property
	_duration_scale_property = duration_scale_property
	_sustain_mode_property = sustain_mode_property

	for property: StdSettingsProperty in [
		confirm_mode_property,
		sustain_mode_property,
		duration_scale_property,
	]:
		if property:
			Signals.ensure_connected(property.value_changed, _on_property_value_changed)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _advance reports `gesture`'s progress and, once it's filled, triggers it.
## `MODE_PRESS` and a `MODE_TOGGLE` charge then complete on their own.
##
## NOTE: A listener can load a set, which can end the gesture at any emission.
func _advance(gesture: _Gesture) -> void:
	if gesture.is_filled() or not _is_running(gesture):
		return

	var progress := 1.0
	if gesture.fill_seconds > 0.0:
		progress = minf(gesture.get_elapsed_seconds() / gesture.fill_seconds, 1.0)

	if progress == gesture.progress:
		return

	var action := gesture.hold.action

	gesture.progress = progress
	action_hold_progress_changed.emit(action, progress)

	if not gesture.is_filled() or not _is_running(gesture):
		return

	action_hold_triggered.emit(action)

	if (
		gesture.mode == MODE_PRESS
		or (gesture.mode == MODE_TOGGLE and gesture.fill_seconds > 0.0)
	):
		_end(gesture, true)


## _end ends `gesture`, if it's still running, and reports whether it completed.
func _end(gesture: _Gesture, is_completed: bool) -> void:
	if not _is_running(gesture):
		return

	var action := gesture.hold.action
	var held_seconds := gesture.get_elapsed_seconds()

	_gestures.erase(action)

	if gesture.progress > 0.0:
		action_hold_progress_changed.emit(action, 0.0)

	if not is_completed:
		action_hold_cancelled.emit(action)
		return

	_completing.append(action)
	action_hold_completed.emit(action, held_seconds)
	_completing.erase(action)


## _is_running returns whether `gesture` is still the one running for its action.
func _is_running(gesture: _Gesture) -> bool:
	return _gestures.get(gesture.hold.action) == gesture


## _read_mode returns the mode `property` holds, or `MODE_INHERIT` when there's no
## property or it holds no mode, since player settings can be edited by hand.
func _read_mode(property: StdSettingsPropertyInt) -> StdInputActionHold.Mode:
	if not property:
		return MODE_INHERIT

	var value: int = property.get_value()
	if value not in StdInputActionHold.Mode.values():
		return MODE_INHERIT

	return value as StdInputActionHold.Mode


## _resolve_duration_scale returns what a hold's `duration` is multiplied by.
##
## NOTE: A scale of `0` would make a tap act at once whatever `allow_press` says, and
## nothing but this stops a game's own property from storing one.
func _resolve_duration_scale() -> float:
	if not _duration_scale_property:
		return 1.0

	var scale: float = _duration_scale_property.get_value()
	if scale > 0.0:
		return scale

	_logger.warn("Ignoring a duration scale that isn't positive.", {&"scale": scale})

	return 1.0


## _resolve_fill_seconds returns how long `hold` takes to fill, as it resolves now.
func _resolve_fill_seconds(hold: StdInputActionHold) -> float:
	if _resolve_mode(hold) == MODE_PRESS:
		return 0.0

	return hold.duration * _resolve_duration_scale()


## _resolve_mode returns the mode `hold` runs in, as it resolves now. That's the first
## choice among its `mode_override`, the property for its kind of hold, and its `mode`.
##
## NOTE: A sustained action has no press form, since it would start and stop at once, so
## `MODE_PRESS` at a duration of `0` runs as `MODE_HOLD`.
func _resolve_mode(hold: StdInputActionHold) -> StdInputActionHold.Mode:
	var mode := _read_mode(hold.mode_override)

	if mode == MODE_INHERIT:
		mode = _read_mode(
			_confirm_mode_property if hold.duration > 0.0 else _sustain_mode_property
		)

	if mode == MODE_INHERIT:
		mode = hold.mode

	if mode == MODE_INHERIT:
		return MODE_HOLD

	if mode != MODE_PRESS:
		return mode

	if not hold.allow_press:
		return MODE_TOGGLE

	return MODE_PRESS if hold.duration > 0.0 else MODE_HOLD


## _start runs `hold` from now.
func _start(hold: StdInputActionHold) -> void:
	var gesture := _Gesture.new()
	gesture.fill_seconds = _resolve_fill_seconds(hold)
	gesture.hold = hold
	gesture.mode = _resolve_mode(hold)
	gesture.started_usec = Time.get_ticks_usec()

	_gestures[hold.action] = gesture

	action_hold_started.emit(hold.action)
	_advance(gesture)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


## _on_property_value_changed cancels each running gesture the change alters, which
## leaves one running if its resolved mode and fill are the same.
func _on_property_value_changed(_value: Variant) -> void:
	for gesture: _Gesture in _gestures.values():
		if (
			gesture.mode != _resolve_mode(gesture.hold)
			or gesture.fill_seconds != _resolve_fill_seconds(gesture.hold)
		):
			_end(gesture, false)
