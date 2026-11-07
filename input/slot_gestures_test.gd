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

const GodotJoypadMonitor := preload("godot/joypad_monitor.gd")
const SlotTest := preload("slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _ACTION is the action most tests run as a hold.
const _ACTION := &"probe_gesture"

## _ACTION_OTHER is an action declared beside `_ACTION`.
const _ACTION_OTHER := &"probe_gesture_other"

## _ACTION_STICK is an action bound to the left stick's positive horizontal axis.
const _ACTION_STICK := &"probe_gesture_stick"

## _ACTIONS lists every action this file defines.
const _ACTIONS: Array[StringName] = [_ACTION, _ACTION_OTHER, _ACTION_STICK]

## _DURATION is the `duration` of each hold, in seconds.
const _DURATION := 1.0

## _HOLD_SIGNALS lists each signal a hold can emit.
const _HOLD_SIGNALS: Array[String] = [
	"action_hold_cancelled",
	"action_hold_progress_changed",
	"action_hold_started",
	"action_hold_triggered",
]

## _MODE_RETIRED is the value of a retired mode that player settings and resources may
## still hold.
const _MODE_RETIRED := 3

## _STICK_DEADZONE is the deadzone of `_ACTION_STICK`, below the `0.5` at which a
## joypad motion reads as a press.
const _STICK_DEADZONE := 0.2

const MODE_HOLD := StdInputActionHold.MODE_HOLD
const MODE_INHERIT := StdInputActionHold.MODE_INHERIT
const MODE_TOGGLE := StdInputActionHold.MODE_TOGGLE

# -- INITIALIZATION ------------------------------------------------------------------ #

var hold_mode: StdSettingsPropertyInt = null
var input: StdTestInput = null
var slot: StdInputSlot = null

# -- TEST METHODS -------------------------------------------------------------------- #

# HOLD


func test_hold_triggers_and_ends_at_the_fill() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# When: The action is pressed.
	input.press_action(_ACTION)

	# Then: The hold is active and hasn't filled.
	assert_signal_emit_count(slot, "action_hold_started", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)
	assert_true(slot.is_action_hold_active(_ACTION))

	# When: The press lasts past the duration.
	await _elapse(_DURATION + 0.5)

	# Then: The hold triggers once and ends.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
	assert_false(slot.is_action_hold_active(_ACTION))
	assert_eq(slot.get_action_hold_progress(_ACTION), 0.0)

	# When: A frame passes while the action stays held.
	await wait_process_frames(1)

	# Then: It doesn't trigger again.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: Nothing more is reported.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)


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
	assert_false(slot.is_action_hold_active(_ACTION))


func test_hold_released_past_the_fill_before_a_frame_reports_it_triggers() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The press lasted past the duration, in a frame that hasn't ended.
	input.press_action(_ACTION)
	_set_elapsed(_DURATION + 0.5)
	assert_signal_emit_count(slot, "action_hold_triggered", 0, "precondition")

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: The hold triggers rather than cancelling.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
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


func test_hold_has_ended_when_its_trigger_is_handled() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: A handler records whether the hold reads as active as it triggers.
	var active: Array[bool] = []
	slot.action_hold_triggered.connect(
		func(action: StringName) -> void:
			active.append(slot.is_action_hold_active(action))
	)

	# When: The press lasts past the duration.
	input.press_action(_ACTION)
	await _elapse(_DURATION)

	# Then: The handler read it as no longer active.
	assert_eq(active, [false] as Array[bool])

	# Then: The progress dropped to none after the fill.
	assert_eq(get_signal_parameters(slot, "action_hold_progress_changed")[1], 0.0)


func test_hold_runs_from_a_key_as_from_any_other_press() -> void:
	# Given: A hold is declared on an action bound to a key.
	await _mount(_make_hold(MODE_HOLD))

	# When: The key is held past the duration.
	input.press_key(KEY_G)
	await _elapse(_DURATION)

	# Then: The hold triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_hold_fills_once_while_two_devices_hold_its_action() -> void:
	# Given: A hold is declared on an action bound to a key.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The monitor reports a joypad.
	_connect_joypad(1)

	# Given: The key presses the action.
	input.press_key(KEY_G)

	# Given: The joypad presses it too.
	input.send(_injected(_ACTION, 1, true))

	# When: Half the duration passes.
	await _elapse(_DURATION * 0.5)

	# Then: One hold runs, at the progress of one press.
	assert_signal_emit_count(slot, "action_hold_started", 1)
	assert_almost_eq(slot.get_action_hold_progress(_ACTION), 0.5, 0.2)

	# When: The key lets go.
	input.release_key(KEY_G)

	# Then: The joypad's press keeps the hold running.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)

	# When: The rest of the duration passes.
	await _elapse(_DURATION)

	# Then: The hold triggers once.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_hold_released_with_no_event_cancels() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The action is pressed, for less than the duration.
	input.press_action(_ACTION)
	await _elapse(_DURATION * 0.25)

	# When: `Input` reads the action as up with no event, as after a loss of focus.
	Input.action_release(_ACTION)
	await wait_process_frames(1)

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_hold_released_with_no_event_doesnt_trigger_an_unreported_fill() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The action is pressed.
	input.press_action(_ACTION)

	# Given: The duration passes with no frame to report it.
	_set_elapsed(_DURATION + 0.5)

	# When: `Input` reads the action as up with no event.
	Input.action_release(_ACTION)
	await wait_process_frames(1)

	# Then: The hold cancels without triggering.
	assert_signal_emit_count(slot, "action_hold_triggered", 0)
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)


