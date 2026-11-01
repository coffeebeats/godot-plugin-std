# gdlint:ignore=max-public-methods
##
## std/input/slot_input_test.gd
##
## Tests driving a `StdInputSlot` and its cursor through the `Input` singleton and real
## frames, as the engine does, rather than by calling their input callbacks directly.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _TEST_ACTION is an action bound to `_TEST_KEY`.
const _TEST_ACTION := &"probe_action"

## _TEST_AXIS_ACTION is an action bound to the left stick's positive horizontal axis.
const _TEST_AXIS_ACTION := &"probe_axis"

## _TEST_DEADZONE is the deadzone of the test actions.
const _TEST_DEADZONE := 0.5

## _TEST_HIDE_ACTION is a cursor hide action bound to the left stick's positive
## vertical axis.
const _TEST_HIDE_ACTION := &"probe_hide"

## _TEST_KEY is the key bound to `_TEST_ACTION`.
const _TEST_KEY := KEY_T

## _TEST_KEY_ALTERNATE is a second key bound to `_TEST_ACTION`.
const _TEST_KEY_ALTERNATE := KEY_Y

## _TEST_TRIGGER_ACTION is an action bound to the right trigger, whose deadzone sits
## below the `0.5` at which a joypad motion event reads as pressed.
const _TEST_TRIGGER_ACTION := &"probe_trigger"

## _TEST_TRIGGER_DEADZONE is the deadzone of `_TEST_TRIGGER_ACTION`.
const _TEST_TRIGGER_DEADZONE := 0.2

## _TEST_UNMAPPED_ACTION is an action the `InputMap` doesn't define.
const _TEST_UNMAPPED_ACTION := &"probe_unmapped"


## ReleaseSwallower marks every release as handled, as an upstream `_input` can. It runs
## before any node earlier in the tree, since `_input` runs in reverse tree order.
class ReleaseSwallower:
	extends Node

	func _input(event: InputEvent) -> void:
		if event.is_action_type() and not event.is_pressed():
			get_viewport().set_input_as_handled()


# -- INITIALIZATION ------------------------------------------------------------------ #

var slot: StdInputSlot = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_slot_held_stick_cannot_reactivate_joypad_until_released() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key and stick actions are active.
	slot._actions = [_TEST_ACTION, _TEST_AXIS_ACTION]

	# When: The stick is pushed past the deadzone.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 1.0))

	# Then: The joypad is active.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_GENERIC)

	# Given: The bound key is pressed and released while the stick is held.
	await _dispatch(_key(true))
	await _dispatch(_key(false))
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD, "precondition")

	# When: The still-held stick reports motion again.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 0.9))

	# Then: The keyboard stays active.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# When: The stick returns inside the deadzone.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 0.3))

	# When: The stick is pushed again.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 1.0))

	# Then: The joypad is active again.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_GENERIC)


func test_input_slot_opposite_stick_flick_releases_and_rearms_the_action() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key and stick actions are active.
	slot._actions = [_TEST_ACTION, _TEST_AXIS_ACTION]

	# Given: The stick is held, which activates the joypad.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 1.0))

	# Given: The bound key is pressed and released, which activates the keyboard.
	await _dispatch(_key(true))
	await _dispatch(_key(false))
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD, "precondition")

	# When: The stick flicks to the opposite side without centering.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, -1.0))

	# When: The stick flicks back.
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 1.0))

	# Then: The joypad is active again.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_GENERIC)


func test_input_slot_mouse_motion_reveals_cursor_without_activating_kbm() -> void:
	# Given: The slot is added to the scene with a joypad preferred.
	slot.claim_kbm_input = true
	slot.prefer_activate_joypad_on_ready = true
	add_child_autofree(slot)
	autofree(slot.get_active_device())

	# Given: A joypad connects, which activates it.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_active_device())
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_GENERIC, "precondition")

	# Given: A set which reveals the cursor on any motion is loaded.
	slot.load_action_set(_make_action_set())

	# Given: The cursor is hidden once a frame passes.
	await wait_process_frames(1)
	assert_false(slot.cursor.get_is_visible(), "precondition: cursor hidden")

	# When: The mouse moves.
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(10, 0)
	motion.screen_relative = Vector2(10, 0)
	await _dispatch(motion)

	# Then: The cursor is visible.
	assert_true(slot.cursor.get_is_visible())

	# Then: The joypad is still active.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_GENERIC)


