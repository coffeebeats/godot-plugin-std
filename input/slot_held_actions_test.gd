# gdlint:ignore=max-public-methods
# gdlint:disable=max-file-lines
##
## std/input/slot_held_actions_test.gd
##
## Tests pertaining to how a `StdInputSlot` times held actions, driven through the
## `Input` singleton and real frames, as the engine does.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _TEST_ACTION is an action bound to `_TEST_KEY`, `_TEST_KEY_ALTERNATE` and a joypad
## button.
const _TEST_ACTION := &"probe_held_action"

## _TEST_AXIS_ACTION is an action bound to the left stick's positive horizontal axis.
const _TEST_AXIS_ACTION := &"probe_held_axis"

## _TEST_DEADZONE is the deadzone of the test actions.
const _TEST_DEADZONE := 0.5

## _TEST_KEY is a key bound to `_TEST_ACTION`.
const _TEST_KEY := KEY_T

## _TEST_KEY_ALTERNATE is a second key bound to `_TEST_ACTION`.
const _TEST_KEY_ALTERNATE := KEY_Y

## _TEST_KEY_SHARED is the key bound to both `_TEST_SHARED_ACTION_A` and
## `_TEST_SHARED_ACTION_B`.
const _TEST_KEY_SHARED := KEY_U

## _TEST_MOUSE_ACTION is an action bound to the left mouse button.
const _TEST_MOUSE_ACTION := &"probe_held_mouse"

## _TEST_SHARED_ACTION_A is the first action bound to `_TEST_KEY_SHARED`.
const _TEST_SHARED_ACTION_A := &"probe_held_shared_a"

## _TEST_SHARED_ACTION_B is the second action bound to `_TEST_KEY_SHARED`.
const _TEST_SHARED_ACTION_B := &"probe_held_shared_b"

## _TEST_TRIGGER_ACTION is an action bound to the right trigger, whose deadzone sits
## below the `0.5` at which a joypad motion event reads as pressed.
const _TEST_TRIGGER_ACTION := &"probe_held_trigger"

## _TEST_TRIGGER_DEADZONE is the deadzone of `_TEST_TRIGGER_ACTION`.
const _TEST_TRIGGER_DEADZONE := 0.2

## _TEST_UNMAPPED_ACTION is an action the `InputMap` doesn't define.
const _TEST_UNMAPPED_ACTION := &"probe_held_unmapped"


## ReleaseSwallower marks every release as handled, as an upstream `_input` can. It runs
## before any node earlier in the tree, since `_input` runs in reverse tree order.
class ReleaseSwallower:
	extends Node

	func _input(event: InputEvent) -> void:
		if event.is_action_type() and not event.is_pressed():
			get_viewport().set_input_as_handled()


# -- INITIALIZATION ------------------------------------------------------------------ #