func test_toggle_released_with_no_event_stays_active() -> void:
	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The action is pressed, which starts the toggle.
	input.press_action(_ACTION)
	assert_true(slot.is_action_hold_active(_ACTION), "precondition: active")

	# When: `Input` reads the action as up with no event.
	Input.action_release(_ACTION)
	await wait_process_frames(1)

	# Then: The toggle stays active, since it ignores its release.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)


func test_hold_is_cancelled_when_the_app_loses_focus() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The action is pressed, for less than the duration.
	input.press_action(_ACTION)
	await _elapse(_DURATION * 0.5)

	# When: The app loses focus, before Godot releases the action.
	slot.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_false(slot.is_action_hold_active(_ACTION))

	# When: Godot releases the action with no event.
	Input.action_release(_ACTION)
	await wait_process_frames(1)

	# Then: Nothing more is reported.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_toggle_is_cancelled_when_the_app_loses_focus() -> void:
	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The action was tapped, which starts the toggle.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: The app loses focus.
	slot.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)

	# Then: The toggle cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_false(slot.is_action_hold_active(_ACTION))

	# When: The duration passes.
	await _elapse(_DURATION)

	# Then: Nothing triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


# Disconnects


func test_hold_on_a_lost_joypad_cancels_on_the_release_steam_sends() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The monitor reports a joypad.
	_connect_joypad(1)

	# Given: The joypad has pressed the action, for less than the duration.
	input.send(_injected(_ACTION, 1, true))
	await _elapse(_DURATION * 0.5)

	# When: The joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(1)

	# Then: The hold waits for the joypad's release.
	assert_true(slot.is_action_hold_active(_ACTION))

	# When: The release arrives as an event, as Steam sends it for a lost joypad.
	input.send(_injected(_ACTION, 1, false))

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_hold_on_a_joypad_godot_loses_cancels() -> void:
	# Given: The slot hears of joypads from Godot's monitor.
	_use_godot_joypad_monitor()

	# Given: A hold is declared on an action bound to a stick.
	await _mount(_make_hold(MODE_HOLD, _DURATION, _ACTION_STICK))

	# Given: The monitor reports a joypad.
	_connect_joypad(1)

	# Given: The stick holds the action between its deadzone and `0.5`.
	input.send(_stick(1, 0.3))

	# Given: Half the duration passes.
	await _elapse(_DURATION * 0.5)

	# When: Godot loses the joypad, which clears `Input` with no event.
	#
	# NOTE: A headless run has no joypad to disconnect, so its effects are stood in for.
	Input.action_release(_ACTION_STICK)

	# When: Another joypad's stick reports at rest before Godot reports the loss.
	input.send(_stick(2, 0.0))

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)

	# When: Godot reports the loss.
	Input.joy_connection_changed.emit(1, false)

	# Then: Nothing more is reported.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)


