# gdlint:ignore=max-public-methods
# gdlint:disable=max-file-lines
##
## std/input/slot_gestures_test.gd
##
## Tests pertaining to how a `StdInputSlot` runs the holds its action sets declare,
## driven by real events and simulated time.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _ACTION is the action most tests run as a hold.
const _ACTION := &"probe_gesture"

## _ACTION_CANCEL is an action a hold names as its `cancel_action`.
const _ACTION_CANCEL := &"probe_gesture_cancel"

## _ACTION_OTHER is an action declared beside `_ACTION`.
const _ACTION_OTHER := &"probe_gesture_other"

## _ACTIONS lists every action this file defines.
const _ACTIONS: Array[StringName] = [_ACTION, _ACTION_CANCEL, _ACTION_OTHER]

## _DURATION is the `duration` of a hold that isn't sustained, in seconds.
const _DURATION := 1.0

## _HOLD_SIGNALS lists each signal a hold can emit.
const _HOLD_SIGNALS: Array[String] = [
	"action_hold_cancelled",
	"action_hold_completed",
	"action_hold_progress_changed",
	"action_hold_started",
	"action_hold_triggered",
]

const MODE_HOLD := StdInputActionHold.MODE_HOLD
const MODE_INHERIT := StdInputActionHold.MODE_INHERIT
const MODE_PRESS := StdInputActionHold.MODE_PRESS
const MODE_TOGGLE := StdInputActionHold.MODE_TOGGLE

# -- INITIALIZATION ------------------------------------------------------------------ #

var confirm_mode: StdSettingsPropertyInt = null
var duration_scale: StdSettingsPropertyFloatRange = null
var input: StdTestInput = null
var slot: StdInputSlot = null
var sustain_mode: StdSettingsPropertyInt = null

# -- TEST METHODS -------------------------------------------------------------------- #

# HOLD


func test_hold_fills_at_the_duration_and_completes_on_release() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# When: The action is pressed.
	input.press_action(_ACTION)

	# Then: The hold is active and hasn't filled.
	assert_signal_emit_count(slot, "action_hold_started", 1)
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_false(slot.is_action_hold_triggered(_ACTION))

	# When: The press lasts past the duration.
	await _elapse(_DURATION + 0.5)

	# Then: The hold triggers once and stays active.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_true(slot.is_action_hold_triggered(_ACTION))
	assert_eq(slot.get_action_hold_progress(_ACTION), 1.0)

	# When: A frame passes while it stays held.
	await wait_process_frames(1)

	# Then: It doesn't trigger again.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: The hold completes, reporting how long it ran.
	assert_signal_emit_count(slot, "action_hold_completed", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_gte(get_signal_parameters(slot, "action_hold_completed")[1], _DURATION)

	# Then: Nothing reads as running.
	assert_false(slot.is_action_hold_active(_ACTION))
	assert_false(slot.is_action_hold_triggered(_ACTION))
	assert_eq(slot.get_action_hold_progress(_ACTION), 0.0)


func test_hold_released_before_the_fill_cancels() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The action is pressed, for less than the duration.
	input.press_action(_ACTION)
	await _elapse(_DURATION * 0.25)

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: The hold cancels without triggering.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)
	assert_signal_emit_count(slot, "action_hold_completed", 0)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_hold_released_past_the_fill_before_a_frame_reports_it_completes() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The press lasted past the duration, in a frame that hasn't ended.
	input.press_action(_ACTION)
	_set_elapsed(_DURATION + 0.5)
	assert_signal_emit_count(slot, "action_hold_triggered", 0, "precondition")

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: The hold triggers, then completes.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
	assert_signal_emit_count(slot, "action_hold_completed", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)


func test_hold_reports_progress_and_its_drop_as_it_ends() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# When: The press lasts half the duration.
	input.press_action(_ACTION)
	await _elapse(_DURATION * 0.5)

	# Then: The progress reads about half, in the getter and the signal.
	assert_almost_eq(slot.get_action_hold_progress(_ACTION), 0.5, 0.2)
	assert_eq(
		get_signal_parameters(slot, "action_hold_progress_changed")[1],
		slot.get_action_hold_progress(_ACTION),
	)

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: The signal reports the drop to none.
	assert_eq(get_signal_parameters(slot, "action_hold_progress_changed")[1], 0.0)