var input: StdTestInput = null
var slot: StdInputSlot = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_slot_key_and_pad_on_one_action_count_as_one_hold() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The action bound to the key and the joypad button is active.
	_load_actions([_TEST_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The key is pressed.
	await _dispatch(_key(true))

	# Then: The hold starts on the keyboard.
	assert_signal_emitted_with_parameters(
		slot, "action_pressed", [_TEST_ACTION, InputEvent.DEVICE_ID_KEYBOARD]
	)

	# When: The joypad button is pressed while the key is held.
	await _dispatch(_button(true))

	# Then: The hold isn't started again.
	assert_signal_emit_count(slot, "action_pressed", 1)

	# When: The key is released while the joypad button is held.
	await _dispatch(_key(false))

	# Then: The hold continues.
	assert_signal_emit_count(slot, "action_released", 0)
	assert_gt(slot.get_action_held_seconds(_TEST_ACTION), 0.0)

	# When: The joypad button is released.
	await _dispatch(_button(false))

	# Then: The hold ends once, on the joypad.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_eq(get_signal_parameters(slot, "action_released")[1], 0)

	# Then: The held time resets.
	assert_eq(slot.get_action_held_seconds(_TEST_ACTION), 0.0)


func test_input_slot_two_keys_on_one_action_count_as_one_hold() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The action bound to both keys is active.
	_load_actions([_TEST_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The first key is held.
	await _dispatch(_key(true))

	# Given: The second key is held.
	await _dispatch(_key(true, _TEST_KEY_ALTERNATE))

	# When: The first key is released.
	await _dispatch(_key(false))

	# Then: The hold continues.
	assert_signal_emit_count(slot, "action_released", 0)

	# When: The second key is released.
	await _dispatch(_key(false, _TEST_KEY_ALTERNATE))

	# Then: The hold ends once.
	assert_signal_emit_count(slot, "action_released", 1)


func test_input_slot_action_released_reports_the_seconds_held() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	_load_actions([_TEST_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The key is held.
	await _dispatch(_key(true))

	# When: A second and a half passes.
	slot._held_actions._held_since[_TEST_ACTION] -= 1_500_000

	# Then: The held time reports it.
	assert_almost_eq(slot.get_action_held_seconds(_TEST_ACTION), 1.5, 0.5)

	# When: The key is released.
	await _dispatch(_key(false))

	# Then: The release reports it too.
	assert_almost_eq(get_signal_parameters(slot, "action_released")[2], 1.5, 0.5)


func test_input_slot_swap_releases_held_action_and_resets_held_time() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The joypad button's action is active.
	_load_actions([_TEST_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The joypad button is held.
	await _dispatch(_button(true))
	assert_gt(slot.get_action_held_seconds(_TEST_ACTION), 0.0, "precondition: held")

	# When: The joypad components are swapped.
	var joypad_monitor := SlotTest.JoypadMonitor.new()
	add_child_autofree(joypad_monitor)
	slot.swap_joypad_components(
		joypad_monitor, slot.actions_joy, slot.glyphs_joy, slot.haptics_joy
	)

	# Then: The hold ends on the joypad.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_eq(get_signal_parameters(slot, "action_released")[1], 0)

	# Then: The held time resets.
	assert_eq(slot.get_action_held_seconds(_TEST_ACTION), 0.0)


func test_input_slot_release_swallowed_upstream_is_caught_by_backstop() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	_load_actions([_TEST_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The key is held.
	await _dispatch(_key(true))

	# Given: A node which runs before the slot swallows every release.
	add_child_autofree(ReleaseSwallower.new())

	# When: The key is released.
	input.send(_key(false))

	# Then: The slot hasn't seen the release.
	assert_false(Input.is_action_pressed(_TEST_ACTION), "precondition: released")
	assert_signal_emit_count(slot, "action_released", 0, "precondition: hidden")

	# When: A frame passes.
	await wait_process_frames(1)

	# Then: The hold ends on the keyboard.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_eq(
		get_signal_parameters(slot, "action_released")[1],
		InputEvent.DEVICE_ID_KEYBOARD,
	)

	# Then: The held time resets.
	assert_eq(slot.get_action_held_seconds(_TEST_ACTION), 0.0)


func test_input_slot_action_released_without_an_event_is_caught_by_backstop() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The joypad button's action is active.
	_load_actions([_TEST_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The joypad button is held.
	await _dispatch(_button(true))

	# When: `Input` drops the action with no event, as when the joypad disconnects.
	Input.action_release(_TEST_ACTION)
	await wait_process_frames(1)

	# Then: The hold ends on the joypad.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_eq(get_signal_parameters(slot, "action_released")[1], 0)


func test_input_slot_backstop_runs_only_while_an_action_is_tracked() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	_load_actions([_TEST_ACTION])

	# Then: The slot isn't processing.
	assert_false(slot._held_actions.is_processing())

	# When: The key is pressed.
	await _dispatch(_key(true))

	# Then: The slot is processing.
	assert_true(slot._held_actions.is_processing())

	# When: The key is released.
	await _dispatch(_key(false))

	# Then: The slot isn't processing.
	assert_false(slot._held_actions.is_processing())


func test_input_slot_action_pressed_below_the_activation_threshold_is_tracked() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The trigger's action is active.
	_load_actions([_TEST_TRIGGER_ACTION])

	# When: The trigger is pressed past its deadzone, but below `is_pressed`'s `0.5`.
	await _dispatch(_stick(JOY_AXIS_TRIGGER_RIGHT, 0.3))

	# Then: The action is held, as `Input` reports it.
	assert_true(Input.is_action_pressed(_TEST_TRIGGER_ACTION), "precondition: pressed")
	assert_gt(slot.get_action_held_seconds(_TEST_TRIGGER_ACTION), 0.0)

	# Then: The keyboard stays active.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# When: The trigger returns inside its deadzone.
	await _dispatch(_stick(JOY_AXIS_TRIGGER_RIGHT, 0.1))

	# Then: The held time resets.
	assert_eq(slot.get_action_held_seconds(_TEST_TRIGGER_ACTION), 0.0)


func test_input_slot_synthetic_press_is_held_until_its_release() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The action is active.
	_load_actions([_TEST_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: A button triggers the action.
	StdInputEvent.trigger_action(_TEST_ACTION)
	await wait_process_frames(2)

	# Then: The hold starts on the synthetic device.
	assert_signal_emitted_with_parameters(
		slot, "action_pressed", [_TEST_ACTION, StdInputEvent.DEVICE_ID_SYNTHETIC]
	)

	# Then: The hold survives the backstop.
	assert_signal_emit_count(slot, "action_released", 0)
	assert_gt(slot.get_action_held_seconds(_TEST_ACTION), 0.0)

	# When: The button releases the action.
	StdInputEvent.trigger_action(_TEST_ACTION, StdInputEvent.DEVICE_ID_SYNTHETIC, false)
	await wait_process_frames(2)

	# Then: The hold ends.
	assert_signal_emit_count(slot, "action_released", 1)


func test_input_slot_action_missing_from_input_map_ends_on_its_release() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: An action the `InputMap` doesn't define is active, as Steam can publish.
	_load_actions([_TEST_UNMAPPED_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The joypad presses the action.
	StdInputEvent.trigger_action(_TEST_UNMAPPED_ACTION, 0)
	await wait_process_frames(3)

	# Then: The backstop leaves the hold alone.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_signal_emit_count(slot, "action_released", 0)

	# When: The joypad releases the action.
	StdInputEvent.trigger_action(_TEST_UNMAPPED_ACTION, 0, false)
	await wait_process_frames(2)

	# Then: The hold ends.
	assert_signal_emit_count(slot, "action_released", 1)


func test_input_slot_action_set_change_releases_only_dropped_actions() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: A set declaring the key's and the stick's actions is loaded.
	_load_actions([_TEST_ACTION, _TEST_AXIS_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The key is held.
	await _dispatch(_key(true))

	# Given: The stick is held.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 1.0))

	# When: A set declaring only the stick's action is loaded.
	_load_actions([_TEST_AXIS_ACTION])

	# Then: Only the dropped action's hold ends.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_eq(get_signal_parameters(slot, "action_released")[0], _TEST_ACTION)
	assert_eq(slot.get_action_held_seconds(_TEST_ACTION), 0.0)
	assert_gt(slot.get_action_held_seconds(_TEST_AXIS_ACTION), 0.0)


func test_input_slot_unclaimed_keyboard_holds_nothing() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	_load_actions([_TEST_ACTION])

	# Given: The slot gives up the keyboard and mouse.
	slot.claim_kbm_input = false

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The key is pressed.
	await _dispatch(_key(true))

	# Then: No hold starts.
	assert_signal_emit_count(slot, "action_pressed", 0)
	assert_eq(slot.get_action_held_seconds(_TEST_ACTION), 0.0)


func test_input_slot_action_pressed_reads_the_device_it_activated() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The joypad button's action is active.
	_load_actions([_TEST_ACTION])

	# Given: A listener records the active device's type at each press.
	var types: Array[int] = []
	slot.action_pressed.connect(func(_action, _device): types.append(_active_type()))

	# When: The joypad button is pressed.
	await _dispatch(_button(true))

	# Then: The listener read the joypad.
	assert_eq(types, [StdInputDevice.DEVICE_TYPE_GENERIC] as Array[int])


func test_input_slot_leaving_the_tree_releases_held_actions() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	_load_actions([_TEST_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The key is held.
	await _dispatch(_key(true))

	# When: The slot leaves the tree.
	slot.get_parent().remove_child(slot)
	autofree(slot)

	# Then: The hold ends.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_eq(slot.get_action_held_seconds(_TEST_ACTION), 0.0)


func test_input_slot_times_a_hold_while_the_tree_is_paused() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	_load_actions([_TEST_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The tree is paused, as behind a pause menu.
	get_tree().paused = true

	# When: The key is pressed.
	input.send(_key(true))

	# Then: The hold starts.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_true(_is_tracked(_TEST_ACTION))

	# When: The key is released.
	input.send(_key(false))

	# Then: The hold ends.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_false(_is_tracked(_TEST_ACTION))


func test_input_slot_backstop_runs_while_the_tree_is_paused() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	_load_actions([_TEST_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The key is held.
	await _dispatch(_key(true))

	# Given: The tree is paused, as behind a pause menu.
	get_tree().paused = true

	# When: `Input` drops the action with no event, as when the window loses focus.
	Input.action_release(_TEST_ACTION)

	# When: A frame passes.
	await wait_process_frames(1)

	# Then: The hold ends.
	assert_signal_emit_count(slot, "action_released", 1)


func test_input_slot_mouse_button_holds_when_claimed() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The mouse button's action is active.
	_load_actions([_TEST_MOUSE_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The mouse button is pressed.
	input.press_mouse()

	# Then: The hold starts on the mouse.
	assert_signal_emitted_with_parameters(
		slot, "action_pressed", [_TEST_MOUSE_ACTION, InputEvent.DEVICE_ID_MOUSE]
	)

	# When: The mouse button is released.
	input.release_mouse()

	# Then: The hold ends.
	assert_signal_emit_count(slot, "action_released", 1)


func test_input_slot_unclaimed_mouse_button_holds_nothing() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The mouse button's action is active.
	_load_actions([_TEST_MOUSE_ACTION])

	# Given: The slot gives up the keyboard and mouse.
	slot.claim_kbm_input = false

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The mouse button is pressed.
	input.press_mouse()

	# Then: No hold starts.
	assert_signal_emit_count(slot, "action_pressed", 0)
	assert_eq(slot.get_action_held_seconds(_TEST_MOUSE_ACTION), 0.0)


func test_input_slot_absolute_mouse_action_activates_without_holding() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: A set declaring an absolute mouse action is loaded.
	var action_set := _make_set([_TEST_ACTION])
	action_set.action_absolute_mouse = _TEST_UNMAPPED_ACTION
	slot.load_action_set(action_set)

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The joypad publishes the absolute mouse action.
	StdInputEvent.trigger_action(_TEST_UNMAPPED_ACTION, 0)
	await wait_process_frames(2)

	# Then: The joypad is active.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_GENERIC)

	# Then: No hold starts.
	assert_signal_emit_count(slot, "action_pressed", 0)
	assert_false(_is_tracked(_TEST_UNMAPPED_ACTION))

	# Then: Nothing is left to poll.
	assert_false(slot._held_actions.is_processing())


func test_input_slot_action_missing_from_input_map_ends_on_the_last_release() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: An action the `InputMap` doesn't define is active.
	_load_actions([_TEST_UNMAPPED_ACTION])

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The first device presses the action.
	StdInputEvent.trigger_action(_TEST_UNMAPPED_ACTION, 0)

	# Given: The second device presses the action.
	StdInputEvent.trigger_action(_TEST_UNMAPPED_ACTION, 1)
	await wait_process_frames(2)

	# When: The second device releases the action.
	StdInputEvent.trigger_action(_TEST_UNMAPPED_ACTION, 1, false)
	await wait_process_frames(2)

	# Then: The hold continues.
	assert_signal_emit_count(slot, "action_released", 0)
	assert_true(_is_tracked(_TEST_UNMAPPED_ACTION))

	# When: The first device releases the action.
	StdInputEvent.trigger_action(_TEST_UNMAPPED_ACTION, 0, false)
	await wait_process_frames(2)

	# Then: The hold ends once.
	assert_signal_emit_count(slot, "action_released", 1)


func test_input_slot_swap_blocks_a_held_stick_until_it_is_released() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The stick's action is active.
	_load_actions([_TEST_AXIS_ACTION])

	# Given: The stick is held.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 1.0))

	# Given: The joypad components are swapped.
	_swap_joypad_components()

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The still-held stick reports motion.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 0.9))

	# Then: No hold starts.
	assert_signal_emit_count(slot, "action_pressed", 0)
	assert_eq(slot.get_action_held_seconds(_TEST_AXIS_ACTION), 0.0)

	# When: The stick returns inside the deadzone.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 0.1))

	# When: The stick is pushed again.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 1.0))

	# Then: A hold starts.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_gt(slot.get_action_held_seconds(_TEST_AXIS_ACTION), 0.0)


func test_input_slot_swap_blocks_a_held_trigger_below_the_activation_threshold(
) -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The trigger's action is active.
	_load_actions([_TEST_TRIGGER_ACTION])

	# Given: The trigger is held past its deadzone, but below `is_pressed`'s `0.5`.
	await _dispatch(_stick(JOY_AXIS_TRIGGER_RIGHT, 0.3))

	# Given: The joypad components are swapped.
	_swap_joypad_components()

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The still-held trigger reports motion.
	await _dispatch(_stick(JOY_AXIS_TRIGGER_RIGHT, 0.35))

	# Then: No hold starts.
	assert_signal_emit_count(slot, "action_pressed", 0)


func test_input_slot_injected_repeat_after_swap_starts_no_hold() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The action is active.
	_load_actions([_TEST_ACTION])

	# Given: The joypad presses the injected action, as Steam publishes it.
	StdInputEvent.trigger_action(_TEST_ACTION, 0)
	await wait_process_frames(2)

	# Given: The joypad components are swapped.
	_swap_joypad_components()

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The action is published again, as Steam does when its strength changes.
	StdInputEvent.trigger_action(_TEST_ACTION, 0)
	await wait_process_frames(2)

	# Then: No hold starts.
	assert_signal_emit_count(slot, "action_pressed", 0)

	# When: The action is released.
	StdInputEvent.trigger_action(_TEST_ACTION, 0, false)
	await wait_process_frames(2)

	# Then: The action is up, with no hold to report ending.
	assert_signal_emit_count(slot, "action_released", 0)
	assert_false(_is_tracked(_TEST_ACTION))


func test_input_slot_set_bringing_in_a_held_trigger_blocks_it() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: A set without the trigger's action is loaded.
	_load_actions([_TEST_ACTION])

	# Given: The trigger is held.
	await _dispatch(_stick(JOY_AXIS_TRIGGER_RIGHT, 1.0))

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: A set with the trigger's action is loaded.
	_load_actions([_TEST_ACTION, _TEST_TRIGGER_ACTION])

	# When: The still-held trigger reports motion.
	await _dispatch(_stick(JOY_AXIS_TRIGGER_RIGHT, 0.9))

	# Then: No hold starts.
	assert_signal_emit_count(slot, "action_pressed", 0)

	# When: The trigger is released.
	await _dispatch(_stick(JOY_AXIS_TRIGGER_RIGHT, 0.0))

	# When: The trigger is pressed again.
	await _dispatch(_stick(JOY_AXIS_TRIGGER_RIGHT, 1.0))

	# Then: A hold starts.
	assert_signal_emit_count(slot, "action_pressed", 1)


func test_input_slot_action_returning_to_the_sets_stays_blocked_while_down() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The stick's action is active.
	_load_actions([_TEST_AXIS_ACTION])

	# Given: The stick is held.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 1.0))

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The action leaves the active sets.
	_load_actions([_TEST_ACTION])

	# Given: The action comes back.
	_load_actions([_TEST_AXIS_ACTION])

	# When: The still-held stick reports motion.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 0.9))

	# Then: The first hold ended once.
	assert_signal_emit_count(slot, "action_released", 1)

	# Then: No hold starts.
	assert_signal_emit_count(slot, "action_pressed", 0)


func test_input_slot_blocked_action_released_and_pressed_within_a_frame_holds() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The stick's action is active.
	_load_actions([_TEST_AXIS_ACTION])

	# Given: The stick is held.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 1.0))

	# Given: The joypad components are swapped.
	_swap_joypad_components()

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The stick is released.
	input.send(_stick(JOY_AXIS_LEFT_X, 0.0))

	# When: The stick is pushed again with no frame between.
	input.send(_stick(JOY_AXIS_LEFT_X, 1.0))

	# Then: A hold starts.
	assert_signal_emit_count(slot, "action_pressed", 1)


func test_input_slot_blocked_action_is_cleared_by_the_backstop() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	_load_actions([_TEST_ACTION])

	# Given: The key is held.
	await _dispatch(_key(true))

	# Given: The joypad components are swapped.
	_swap_joypad_components()

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: A node which runs before the slot swallows every release.
	var swallower := ReleaseSwallower.new()
	add_child_autofree(swallower)

	# When: The key is released.
	input.send(_key(false))
	await wait_process_frames(1)

	# Then: Nothing is left to poll.
	assert_false(slot._held_actions.is_processing())

	# Given: The node stops swallowing releases.
	remove_child(swallower)

	# When: The key is pressed again.
	await _dispatch(_key(true))

	# Then: A hold starts.
	assert_signal_emit_count(slot, "action_pressed", 1)


func test_input_slot_blocked_action_ignores_a_press_on_another_binding() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The action bound to the key and the joypad button is active.
	_load_actions([_TEST_ACTION])

	# Given: The key is held.
	await _dispatch(_key(true))

	# Given: The joypad components are swapped.
	_swap_joypad_components()

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The joypad button is pressed.
	await _dispatch(_button(true))

	# Then: No hold starts.
	assert_signal_emit_count(slot, "action_pressed", 0)

	# When: The key is released.
	await _dispatch(_key(false))

	# When: The joypad button is released.
	await _dispatch(_button(false))

	# When: The key is pressed again.
	await _dispatch(_key(true))

	# Then: A hold starts.
	assert_signal_emit_count(slot, "action_pressed", 1)


func test_input_slot_listener_dropping_an_action_stops_its_hold_starting() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: Two actions on one key are active.
	_load_actions([_TEST_SHARED_ACTION_A, _TEST_SHARED_ACTION_B])

	# Given: A listener drops the second when the first is pressed.
	var next := _make_set([_TEST_SHARED_ACTION_A])
	slot.action_pressed.connect(
		func(_action: StringName, _device: int) -> void: slot.load_action_set(next)
	)

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The key is pressed.
	await _dispatch(_key(true, _TEST_KEY_SHARED))

	# Then: Only the first action's hold starts.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_eq(get_signal_parameters(slot, "action_pressed")[0], _TEST_SHARED_ACTION_A)
	assert_false(_is_tracked(_TEST_SHARED_ACTION_B))


func test_input_slot_listener_keeping_an_action_lets_its_hold_start() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: Two actions on one key are active.
	_load_actions([_TEST_SHARED_ACTION_A, _TEST_SHARED_ACTION_B])

	# Given: A listener loads another set holding both when the first is pressed.
	var next := _make_set([_TEST_SHARED_ACTION_A, _TEST_SHARED_ACTION_B])
	slot.action_pressed.connect(
		func(_action: StringName, _device: int) -> void: slot.load_action_set(next)
	)

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The key is pressed.
	await _dispatch(_key(true, _TEST_KEY_SHARED))

	# Then: Both holds start.
	assert_signal_emit_count(slot, "action_pressed", 2)
	assert_gt(slot.get_action_held_seconds(_TEST_SHARED_ACTION_B), 0.0)


func test_input_slot_listener_loading_a_set_during_a_set_change_keeps_its_cursor_rules(
) -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	_load_actions([_TEST_ACTION])

	# Given: The key is held.
	await _dispatch(_key(true))

	# Given: A listener loads a third set when the hold ends.
	var third := _make_set([_TEST_TRIGGER_ACTION], [_TEST_TRIGGER_ACTION])
	slot.action_released.connect(
		func(_action: StringName, _device: int, _seconds: float) -> void:
			slot.load_action_set(third)
	)

	# When: A second set drops the key's action.
	slot.load_action_set(_make_set([_TEST_AXIS_ACTION], [_TEST_AXIS_ACTION]))

	# Then: The slot uses the third set.
	assert_eq(slot.actions.get_action_set(slot.device_id), third)

	# Then: The cursor uses the third set too.
	assert_true(String(_TEST_TRIGGER_ACTION) in slot.cursor._hide_actions)
	assert_false(String(_TEST_AXIS_ACTION) in slot.cursor._hide_actions)


func test_input_slot_listener_loading_a_set_during_a_swap_keeps_it_on_the_joypad(
) -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	_load_actions([_TEST_ACTION])

	# Given: The key is held.
	await _dispatch(_key(true))

	# Given: A listener loads another set when the hold ends.
	var next := _make_set([_TEST_AXIS_ACTION])
	slot.action_released.connect(
		func(_action: StringName, _device: int, _seconds: float) -> void:
			slot.load_action_set(next)
	)

	# Given: A new actions component.
	var actions := SlotTest.DeviceActions.new()
	add_child_autofree(actions)

	# Given: A new monitor reporting the same joypad.
	var joypad_monitor := SlotTest.JoypadMonitor.new()
	joypad_monitor.connected = [0] as Array[int]
	joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	add_child_autofree(joypad_monitor)

	# When: The joypad components are swapped.
	slot.swap_joypad_components(
		joypad_monitor, actions, slot.glyphs_joy, slot.haptics_joy
	)

	# Then: The slot uses the listener's set.
	assert_eq(slot.actions.get_action_set(slot.device_id), next)

	# Then: The joypad uses it too.
	var joypad: StdInputDevice = slot.get_connected_devices(false)[0]
	assert_eq(joypad.actions.get_action_set(joypad.device_id), next)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in [
		_TEST_ACTION,
		_TEST_AXIS_ACTION,
		_TEST_MOUSE_ACTION,
		_TEST_SHARED_ACTION_A,
		_TEST_SHARED_ACTION_B,
		_TEST_TRIGGER_ACTION,
	]:
		InputMap.erase_action(action)


func after_each() -> void:
	get_tree().paused = false


func before_all() -> void:
	InputMap.add_action(_TEST_ACTION, _TEST_DEADZONE)
	InputMap.action_add_event(_TEST_ACTION, _make_key_binding(_TEST_KEY))
	InputMap.action_add_event(_TEST_ACTION, _make_key_binding(_TEST_KEY_ALTERNATE))
	InputMap.action_add_event(_TEST_ACTION, _button(true))

	InputMap.add_action(_TEST_AXIS_ACTION, _TEST_DEADZONE)
	InputMap.action_add_event(_TEST_AXIS_ACTION, _stick(JOY_AXIS_LEFT_X, 1.0))

	InputMap.add_action(_TEST_MOUSE_ACTION, _TEST_DEADZONE)
	var mouse_button := InputEventMouseButton.new()
	mouse_button.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(_TEST_MOUSE_ACTION, mouse_button)

	for action in [_TEST_SHARED_ACTION_A, _TEST_SHARED_ACTION_B]:
		InputMap.add_action(action, _TEST_DEADZONE)
		InputMap.action_add_event(action, _make_key_binding(_TEST_KEY_SHARED))

	InputMap.add_action(_TEST_TRIGGER_ACTION, _TEST_TRIGGER_DEADZONE)
	InputMap.action_add_event(_TEST_TRIGGER_ACTION, _stick(JOY_AXIS_TRIGGER_RIGHT, 1.0))


func before_each() -> void:
	slot = SlotTest.make_slot()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _activate_kbm_with_joypad_connected adds the slot to the scene with the keyboard
## active and joypad `0` connected, then lets a frame pass.
func _activate_kbm_with_joypad_connected() -> void:
	slot.claim_kbm_input = true
	slot.prefer_activate_joypad_on_ready = false
	input = await StdTestInput.mount(self, slot)
	autofree(slot.get_active_device())

	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[0])

	await wait_process_frames(1)
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD, "precondition")


## _active_type returns the active device's type.
func _active_type() -> StdInputDevice.DeviceType:
	return slot.get_active_device().device_type


## _button returns a press, or a release when `pressed` is `false`, of joypad `0`'s
## south face button.
func _button(pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	return event


## _dispatch sends `event` as a player's input and lets a frame pass, so anything
## polling `Input` in `_process` reads it.
func _dispatch(event: InputEvent) -> void:
	input.send(event)
	await wait_process_frames(1)


## _is_tracked returns whether the slot records `action` as held or blocked.
func _is_tracked(action: StringName) -> bool:
	return slot._held_actions._held_since.has(action)


## _key returns a press, or a release when `pressed` is `false`, of `keycode`.
func _key(pressed: bool, keycode: Key = _TEST_KEY) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event


## _load_actions loads a new set declaring `actions`.
func _load_actions(actions: Array[StringName]) -> void:
	slot.load_action_set(_make_set(actions))


## _make_key_binding returns an `InputMap` binding of `keycode`.
func _make_key_binding(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


## _make_set returns a new set declaring `actions` and hiding the cursor on
## `hide_actions`.
func _make_set(
	actions: Array[StringName], hide_actions: Array[StringName] = []
) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = &"Probe"
	action_set.actions_digital = actions
	action_set.cursor_hide_actions = hide_actions
	return action_set


## _stick returns a motion of joypad `0`'s `axis` to `value`.
func _stick(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	return event


## _swap_joypad_components swaps in a monitor reporting no joypads, keeping the slot's
## other components.
func _swap_joypad_components() -> void:
	var joypad_monitor := SlotTest.JoypadMonitor.new()
	add_child_autofree(joypad_monitor)
	slot.swap_joypad_components(
		joypad_monitor, slot.actions_joy, slot.glyphs_joy, slot.haptics_joy
	)