func test_cursor_held_hide_action_is_released_by_input_state() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: A set whose hide action is bound to the stick is loaded.
	slot.load_action_set(_make_action_set())

	# Given: The cursor is visible.
	slot.cursor.show_cursor()
	await wait_process_frames(1)
	assert_true(slot.cursor.get_is_visible(), "precondition: cursor visible")

	# When: The stick is pushed past the deadzone.
	await _dispatch(_stick(JOY_AXIS_LEFT_Y, 1.0))

	# Then: The cursor is hidden.
	assert_false(slot.cursor.get_is_visible())

	# Given: The cursor is shown again.
	slot.cursor.show_cursor()

	# When: The still-held stick reports motion again.
	await _dispatch(_stick(JOY_AXIS_LEFT_Y, 0.9))

	# Then: The cursor stays visible.
	assert_true(slot.cursor.get_is_visible())

	# When: The stick is released for a frame.
	await _dispatch(_stick(JOY_AXIS_LEFT_Y, 0.0))

	# When: The stick is pushed again.
	await _dispatch(_stick(JOY_AXIS_LEFT_Y, 1.0))

	# Then: The cursor is hidden again.
	assert_false(slot.cursor.get_is_visible())


func test_input_slot_key_and_pad_on_one_action_count_as_one_hold() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The action bound to the key and the joypad button is active.
	slot._actions = [_TEST_ACTION]

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
	slot._actions = [_TEST_ACTION]

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: Both keys are held.
	await _dispatch(_key(true))
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
	slot._actions = [_TEST_ACTION]

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The key is held.
	await _dispatch(_key(true))

	# When: A second and a half passes.
	slot._held_since[_TEST_ACTION] -= 1_500_000

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
	slot._actions = [_TEST_ACTION]

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
	slot._actions = [_TEST_ACTION]

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The key is held.
	await _dispatch(_key(true))

	# Given: A node which runs before the slot swallows every release.
	add_child_autofree(ReleaseSwallower.new())

	# When: The key is released.
	Input.parse_input_event(_key(false))
	Input.flush_buffered_events()

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
	slot._actions = [_TEST_ACTION]

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


func test_input_slot_backstop_runs_only_while_an_action_is_held() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	slot._actions = [_TEST_ACTION]

	# Then: The slot isn't processing.
	assert_false(slot.is_processing())

	# When: The key is pressed.
	await _dispatch(_key(true))

	# Then: The slot is processing.
	assert_true(slot.is_processing())

	# When: The key is released.
	await _dispatch(_key(false))

	# Then: The slot isn't processing.
	assert_false(slot.is_processing())


func test_input_slot_action_pressed_below_the_activation_threshold_is_held() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The trigger's action is active.
	slot._actions = [_TEST_TRIGGER_ACTION]

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
	slot._actions = [_TEST_ACTION]

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: A button triggers the action.
	StdInputEvent.trigger_action(_TEST_ACTION)
	await wait_process_frames(2)

	# Then: The hold starts on the synthetic device.
	assert_signal_emitted_with_parameters(
		slot, "action_pressed", [_TEST_ACTION, StdInputEvent.DEVICE_ID_SYNTHETIC]
	)

	# When: The button releases the action.
	StdInputEvent.trigger_action(_TEST_ACTION, StdInputEvent.DEVICE_ID_SYNTHETIC, false)
	await wait_process_frames(2)

	# Then: The hold ends.
	assert_signal_emit_count(slot, "action_released", 1)