func test_hold_survives_another_joypad_disconnecting() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The monitor reports two joypads.
	_connect_joypad(1)
	_connect_joypad(2)

	# Given: The first joypad has pressed the action, for less than the duration.
	input.send(_injected(_ACTION, 1, true))
	await _elapse(_DURATION * 0.5)

	# When: The idle joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(2)

	# Then: The hold keeps running.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)

	# When: The rest of the duration passes.
	await _elapse(_DURATION)

	# Then: The hold triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_hold_from_a_key_survives_a_joypad_disconnecting() -> void:
	# Given: A hold is declared on an action bound to a key.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The monitor reports joypad `0`.
	_connect_joypad(0)

	# Given: The key has pressed the action, for less than the duration.
	input.press_key(KEY_G)
	await _elapse(_DURATION * 0.5)

	# When: The joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(0)

	# Then: The hold keeps running.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)

	# When: The rest of the duration passes.
	await _elapse(_DURATION)

	# Then: The hold triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_hold_from_a_key_survives_a_joypad_holding_it_disconnecting() -> void:
	# Given: A hold is declared on an action bound to a key.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The monitor reports a joypad.
	_connect_joypad(1)

	# Given: The key presses the action.
	input.press_key(KEY_G)

	# Given: The joypad presses it too, for less than the duration.
	input.send(_injected(_ACTION, 1, true))
	await _elapse(_DURATION * 0.5)

	# When: The joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(1)

	# When: Its release arrives as an event, as Steam sends it for a lost joypad.
	input.send(_injected(_ACTION, 1, false))

	# Then: The key's press keeps the hold running.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)

	# When: The rest of the duration passes.
	await _elapse(_DURATION)

	# Then: The hold triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_hold_handed_to_a_second_joypad_cancels_on_its_lost_release() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The monitor reports two joypads.
	_connect_joypad(1)
	_connect_joypad(2)

	# Given: The first joypad presses the action.
	input.send(_injected(_ACTION, 1, true))

	# Given: The second joypad presses it too.
	input.send(_injected(_ACTION, 2, true))

	# Given: The first joypad lets go.
	input.send(_injected(_ACTION, 1, false))
	assert_true(slot.is_action_hold_active(_ACTION), "precondition: active")

	# Given: Less than the duration has passed.
	await _elapse(_DURATION * 0.5)

	# When: The second joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(2)

	# When: Its release arrives as an event, as Steam sends it for a lost joypad.
	input.send(_injected(_ACTION, 2, false))

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_hold_handed_to_a_second_joypad_survives_the_first_disconnecting() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The monitor reports two joypads.
	_connect_joypad(1)
	_connect_joypad(2)

	# Given: The first joypad presses the action.
	input.send(_injected(_ACTION, 1, true))

	# Given: The second joypad presses it too.
	input.send(_injected(_ACTION, 2, true))

	# Given: The first joypad lets go.
	input.send(_injected(_ACTION, 1, false))

	# Given: Less than the duration has passed.
	await _elapse(_DURATION * 0.5)

	# When: The first joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(1)

	# Then: The hold keeps running.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)

	# When: The rest of the duration passes.
	await _elapse(_DURATION)

	# Then: The hold triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_toggle_is_cancelled_only_when_its_own_joypad_disconnects() -> void:
	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The monitor reports two joypads.
	_connect_joypad(1)
	_connect_joypad(2)

	# Given: The first joypad taps the action, which starts the toggle.
	input.send(_injected(_ACTION, 1, true))
	input.send(_injected(_ACTION, 1, false))

	# When: The other joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(2)

	# Then: The toggle goes on.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)

	# When: The toggle's joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(1)

	# Then: The toggle cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_false(slot.is_action_hold_active(_ACTION))

	# When: The duration passes.
	await _elapse(_DURATION)

	# Then: Nothing triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_toggle_survives_another_joypad_holding_it_disconnecting() -> void:
	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The monitor reports two joypads.
	_connect_joypad(1)
	_connect_joypad(2)

	# Given: The first joypad presses the action, which starts the toggle.
	input.send(_injected(_ACTION, 1, true))

	# Given: The second joypad presses it too.
	input.send(_injected(_ACTION, 2, true))

	# Given: The first joypad lets go.
	input.send(_injected(_ACTION, 1, false))

	# When: The second joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(2)

	# When: Its release arrives as an event, as Steam sends it for a lost joypad.
	input.send(_injected(_ACTION, 2, false))

	# Then: The toggle goes on, since the joypad which started it is connected.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)