func test_hold_reads_as_triggered_during_its_completion() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: A handler records what it reads as the hold completes.
	var triggered: Array[bool] = []
	var active: Array[bool] = []
	slot.action_hold_completed.connect(
		func(action: StringName, _held_seconds: float) -> void:
			triggered.append(slot.is_action_hold_triggered(action))
			active.append(slot.is_action_hold_active(action))
	)

	# Given: The hold has filled.
	input.press_action(_ACTION)
	await _elapse(_DURATION)

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: The handler read it as triggered and no longer active.
	assert_eq(triggered, [true] as Array[bool])
	assert_eq(active, [false] as Array[bool])

	# Then: It no longer reads as triggered.
	assert_false(slot.is_action_hold_triggered(_ACTION))


func test_hold_at_duration_zero_runs_from_the_press_until_the_release() -> void:
	# Given: A sustained hold is declared.
	await _mount(_make_hold(MODE_HOLD, 0.0))

	# When: The action is pressed.
	input.press_action(_ACTION)

	# Then: The hold starts filled.
	assert_signal_emit_count(slot, "action_hold_started", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
	assert_eq(slot.get_action_hold_progress(_ACTION), 1.0)
	assert_true(slot.is_action_hold_active(_ACTION))

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: The hold completes.
	assert_signal_emit_count(slot, "action_hold_completed", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_hold_ignores_its_cancel_action() -> void:
	# Given: A hold naming a cancel action is declared.
	var hold := _make_hold(MODE_HOLD)
	hold.cancel_action = _ACTION_CANCEL
	await _mount(hold)

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: The cancel action is pressed.
	input.press_action(_ACTION_CANCEL)

	# Then: The hold goes on, since only a toggle has one to cancel.
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_true(slot.is_action_hold_active(_ACTION))


func test_hold_runs_from_a_key_as_from_any_other_press() -> void:
	# Given: A hold is declared on an action bound to a key.
	await _mount(_make_hold(MODE_HOLD))

	# When: The key is held past the duration.
	input.press_key(KEY_G)
	await _elapse(_DURATION)

	# Then: The hold triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)

	# When: The key is released.
	input.release_key(KEY_G)

	# Then: The hold completes.
	assert_signal_emit_count(slot, "action_hold_completed", 1)


func test_hold_released_with_no_event_cancels_though_filled() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The hold has filled.
	input.press_action(_ACTION)
	await _elapse(_DURATION)

	# When: `Input` reads the action as up with no event, as after a loss of focus.
	Input.action_release(_ACTION)
	await wait_process_frames(1)

	# Then: The hold cancels rather than completing.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_completed", 0)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_hold_released_with_no_event_doesnt_trigger_an_unreported_fill() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The action is pressed, and the duration passes with no frame to report it.
	input.press_action(_ACTION)
	_set_elapsed(_DURATION + 0.5)

	# When: `Input` reads the action as up with no event.
	Input.action_release(_ACTION)
	await wait_process_frames(1)

	# Then: The hold cancels without triggering.
	assert_signal_emit_count(slot, "action_hold_triggered", 0)
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)


func test_toggle_released_with_no_event_stays_active() -> void:
	# Given: A toggle at duration 0 is declared.
	await _mount(_make_hold(MODE_TOGGLE, 0.0))

	# Given: The action is pressed, which starts the toggle.
	input.press_action(_ACTION)
	assert_true(slot.is_action_hold_active(_ACTION), "precondition: active")

	# When: `Input` reads the action as up with no event.
	Input.action_release(_ACTION)
	await wait_process_frames(1)

	# Then: The toggle stays active, since it ignores its release.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_signal_emit_count(slot, "action_hold_completed", 0)


# TOGGLE


func test_toggle_charge_completes_on_its_own_after_a_tap() -> void:
	# Given: A toggle with a duration is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# When: The action is tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# Then: The hold stays active past the release.
	assert_signal_emit_count(slot, "action_hold_started", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_signal_emit_count(slot, "action_hold_completed", 0)
	assert_true(slot.is_action_hold_active(_ACTION))

	# When: The duration passes.
	await _elapse(_DURATION + 0.5)

	# Then: The hold triggers, then completes on its own.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
	assert_signal_emit_count(slot, "action_hold_completed", 1)
	assert_gte(get_signal_parameters(slot, "action_hold_completed")[1], _DURATION)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_toggle_charge_runs_while_the_slot_holds_nothing() -> void:
	# Given: A toggle with a duration is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The action was tapped, and frames have passed since.
	input.press_action(_ACTION)
	input.release_action(_ACTION)
	await wait_process_frames(2)
	assert_eq(slot.get_action_held_seconds(_ACTION), 0.0, "precondition: not held")

	# When: The duration passes.
	await _elapse(_DURATION)

	# Then: The slot was still processing, so the hold completes.
	assert_signal_emit_count(slot, "action_hold_completed", 1)


func test_toggle_charge_second_tap_cancels() -> void:
	# Given: A toggle with a duration is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: The action is tapped again before the fill.
	input.press_action(_ACTION)

	# Then: The hold cancels, and the tap starts nothing.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_started", 1)
	assert_false(slot.is_action_hold_active(_ACTION))

	# When: The tap is released and the duration passes.
	input.release_action(_ACTION)
	await _elapse(_DURATION)

	# Then: Nothing triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_toggle_charge_cancel_action_cancels() -> void:
	# Given: A toggle with a duration, naming a cancel action, is declared.
	var hold := _make_hold(MODE_TOGGLE)
	hold.cancel_action = _ACTION_CANCEL
	await _mount(hold)

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: The cancel action is pressed.
	input.press_action(_ACTION_CANCEL)

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emitted_with_parameters(slot, "action_hold_cancelled", [_ACTION])
	assert_false(slot.is_action_hold_active(_ACTION))


func test_toggle_charge_tap_after_completing_starts_again() -> void:
	# Given: A toggle with a duration is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The action's charge has completed.
	input.press_action(_ACTION)
	input.release_action(_ACTION)
	await _elapse(_DURATION)
	assert_signal_emit_count(slot, "action_hold_completed", 1, "precondition")

	# When: The action is tapped again.
	input.press_action(_ACTION)

	# Then: A new hold starts.
	assert_signal_emit_count(slot, "action_hold_started", 2)
	assert_true(slot.is_action_hold_active(_ACTION))


func test_toggle_at_duration_zero_stays_on_until_a_second_tap() -> void:
	# Given: A sustained toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE, 0.0))

	# When: The action is tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# Then: The hold is on, past the release.
	assert_signal_emit_count(slot, "action_hold_started", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
	assert_true(slot.is_action_hold_active(_ACTION))

	# When: Frames pass.
	await wait_process_frames(2)

	# Then: It doesn't end on its own.
	assert_signal_emit_count(slot, "action_hold_completed", 0)
	assert_true(slot.is_action_hold_active(_ACTION))

	# When: The action is tapped again.
	input.press_action(_ACTION)

	# Then: The hold completes, since the player ended it.
	assert_signal_emit_count(slot, "action_hold_completed", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_toggle_at_duration_zero_cancel_action_completes_it() -> void:
	# Given: A sustained toggle, naming a cancel action, is declared.
	var hold := _make_hold(MODE_TOGGLE, 0.0)
	hold.cancel_action = _ACTION_CANCEL
	await _mount(hold)

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: The cancel action is pressed.
	input.press_action(_ACTION_CANCEL)

	# Then: The hold completes, since the player ended it.
	assert_signal_emit_count(slot, "action_hold_completed", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_false(slot.is_action_hold_active(_ACTION))


# PRESS


func test_press_triggers_and_completes_at_once() -> void:
	# Given: A hold with a duration is declared to run on the press.
	await _mount(_make_hold(MODE_PRESS))

	# When: The action is pressed.
	input.press_action(_ACTION)

	# Then: The hold starts, triggers and completes without waiting.
	assert_signal_emit_count(slot, "action_hold_started", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
	assert_signal_emit_count(slot, "action_hold_completed", 1)
	assert_false(slot.is_action_hold_active(_ACTION))

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: Nothing more is reported.
	assert_signal_emit_count(slot, "action_hold_completed", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)


func test_press_at_duration_zero_runs_as_a_sustained_hold() -> void:
	# Given: A sustained hold is declared to run on the press.
	await _mount(_make_hold(MODE_PRESS, 0.0))

	# Then: It resolves to a hold.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_HOLD)

	# When: The action is pressed.
	input.press_action(_ACTION)

	# Then: It stays active rather than starting and stopping at once.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_completed", 0)

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: The hold completes.
	assert_signal_emit_count(slot, "action_hold_completed", 1)


# Mode resolution


func test_mode_uses_the_holds_own_mode_while_each_property_inherits() -> void:
	# Given: A hold's own mode, with every property it reads left at `MODE_INHERIT`.
	var hold := _make_hold(MODE_TOGGLE)
	hold.mode_override = _make_mode_property(&"override")
	await _mount(hold)

	# Then: The hold's own mode runs.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)


func test_mode_inherit_on_the_hold_runs_as_hold() -> void:
	# Given: A hold whose own mode inherits, with nothing to inherit from.
	await _mount(_make_hold(MODE_INHERIT))

	# Then: It runs as a hold, and the mode reported is never `MODE_INHERIT`.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_HOLD)


func test_mode_confirm_property_decides_only_a_hold_with_a_duration() -> void:
	# Given: A hold with a duration and a sustained hold.
	var other := _make_hold(MODE_HOLD, 0.0, _ACTION_OTHER)
	await _mount(_make_hold(MODE_HOLD), [other])

	# When: The player chooses a mode for holds with a duration.
	confirm_mode.set_value(MODE_TOGGLE)

	# Then: Only the hold with a duration follows it.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)
	assert_eq(slot.get_action_hold_mode(_ACTION_OTHER), MODE_HOLD)


func test_mode_sustain_property_decides_only_a_hold_at_duration_zero() -> void:
	# Given: A hold with a duration and a sustained hold.
	var other := _make_hold(MODE_HOLD, 0.0, _ACTION_OTHER)
	await _mount(_make_hold(MODE_HOLD), [other])

	# When: The player chooses a mode for sustained holds.
	sustain_mode.set_value(MODE_TOGGLE)

	# Then: Only the sustained hold follows it.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_HOLD)
	assert_eq(slot.get_action_hold_mode(_ACTION_OTHER), MODE_TOGGLE)


func test_mode_override_beats_the_slots_properties() -> void:
	# Given: A hold with a mode override.
	var hold := _make_hold(MODE_HOLD)
	hold.mode_override = _make_mode_property(&"override")
	await _mount(hold)

	# Given: The player chose a mode for every hold with a duration.
	confirm_mode.set_value(MODE_TOGGLE)

	# When: The player chooses another for this hold's group.
	hold.mode_override.set_value(MODE_PRESS)

	# Then: The override decides.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_PRESS)


func test_mode_override_at_inherit_defers_to_the_slots_property() -> void:
	# Given: A hold with a mode override left at `MODE_INHERIT`.
	var hold := _make_hold(MODE_HOLD)
	hold.mode_override = _make_mode_property(&"override")
	await _mount(hold)

	# When: The player chooses a mode for every hold with a duration.
	confirm_mode.set_value(MODE_TOGGLE)

	# Then: The slot's property decides.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)


func test_mode_stored_value_that_is_no_mode_defers_to_the_next_source() -> void:
	# Given: A hold's own mode.
	await _mount(_make_hold(MODE_TOGGLE))

	# When: The player's settings store something that's no mode.
	confirm_mode.set_value(99)

	# Then: The hold's own mode runs.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)


func test_mode_press_without_allow_press_runs_as_toggle_from_its_own_mode() -> void:
	# Given: A hold which rules out the press, declared to run on the press.
	var hold := _make_hold(MODE_PRESS)
	hold.allow_press = false
	await _mount(hold)

	# Then: It resolves to a toggle.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)

	# When: The action is pressed.
	input.press_action(_ACTION)

	# Then: A tap doesn't skip the duration.
	assert_signal_emit_count(slot, "action_hold_triggered", 0)

	# When: The duration passes.
	await _elapse(_DURATION)

	# Then: The hold triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_mode_press_without_allow_press_runs_as_toggle_from_a_stored_value() -> void:
	# Given: A hold which rules out the press.
	var hold := _make_hold(MODE_HOLD)
	hold.allow_press = false
	await _mount(hold)

	# When: The player's settings store the press.
	confirm_mode.set_value(MODE_PRESS)

	# Then: It resolves to a toggle.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)


func test_mode_press_without_allow_press_at_duration_zero_runs_as_toggle() -> void:
	# Given: A sustained hold which rules out the press.
	var hold := _make_hold(MODE_PRESS, 0.0)
	hold.allow_press = false
	await _mount(hold)

	# Then: It resolves to the on/off toggle, not a hold.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)


func test_mode_reads_as_press_for_an_action_that_is_no_hold() -> void:
	# Given: An action no hold names.
	await _mount(_make_hold(MODE_HOLD))

	# Then: It reads as what it does, with nothing to run.
	assert_null(slot.get_action_hold(_ACTION_OTHER))
	assert_eq(slot.get_action_hold_mode(_ACTION_OTHER), MODE_PRESS)
	assert_eq(slot.get_action_hold_progress(_ACTION_OTHER), 0.0)
	assert_false(slot.is_action_hold_active(_ACTION_OTHER))
	assert_false(slot.is_action_hold_triggered(_ACTION_OTHER))


func test_mode_action_that_is_no_hold_runs_nothing() -> void:
	# Given: An action no hold names.
	await _mount(_make_hold(MODE_HOLD))

	# When: The action is pressed.
	input.press_action(_ACTION_OTHER)

	# Then: The raw press is reported, with no hold.
	assert_signal_emit_count(slot, "action_pressed", 1)
	for hold_signal in _HOLD_SIGNALS:
		assert_signal_emit_count(slot, hold_signal, 0)


func test_slot_answers_before_it_is_ready() -> void:
	# Given: A slot which hasn't entered the tree.
	autofree(slot)

	# Then: A widget asking about a hold gets an answer, as nothing is declared yet.
	assert_null(slot.get_action_hold(_ACTION))
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_PRESS)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_slot_without_properties_runs_each_holds_own_mode() -> void:
	# Given: A slot which wires no settings properties.
	slot.hold_confirm_mode_property = null
	slot.hold_duration_scale_property = null
	slot.hold_sustain_mode_property = null

	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# When: The action is tapped, and the duration passes.
	input.press_action(_ACTION)
	input.release_action(_ACTION)
	await _elapse(_DURATION)

	# Then: The hold ran in its own mode at its own duration.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)
	assert_signal_emit_count(slot, "action_hold_completed", 1)


# Duration scale


func test_duration_scale_stretches_the_fill() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The player doubled the time holds take.
	duration_scale.set_value(2.0)

	# When: The press lasts past the declared duration, short of the scaled one.
	input.press_action(_ACTION)
	await _elapse(_DURATION + 0.5)

	# Then: The hold hasn't filled.
	assert_signal_emit_count(slot, "action_hold_triggered", 0)

	# When: The press lasts past the scaled duration.
	await _elapse(_DURATION * 2.0)

	# Then: The hold fills.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_duration_scale_of_zero_is_rejected() -> void:
	# Given: A property whose range lets it store zero.
	duration_scale.minimum = 0.0
	duration_scale.default = 0.0

	# Given: A hold which rules out the press.
	var hold := _make_hold(MODE_PRESS)
	hold.allow_press = false
	await _mount(hold)

	# When: The action is pressed.
	input.press_action(_ACTION)
	await wait_process_frames(1)

	# Then: A tap doesn't act at once.
	assert_signal_emit_count(slot, "action_hold_triggered", 0)

	# When: The declared duration passes.
	await _elapse(_DURATION)

	# Then: The hold fills at it.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_duration_scale_below_zero_is_rejected() -> void:
	# Given: A property whose range lets it store a negative value.
	duration_scale.minimum = -1.0
	duration_scale.default = -0.5

	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# When: The action is pressed.
	input.press_action(_ACTION)
	await wait_process_frames(1)

	# Then: The hold hasn't filled.
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


# Setting changes


func test_setting_change_mid_gesture_cancels() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: The player changes the mode.
	confirm_mode.set_value(MODE_TOGGLE)

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_false(slot.is_action_hold_active(_ACTION))

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: Nothing more is reported.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_completed", 0)


func test_setting_change_cancels_a_filled_hold() -> void:
	# Given: A hold has filled.
	await _mount(_make_hold(MODE_HOLD))
	input.press_action(_ACTION)
	await _elapse(_DURATION)

	# When: The player changes the mode.
	confirm_mode.set_value(MODE_TOGGLE)

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_completed", 0)


func test_setting_change_through_a_mode_override_cancels() -> void:
	# Given: A hold with a mode override.
	var hold := _make_hold(MODE_HOLD)
	hold.mode_override = _make_mode_property(&"override")
	await _mount(hold)

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: The player changes the override.
	hold.mode_override.set_value(MODE_TOGGLE)

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)


func test_setting_change_to_the_duration_scale_cancels() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: The player changes the time holds take.
	duration_scale.set_value(2.0)

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)


func test_setting_change_that_leaves_the_gesture_alone_keeps_it() -> void:
	# Given: A hold with a duration, whose mode a sustained hold's setting doesn't decide.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: The player changes the setting for sustained holds.
	sustain_mode.set_value(MODE_TOGGLE)

	# Then: The hold goes on.
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_true(slot.is_action_hold_active(_ACTION))


func test_setting_change_to_the_scale_keeps_a_gesture_at_duration_zero() -> void:
	# Given: A sustained hold.
	await _mount(_make_hold(MODE_HOLD, 0.0))

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: The player changes the time holds take.
	duration_scale.set_value(2.0)

	# Then: The hold goes on, as it takes no time at any scale.
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_true(slot.is_action_hold_active(_ACTION))


# Set and layer changes


func test_layer_disabled_mid_gesture_cancels() -> void:
	# Given: A layer declaring a hold on an action its parent declares.
	var action_set := _make_set([])
	var layer := _make_layer([_make_hold(MODE_HOLD)], action_set)
	await _mount_set(action_set)
	slot.enable_action_set_layer(layer)

	# Given: The action is held.
	input.press_action(_ACTION)
	assert_true(slot.is_action_hold_active(_ACTION), "precondition")

	# When: The layer is disabled.
	slot.disable_action_set_layer(layer)

	# Then: The hold cancels, while the action stays held.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_false(slot.is_action_hold_active(_ACTION))
	assert_gt(slot.get_action_held_seconds(_ACTION), 0.0)


func test_layer_disabled_cancels_a_filled_hold_rather_than_completing_it() -> void:
	# Given: A layer declaring a hold.
	var action_set := _make_set([])
	var layer := _make_layer([_make_hold(MODE_HOLD)], action_set)
	await _mount_set(action_set)
	slot.enable_action_set_layer(layer)

	# Given: The hold has filled.
	input.press_action(_ACTION)
	await _elapse(_DURATION)

	# When: The layer is disabled.
	slot.disable_action_set_layer(layer)

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_completed", 0)


func test_layer_hold_replaces_the_sets_until_it_is_disabled() -> void:
	# Given: A set and a layer declaring different holds on one action.
	var set_hold := _make_hold(MODE_HOLD)
	var layer_hold := _make_hold(MODE_TOGGLE)
	var action_set := _make_set([set_hold])
	var layer := _make_layer([layer_hold], action_set)
	await _mount_set(action_set)

	# When: The layer is enabled.
	slot.enable_action_set_layer(layer)

	# Then: The layer's hold runs.
	assert_eq(slot.get_action_hold(_ACTION), layer_hold)
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)

	# When: The layer is disabled.
	slot.disable_action_set_layer(layer)

	# Then: The set's hold runs.
	assert_eq(slot.get_action_hold(_ACTION), set_hold)
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_HOLD)


func test_layer_enabled_mid_gesture_replacing_its_hold_cancels() -> void:
	# Given: A set declaring a hold, and a layer replacing it.
	var action_set := _make_set([_make_hold(MODE_HOLD)])
	var layer := _make_layer([_make_hold(MODE_TOGGLE)], action_set)
	await _mount_set(action_set)

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: The layer is enabled.
	slot.enable_action_set_layer(layer)

	# Then: The first hold cancels, and the second waits for a press.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_set_change_keeping_the_hold_keeps_the_gesture() -> void:
	# Given: A hold is declared.
	var hold := _make_hold(MODE_HOLD)
	await _mount(hold)

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: A set declaring the same hold is loaded.
	slot.load_action_set(_make_set([hold]))

	# Then: The hold goes on.
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_true(slot.is_action_hold_active(_ACTION))


func test_set_change_dropping_a_filled_hold_cancels_rather_than_completing() -> void:
	# Given: A hold has filled.
	await _mount(_make_hold(MODE_HOLD))
	input.press_action(_ACTION)
	await _elapse(_DURATION)

	# When: A set without the hold or its action is loaded.
	slot.load_action_set(_make_set([], [_ACTION_OTHER]))

	# Then: The hold cancels, though the slot releases the action.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_completed", 0)


func test_set_change_cancels_an_active_toggle() -> void:
	# Given: A sustained toggle is on.
	await _mount(_make_hold(MODE_TOGGLE, 0.0))
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: A set without the hold is loaded.
	slot.load_action_set(_make_set([]))

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_set_loaded_by_a_cancel_listener_outlives_the_change_it_interrupts() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: A listener loads a set when a hold cancels.
	var next := _make_set(
		[_make_hold(MODE_TOGGLE, 0.0, _ACTION_OTHER)], [_ACTION_OTHER]
	)
	slot.action_hold_cancelled.connect(
		func(_action: StringName) -> void: slot.load_action_set(next),
		CONNECT_ONE_SHOT,
	)

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: A set dropping the hold, and not declaring the listener's action, is loaded.
	slot.load_action_set(_make_set([], [_ACTION]))

	# Then: The listener's set stays loaded.
	assert_eq(slot.actions.get_action_set(slot.device_id), next)
	assert_eq(slot.get_action_hold_mode(_ACTION_OTHER), MODE_TOGGLE)
	assert_null(slot.get_action_hold(_ACTION))

	# When: The action the listener's set declares is pressed.
	input.press_action(_ACTION_OTHER)

	# Then: Its hold runs, so the slot kept that set's actions.
	assert_true(slot.is_action_hold_active(_ACTION_OTHER))


func test_set_loaded_by_a_started_listener_ends_the_press_it_interrupts() -> void:
	# Given: A press-mode hold is declared.
	await _mount(_make_hold(MODE_PRESS))

	# Given: A listener loads a set dropping the hold as it starts.
	slot.action_hold_started.connect(
		func(_action: StringName) -> void: slot.load_action_set(_make_set([])),
		CONNECT_ONE_SHOT,
	)

	# When: The action is pressed.
	input.press_action(_ACTION)

	# Then: The hold cancels without triggering.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)
	assert_signal_emit_count(slot, "action_hold_completed", 0)


func test_set_loaded_by_a_progress_listener_stops_the_trigger() -> void:
	# Given: A sustained hold is declared.
	await _mount(_make_hold(MODE_HOLD, 0.0))

	# Given: A listener loads a set dropping the hold as its progress changes.
	slot.action_hold_progress_changed.connect(
		func(_action: StringName, _progress: float) -> void:
			slot.load_action_set(_make_set([])),
		CONNECT_ONE_SHOT,
	)

	# When: The action is pressed.
	input.press_action(_ACTION)

	# Then: The hold cancels without triggering.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_set_loaded_by_a_trigger_listener_cancels_rather_than_completes() -> void:
	# Given: A press-mode hold is declared.
	await _mount(_make_hold(MODE_PRESS))

	# Given: A listener loads a set dropping the hold as it triggers.
	slot.action_hold_triggered.connect(
		func(_action: StringName) -> void: slot.load_action_set(_make_set([])),
		CONNECT_ONE_SHOT,
	)

	# When: The action is pressed.
	input.press_action(_ACTION)

	# Then: The hold ends once, cancelled.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_completed", 0)


func test_set_loaded_by_a_cancel_listener_cancels_each_other_gesture_once() -> void:
	# Given: Two holds are declared.
	await _mount(_make_hold(MODE_HOLD), [_make_hold(MODE_HOLD, 1.0, _ACTION_OTHER)])

	# Given: Both actions are held.
	input.press_action(_ACTION)
	input.press_action(_ACTION_OTHER)

	# Given: A listener loads another set with no holds as the first cancels.
	slot.action_hold_cancelled.connect(
		func(_action: StringName) -> void: slot.load_action_set(_make_set([])),
		CONNECT_ONE_SHOT,
	)

	# When: A set dropping both holds is loaded.
	slot.load_action_set(_make_set([]))

	# Then: Each gesture cancels exactly once.
	assert_signal_emit_count(slot, "action_hold_cancelled", 2)
	assert_false(slot.is_action_hold_active(_ACTION))
	assert_false(slot.is_action_hold_active(_ACTION_OTHER))


# Interruptions


func test_swap_cancels_a_filled_hold_rather_than_completing_it() -> void:
	# Given: A hold has filled.
	await _mount(_make_hold(MODE_HOLD))
	input.press_action(_ACTION)
	await _elapse(_DURATION)

	# When: The joypad components are swapped.
	_swap_joypad_components()

	# Then: The hold cancels, though the slot releases the action.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_completed", 0)


func test_swap_cancels_an_active_toggle() -> void:
	# Given: A toggle's charge is running, with nothing held.
	await _mount(_make_hold(MODE_TOGGLE))
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: The joypad components are swapped.
	_swap_joypad_components()

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_leaving_the_tree_cancels_a_filled_hold() -> void:
	# Given: A hold has filled.
	await _mount(_make_hold(MODE_HOLD))
	input.press_action(_ACTION)
	await _elapse(_DURATION)

	# When: The slot leaves the tree.
	slot.get_parent().remove_child(slot)
	autofree(slot)

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_completed", 0)


func test_hold_fills_while_the_tree_is_paused() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The tree is paused, as behind a pause menu.
	get_tree().paused = true

	# When: The action is held past the duration.
	input.press_action(_ACTION)
	await _elapse(_DURATION)

	# Then: The hold fills.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_slot_stops_processing_once_nothing_runs() -> void:
	# Given: A toggle's charge has completed, with nothing held.
	await _mount(_make_hold(MODE_TOGGLE))
	input.press_action(_ACTION)
	input.release_action(_ACTION)
	await _elapse(_DURATION)
	assert_signal_emit_count(slot, "action_hold_completed", 1, "precondition")

	# When: A frame passes.
	await wait_process_frames(1)

	# Then: The slot no longer processes.
	assert_false(slot.is_processing())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _ACTIONS:
		InputMap.erase_action(action)


func after_each() -> void:
	get_tree().paused = false

	# NOTE: `Input` outlives each test, so a press left down would carry into the next.
	for action in _ACTIONS:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func before_all() -> void:
	for action in _ACTIONS:
		InputMap.add_action(action, 0.5)

	var key := InputEventKey.new()
	key.keycode = KEY_G
	key.physical_keycode = KEY_G
	InputMap.action_add_event(_ACTION, key)


func before_each() -> void:
	confirm_mode = _make_mode_property(&"confirm")
	sustain_mode = _make_mode_property(&"sustain")

	duration_scale = StdSettingsPropertyFloatRange.new()
	duration_scale.category = &"probe"
	duration_scale.name = &"scale"
	duration_scale.scope = StdSettingsScope.new()
	duration_scale.minimum = 0.5
	duration_scale.maximum = 2.0
	duration_scale.default = 1.0

	slot = SlotTest.make_slot()
	slot.hold_confirm_mode_property = confirm_mode
	slot.hold_duration_scale_property = duration_scale
	slot.hold_sustain_mode_property = sustain_mode


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _elapse makes `seconds` pass for each running gesture and lets a frame report it.
func _elapse(seconds: float) -> void:
	_set_elapsed(seconds)
	await wait_process_frames(1)


## _make_hold returns a new hold on `action`.
func _make_hold(
	mode: StdInputActionHold.Mode,
	duration: float = _DURATION,
	action: StringName = _ACTION,
) -> StdInputActionHold:
	var hold := StdInputActionHold.new()
	hold.action = action
	hold.duration = duration
	hold.mode = mode
	return hold


## _make_layer returns a new layer of `parent` declaring `holds`.
func _make_layer(
	holds: Array[StdInputActionHold], parent: StdInputActionSet
) -> StdInputActionSetLayer:
	var layer := StdInputActionSetLayer.new()
	layer.name = &"ProbeLayer"
	layer.parent = parent
	layer.holds = holds
	return layer


## _make_mode_property returns a new property at `MODE_INHERIT` in a scope of its own.
func _make_mode_property(property_name: StringName) -> StdSettingsPropertyInt:
	var property := StdSettingsPropertyInt.new()
	property.category = &"probe"
	property.name = property_name
	property.scope = StdSettingsScope.new()
	return property


## _make_set returns a new set declaring `holds` and `actions`.
func _make_set(
	holds: Array[StdInputActionHold], actions: Array[StringName] = _ACTIONS
) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = &"Probe"
	action_set.actions_digital = actions
	action_set.holds = holds
	return action_set


## _mount adds the slot to the scene with a set declaring `hold` and `others` loaded.
func _mount(hold: StdInputActionHold, others: Array[StdInputActionHold] = []) -> void:
	var holds: Array[StdInputActionHold] = [hold]
	holds.append_array(others)

	await _mount_set(_make_set(holds))


## _mount_set adds the slot to the scene with `action_set` loaded, watching its signals.
func _mount_set(action_set: StdInputActionSet) -> void:
	input = await StdTestInput.mount(self, slot)
	autofree(slot.get_active_device())

	slot.load_action_set(action_set)

	watch_signals(slot)


## _set_elapsed makes `seconds` pass for each running gesture, with no frame.
func _set_elapsed(seconds: float) -> void:
	for gesture in slot._gestures._gestures.values():
		gesture.started_usec -= int(seconds * 1_000_000)


## _swap_joypad_components swaps in a new joypad monitor, keeping the other components.
func _swap_joypad_components() -> void:
	var joypad_monitor := SlotTest.JoypadMonitor.new()
	add_child_autofree(joypad_monitor)
	slot.swap_joypad_components(
		joypad_monitor, slot.actions_joy, slot.glyphs_joy, slot.haptics_joy
	)