func test_input_slot_action_missing_from_input_map_ends_on_its_release() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: An action the `InputMap` doesn't define is active, as Steam can publish.
	slot._actions = [_TEST_UNMAPPED_ACTION]

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
	slot.load_action_set(_make_action_set())

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: Both actions are held.
	await _dispatch(_key(true))
	await _dispatch(_stick(JOY_AXIS_LEFT_X, 1.0))

	# When: A set declaring only the stick's action is loaded.
	var next := StdInputActionSet.new()
	next.name = &"Next"
	next.actions_digital = [_TEST_AXIS_ACTION]
	slot.load_action_set(next)

	# Then: Only the dropped action's hold ends.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_eq(get_signal_parameters(slot, "action_released")[0], _TEST_ACTION)
	assert_eq(slot.get_action_held_seconds(_TEST_ACTION), 0.0)
	assert_gt(slot.get_action_held_seconds(_TEST_AXIS_ACTION), 0.0)


func test_input_slot_unclaimed_keyboard_holds_nothing() -> void:
	# Given: The keyboard is active with a joypad connected.
	await _activate_kbm_with_joypad_connected()

	# Given: The key's action is active.
	slot._actions = [_TEST_ACTION]

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
	slot._actions = [_TEST_ACTION]

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
	slot._actions = [_TEST_ACTION]

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The key is held.
	await _dispatch(_key(true))

	# When: The slot leaves the tree.
	remove_child(slot)

	# Then: The hold ends.
	assert_signal_emit_count(slot, "action_released", 1)

	# Then: The slot isn't processing.
	assert_false(slot.is_processing())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _list_test_actions():
		InputMap.erase_action(action)


func after_each() -> void:
	# NOTE: Every test action is released, so a held stick can't leak into the next.
	for action in _list_test_actions():
		Input.action_release(action)
	await wait_process_frames(1)


func before_all() -> void:
	InputMap.add_action(_TEST_ACTION, _TEST_DEADZONE)
	var key := InputEventKey.new()
	key.keycode = _TEST_KEY
	InputMap.action_add_event(_TEST_ACTION, key)

	var key_alternate := InputEventKey.new()
	key_alternate.keycode = _TEST_KEY_ALTERNATE
	InputMap.action_add_event(_TEST_ACTION, key_alternate)

	InputMap.action_add_event(_TEST_ACTION, _button(true))

	InputMap.add_action(_TEST_AXIS_ACTION, _TEST_DEADZONE)
	InputMap.action_add_event(_TEST_AXIS_ACTION, _stick(JOY_AXIS_LEFT_X, 1.0))

	InputMap.add_action(_TEST_HIDE_ACTION, _TEST_DEADZONE)
	InputMap.action_add_event(_TEST_HIDE_ACTION, _stick(JOY_AXIS_LEFT_Y, 1.0))

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
	add_child_autofree(slot)
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


## _dispatch parses `event` through `Input` and lets two frames pass so the engine
## delivers it to the scene.
func _dispatch(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await wait_process_frames(2)


## _key returns a press, or a release when `pressed` is `false`, of `keycode`.
func _key(pressed: bool, keycode: Key = _TEST_KEY) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event


## _list_test_actions returns every action `before_all` adds to the `InputMap`.
func _list_test_actions() -> Array[StringName]:
	return [_TEST_ACTION, _TEST_AXIS_ACTION, _TEST_HIDE_ACTION, _TEST_TRIGGER_ACTION]


## _make_action_set returns an action set declaring the test actions, hiding the cursor
## on the hide action, and revealing it on any mouse motion.
func _make_action_set() -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = &"Probe"
	action_set.actions_digital = [_TEST_ACTION, _TEST_AXIS_ACTION, _TEST_HIDE_ACTION]
	action_set.cursor_hide_actions = [_TEST_HIDE_ACTION]
	return action_set


## _stick returns a motion of joypad `0`'s `axis` to `value`.
func _stick(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	return event