func test_toggle_from_a_key_survives_joypad_zero_disconnecting() -> void:
	# Given: A toggle is declared on an action bound to a key.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The monitor reports joypad `0`.
	_connect_joypad(0)

	# Given: The key taps the action, which starts the toggle.
	input.press_key(KEY_G)
	input.release_key(KEY_G)

	# When: The joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(0)

	# Then: The toggle goes on.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)


func test_toggle_from_a_synthetic_action_survives_joypad_zero_disconnecting() -> void:
	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The monitor reports joypad `0`.
	_connect_joypad(0)

	# Given: A synthetic action taps the action, as `StdInputEvent.trigger_action` does.
	input.send(_injected(_ACTION, StdInputEvent.DEVICE_ID_SYNTHETIC, true))
	input.send(_injected(_ACTION, StdInputEvent.DEVICE_ID_SYNTHETIC, false))

	# When: The joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(0)

	# Then: The toggle goes on.
	assert_true(slot.is_action_hold_active(_ACTION))
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)


# TOGGLE


func test_toggle_triggers_on_its_own_after_a_tap() -> void:
	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# When: The action is tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# Then: The hold stays active past the release.
	assert_signal_emit_count(slot, "action_hold_started", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_true(slot.is_action_hold_active(_ACTION))

	# When: The duration passes.
	await _elapse(_DURATION + 0.5)

	# Then: The hold triggers and ends.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_toggle_runs_while_the_slot_holds_nothing() -> void:
	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# Given: Frames have passed since the tap.
	await wait_process_frames(2)
	assert_eq(slot.get_action_held_seconds(_ACTION), 0.0, "precondition: not held")

	# When: The duration passes.
	await _elapse(_DURATION)

	# Then: The slot was still processing, so the hold triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_toggle_second_tap_cancels() -> void:
	# Given: A toggle is declared.
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

	# When: The tap is released.
	input.release_action(_ACTION)

	# When: The duration passes.
	await _elapse(_DURATION)

	# Then: Nothing triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_toggle_press_of_another_action_leaves_it_running() -> void:
	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: Another action is pressed.
	input.press_action(_ACTION_OTHER)

	# Then: The toggle goes on, since only a second tap of its own action cancels it.
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_true(slot.is_action_hold_active(_ACTION))


func test_toggle_tap_after_triggering_starts_again() -> void:
	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The action's toggle has triggered.
	input.press_action(_ACTION)
	input.release_action(_ACTION)
	await _elapse(_DURATION)
	assert_signal_emit_count(slot, "action_hold_triggered", 1, "precondition")

	# When: The action is tapped again.
	input.press_action(_ACTION)

	# Then: A new hold starts.
	assert_signal_emit_count(slot, "action_hold_started", 2)
	assert_true(slot.is_action_hold_active(_ACTION))


func test_toggle_tapped_past_its_fill_before_a_frame_reports_it_triggers() -> void:
	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# Given: The duration has passed, in a frame that hasn't ended.
	_set_elapsed(_DURATION + 0.5)
	assert_signal_emit_count(slot, "action_hold_triggered", 0, "precondition")

	# When: The action is tapped again.
	input.press_action(_ACTION)

	# Then: The toggle triggers rather than cancelling.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)

	# Then: The tap starts a new toggle.
	assert_signal_emit_count(slot, "action_hold_started", 2)
	assert_true(slot.is_action_hold_active(_ACTION))


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


func test_mode_slots_property_beats_the_holds_own_mode() -> void:
	# Given: A hold's own mode.
	await _mount(_make_hold(MODE_HOLD))

	# When: The player chooses a mode for every hold.
	hold_mode.set_value(MODE_TOGGLE)

	# Then: The player's choice decides.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)


func test_mode_override_beats_the_slots_property() -> void:
	# Given: A hold with a mode override.
	var hold := _make_hold(MODE_TOGGLE)
	hold.mode_override = _make_mode_property(&"override")
	await _mount(hold)

	# Given: The player chose a mode for every hold.
	hold_mode.set_value(MODE_TOGGLE)

	# When: The player chooses another for this hold's group.
	hold.mode_override.set_value(MODE_HOLD)

	# Then: The override decides.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_HOLD)


func test_mode_override_at_inherit_defers_to_the_slots_property() -> void:
	# Given: A hold with a mode override left at `MODE_INHERIT`.
	var hold := _make_hold(MODE_HOLD)
	hold.mode_override = _make_mode_property(&"override")
	await _mount(hold)

	# When: The player chooses a mode for every hold.
	hold_mode.set_value(MODE_TOGGLE)

	# Then: The slot's property decides.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)


func test_mode_stored_value_that_is_no_mode_defers_to_the_next_source() -> void:
	# Given: A hold's own mode.
	await _mount(_make_hold(MODE_TOGGLE))

	# When: The player's settings store something that's no mode.
	hold_mode.set_value(99)

	# Then: The hold's own mode runs.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)


func test_mode_stored_retired_value_defers_to_the_next_source() -> void:
	# Given: A hold's own mode.
	await _mount(_make_hold(MODE_TOGGLE))

	# When: The player's settings store the retired mode.
	hold_mode.set_value(_MODE_RETIRED)

	# Then: The hold's own mode runs.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)


func test_mode_holds_own_retired_value_runs_as_hold() -> void:
	# Given: A hold whose own mode stores the retired mode, as a saved resource can.
	var hold := _make_hold(MODE_TOGGLE)
	hold.set(&"mode", _MODE_RETIRED)
	await _mount(hold)

	# Then: It resolves to a hold.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_HOLD)

	# When: The action is pressed.
	input.press_action(_ACTION)

	# Then: A press doesn't skip the duration.
	assert_signal_emit_count(slot, "action_hold_triggered", 0)
	assert_true(slot.is_action_hold_active(_ACTION))

	# When: The press lasts past the duration.
	await _elapse(_DURATION)

	# Then: The hold triggers.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


func test_mode_reads_as_inherit_for_an_action_that_is_no_hold() -> void:
	# Given: An action no hold names.
	await _mount(_make_hold(MODE_HOLD))

	# Then: It reads as making no choice, with nothing to run.
	assert_null(slot.get_action_hold(_ACTION_OTHER))
	assert_eq(slot.get_action_hold_mode(_ACTION_OTHER), MODE_INHERIT)
	assert_eq(slot.get_action_hold_progress(_ACTION_OTHER), 0.0)
	assert_false(slot.is_action_hold_active(_ACTION_OTHER))


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
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_INHERIT)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_slot_without_properties_runs_each_holds_own_mode() -> void:
	# Given: A slot which wires no settings property.
	slot.hold_mode_property = null

	# Given: A toggle is declared.
	await _mount(_make_hold(MODE_TOGGLE))

	# When: The action is tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: The duration passes.
	await _elapse(_DURATION)

	# Then: The hold ran in its own mode.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)
	assert_signal_emit_count(slot, "action_hold_triggered", 1)


