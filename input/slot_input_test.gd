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


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in [_TEST_ACTION, _TEST_AXIS_ACTION, _TEST_HIDE_ACTION]:
		InputMap.erase_action(action)


func after_each() -> void:
	# NOTE: Every test action is released, so a held stick can't leak into the next.
	for action in [_TEST_ACTION, _TEST_AXIS_ACTION, _TEST_HIDE_ACTION]:
		Input.action_release(action)
	await wait_process_frames(1)


func before_all() -> void:
	InputMap.add_action(_TEST_ACTION, _TEST_DEADZONE)
	var key := InputEventKey.new()
	key.keycode = _TEST_KEY
	InputMap.action_add_event(_TEST_ACTION, key)

	InputMap.add_action(_TEST_AXIS_ACTION, _TEST_DEADZONE)
	InputMap.action_add_event(_TEST_AXIS_ACTION, _stick(JOY_AXIS_LEFT_X, 1.0))

	InputMap.add_action(_TEST_HIDE_ACTION, _TEST_DEADZONE)
	InputMap.action_add_event(_TEST_HIDE_ACTION, _stick(JOY_AXIS_LEFT_Y, 1.0))


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


## _dispatch parses `event` through `Input` and lets two frames pass so the engine
## delivers it to the scene.
func _dispatch(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await wait_process_frames(2)


## _key returns a press, or a release when `pressed` is `false`, of the test key.
func _key(pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = _TEST_KEY
	event.pressed = pressed
	return event


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