# Setting changes


func test_setting_change_mid_gesture_cancels() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: The player changes the mode.
	hold_mode.set_value(MODE_TOGGLE)

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_false(slot.is_action_hold_active(_ACTION))

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: Nothing more is reported.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


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


func test_setting_change_that_leaves_the_gesture_alone_keeps_it() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: The player chooses the mode the hold already runs in.
	hold_mode.set_value(MODE_HOLD)

	# Then: The hold goes on.
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_true(slot.is_action_hold_active(_ACTION))


func test_setting_property_assigned_after_ready_is_used() -> void:
	# Given: A hold is declared on a slot that's ready.
	await _mount(_make_hold(MODE_HOLD))

	# Given: A property holding the toggle.
	var property := _make_mode_property(&"late")
	property.set_value(MODE_TOGGLE)

	# When: A game's script assigns it, as an ancestor's `_ready` does.
	slot.hold_mode_property = property

	# Then: The property decides the mode.
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_TOGGLE)

	# When: The action is tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# Then: The hold runs as a toggle, which outlasts the release.
	assert_true(slot.is_action_hold_active(_ACTION))


func test_setting_property_assigned_mid_gesture_cancels() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The action is held.
	input.press_action(_ACTION)

	# Given: A property holding the toggle.
	var property := _make_mode_property(&"late")
	property.set_value(MODE_TOGGLE)

	# When: A game's script assigns it.
	slot.hold_mode_property = property

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_false(slot.is_action_hold_active(_ACTION))

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: Nothing more is reported.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_setting_property_replaced_is_no_longer_heard() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: A game's script replaced the mode property.
	slot.hold_mode_property = _make_mode_property(&"late")

	# Given: The action is held.
	input.press_action(_ACTION)

	# When: The replaced property changes.
	hold_mode.set_value(MODE_TOGGLE)

	# Then: The hold goes on in its mode.
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)
	assert_eq(slot.get_action_hold_mode(_ACTION), MODE_HOLD)


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


func test_layer_disabled_past_the_fill_before_a_frame_reports_it_cancels() -> void:
	# Given: A layer declaring a hold.
	var action_set := _make_set([])
	var layer := _make_layer([_make_hold(MODE_HOLD)], action_set)
	await _mount_set(action_set)
	slot.enable_action_set_layer(layer)

	# Given: The press lasted past the duration, in a frame that hasn't ended.
	input.press_action(_ACTION)
	_set_elapsed(_DURATION + 0.5)

	# When: The layer is disabled, as when a menu opens.
	slot.disable_action_set_layer(layer)

	# Then: The hold cancels rather than triggering.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


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


func test_set_change_dropping_a_hold_past_its_unreported_fill_cancels() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The press lasted past the duration, in a frame that hasn't ended.
	input.press_action(_ACTION)
	_set_elapsed(_DURATION + 0.5)

	# When: A set without the hold or its action is loaded.
	slot.load_action_set(_make_set([], [_ACTION_OTHER]))

	# Then: The hold cancels rather than triggering, though the slot releases the action.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_set_change_cancels_an_active_toggle() -> void:
	# Given: A toggle is running.
	await _mount(_make_hold(MODE_TOGGLE))
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
		[_make_hold(MODE_TOGGLE, _DURATION, _ACTION_OTHER)], [_ACTION_OTHER]
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


func test_set_loaded_by_a_started_listener_cancels_the_hold_it_starts() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: A listener loads a set dropping the hold as it starts.
	slot.action_hold_started.connect(
		func(_action: StringName) -> void: slot.load_action_set(_make_set([])),
		CONNECT_ONE_SHOT,
	)

	# When: The action is pressed.
	input.press_action(_ACTION)

	# Then: The hold cancels without reporting progress or triggering.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_progress_changed", 0)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_set_loaded_by_a_progress_listener_stops_the_trigger() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The press lasted past the duration, in a frame that hasn't ended.
	input.press_action(_ACTION)
	_set_elapsed(_DURATION + 0.5)

	# Given: A listener loads a set dropping the hold as its progress changes.
	slot.action_hold_progress_changed.connect(
		func(_action: StringName, _progress: float) -> void:
			slot.load_action_set(_make_set([])),
		CONNECT_ONE_SHOT,
	)

	# When: A frame reports the fill.
	await wait_process_frames(1)

	# Then: The hold cancels without triggering.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_set_loaded_by_a_trigger_listener_leaves_the_hold_triggered() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: A listener loads a set dropping the hold as it triggers.
	slot.action_hold_triggered.connect(
		func(_action: StringName) -> void: slot.load_action_set(_make_set([])),
		CONNECT_ONE_SHOT,
	)

	# When: The press lasts past the duration.
	input.press_action(_ACTION)
	await _elapse(_DURATION)

	# Then: The hold triggers once, and doesn't also cancel.
	assert_signal_emit_count(slot, "action_hold_triggered", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 0)


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


func test_swap_cancels_a_hold_past_its_unreported_fill() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The press lasted past the duration, in a frame that hasn't ended.
	input.press_action(_ACTION)
	_set_elapsed(_DURATION + 0.5)

	# When: The joypad components are swapped.
	_swap_joypad_components()

	# Then: The hold cancels rather than triggering, though the slot releases the action.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


func test_swap_cancels_an_active_toggle() -> void:
	# Given: A toggle is running, with nothing held.
	await _mount(_make_hold(MODE_TOGGLE))
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: The joypad components are swapped.
	_swap_joypad_components()

	# Then: The hold cancels.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_false(slot.is_action_hold_active(_ACTION))


func test_leaving_the_tree_cancels_a_hold_past_its_unreported_fill() -> void:
	# Given: A hold is declared.
	await _mount(_make_hold(MODE_HOLD))

	# Given: The press lasted past the duration, in a frame that hasn't ended.
	input.press_action(_ACTION)
	_set_elapsed(_DURATION + 0.5)

	# When: The slot leaves the tree.
	slot.get_parent().remove_child(slot)
	autofree(slot)

	# Then: The hold cancels rather than triggering.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1)
	assert_signal_emit_count(slot, "action_hold_triggered", 0)


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
	# Given: A toggle has triggered, with nothing held.
	await _mount(_make_hold(MODE_TOGGLE))
	input.press_action(_ACTION)
	input.release_action(_ACTION)
	await _elapse(_DURATION)
	assert_signal_emit_count(slot, "action_hold_triggered", 1, "precondition")

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

	# NOTE: A binding's device of `-1` matches every device.
	InputMap.action_add_event(_ACTION_STICK, _stick(-1, 1.0))
	InputMap.action_set_deadzone(_ACTION_STICK, _STICK_DEADZONE)


func before_each() -> void:
	hold_mode = _make_mode_property(&"mode")

	slot = SlotTest.make_slot()
	slot.hold_mode_property = hold_mode


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _connect_joypad has the slot's monitor report joypad `device`. Its node is freed with
## the test, since a disconnect only queues it for freeing.
func _connect_joypad(device: int) -> void:
	slot.joypad_monitor.joy_connected.emit(device, StdInputDevice.DEVICE_TYPE_GENERIC)
	autofree(slot.get_connected_devices(false).back())


## _elapse makes `seconds` pass for each running gesture and lets a frame report it.
func _elapse(seconds: float) -> void:
	_set_elapsed(seconds)
	await wait_process_frames(1)


## _injected returns a press of `action` on `device`, or its release when `pressed` is
## `false`, as the Steam actions component publishes one.
func _injected(action: StringName, device: int, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.device = device
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	return event


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


## _stick returns a motion of `device`'s left stick along its horizontal axis to
## `value`.
func _stick(device: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event


## _swap_joypad_components swaps in a new joypad monitor, keeping the other components.
func _swap_joypad_components() -> void:
	var joypad_monitor := SlotTest.JoypadMonitor.new()
	add_child_autofree(joypad_monitor)
	slot.swap_joypad_components(
		joypad_monitor, slot.actions_joy, slot.glyphs_joy, slot.haptics_joy
	)


## _use_godot_joypad_monitor replaces the slot's fake monitor with Godot's, which hears
## of a disconnect from `Input` after the slot's held actions do, as in a game's scene.
func _use_godot_joypad_monitor() -> void:
	var fake := slot.joypad_monitor
	slot.remove_child(fake)
	fake.free()

	slot.joypad_monitor = GodotJoypadMonitor.new()
	slot.add_child(slot.joypad_monitor)
