##
## std/input/slot_held_actions_bindings_test.gd
##
## Tests of a `StdInputSlot`'s holds against the real `StdInputDeviceActions` for
## Godot's action map, whose binding changes reach `Input` as a mock's can't.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const DeviceActions := preload("godot/device_actions.gd")
const SlotTest := preload("slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _ACTION_BUTTON is bound to joypad `0`'s south face button.
const _ACTION_BUTTON := &"probe_bindings_button"

## _ACTION_KEY is bound to `_KEY`.
const _ACTION_KEY := &"probe_bindings_key"

## _ACTION_LAYER is bound to a key nothing else uses.
const _ACTION_LAYER := &"probe_bindings_layer"

## _ACTION_LEFT is bound to the left stick's negative X axis.
const _ACTION_LEFT := &"probe_bindings_left"

## _ACTION_OTHER is bound to a key nothing else uses.
const _ACTION_OTHER := &"probe_bindings_other"

## _ACTION_RIGHT is bound to the left stick's positive X axis.
const _ACTION_RIGHT := &"probe_bindings_right"

## _ACTION_STICK is bound to the right stick's positive Y axis.
const _ACTION_STICK := &"probe_bindings_stick"

## _ACTION_STOMP is bound to `_KEY`, so a layer declaring it takes the key.
const _ACTION_STOMP := &"probe_bindings_stomp"

## _ACTION_TRIGGER is bound to the right trigger with a deadzone below the slot's `0.5`.
const _ACTION_TRIGGER := &"probe_bindings_trigger"

## _ACTIONS lists every action this file defines.
const _ACTIONS: Array[StringName] = [
	_ACTION_BUTTON,
	_ACTION_KEY,
	_ACTION_LAYER,
	_ACTION_LEFT,
	_ACTION_OTHER,
	_ACTION_RIGHT,
	_ACTION_STICK,
	_ACTION_STOMP,
	_ACTION_TRIGGER,
]

## _KEY is the key `_ACTION_KEY` and `_ACTION_STOMP` are bound to.
const _KEY := KEY_Y

# -- INITIALIZATION ------------------------------------------------------------------ #

var actions: StdInputDeviceActions = null
var input: StdTestInput = null
var slot: StdInputSlot = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_slot_key_keeps_its_hold_when_a_set_keeps_its_action() -> void:
	# Given: The key's action is active.
	await _load([_ACTION_KEY])

	# Given: The key is held.
	await _dispatch(_key(true))

	# When: A set keeping the action is loaded.
	await _load([_ACTION_KEY, _ACTION_OTHER])

	# Then: The hold goes on, with no second press.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_signal_emit_count(slot, "action_released", 0)
	assert_gt(slot.get_action_held_seconds(_ACTION_KEY), 0.0)
	assert_true(Input.is_action_pressed(_ACTION_KEY))

	# When: The key is released.
	await _dispatch(_key(false))

	# Then: The hold ends.
	assert_signal_emit_count(slot, "action_released", 1)


func test_input_slot_key_keeps_its_hold_through_a_reload() -> void:
	# Given: The key's action is active.
	await _load([_ACTION_KEY])

	# Given: The key is held.
	await _dispatch(_key(true))

	# When: The bindings are reloaded with nothing changed.
	actions.reload()
	await wait_process_frames(2)

	# Then: The hold goes on.
	assert_signal_emit_count(slot, "action_released", 0)
	assert_gt(slot.get_action_held_seconds(_ACTION_KEY), 0.0)


func test_input_slot_button_keeps_its_hold_when_a_layer_is_disabled() -> void:
	# Given: The button's action is active with an unrelated layer over it.
	var layer := _make_layer([_ACTION_LAYER])
	var action_set := _make_set([_ACTION_BUTTON])
	layer.parent = action_set
	slot.load_action_set(action_set)
	slot.enable_action_set_layer(layer)
	await wait_process_frames(1)

	# Given: The button is held.
	await _dispatch(_button(true))

	# When: The layer is disabled.
	slot.disable_action_set_layer(layer)
	await wait_process_frames(2)

	# Then: The hold goes on.
	assert_signal_emit_count(slot, "action_released", 0)
	assert_gt(slot.get_action_held_seconds(_ACTION_BUTTON), 0.0)


func test_input_slot_stick_keeps_its_hold_when_a_set_keeps_its_action() -> void:
	# Given: The stick's action is active.
	await _load([_ACTION_STICK])

	# Given: The stick is held.
	await _dispatch(_motion(JOY_AXIS_RIGHT_Y, 1.0))

	# When: A set keeping the action is loaded.
	await _load([_ACTION_STICK, _ACTION_OTHER])

	# When: The still-held stick reports motion.
	await _dispatch(_motion(JOY_AXIS_RIGHT_Y, 0.9))

	# Then: The hold goes on, with no second press.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_signal_emit_count(slot, "action_released", 0)


func test_input_slot_trigger_keeps_its_hold_when_a_set_keeps_its_action() -> void:
	# Given: The trigger's action is active.
	await _load([_ACTION_TRIGGER])

	# Given: The trigger is held past its deadzone, but below the slot's `0.5`.
	await _dispatch(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.3))

	# When: A set keeping the action is loaded.
	await _load([_ACTION_TRIGGER, _ACTION_OTHER])

	# When: The still-held trigger reports motion.
	await _dispatch(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.35))

	# Then: The hold goes on, with no second press.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_signal_emit_count(slot, "action_released", 0)


func test_input_slot_injected_press_keeps_its_hold_when_a_set_keeps_its_action(
) -> void:
	# Given: The joypad's bindings belong to another component, as with Steam.
	actions.claim_joy_input = false

	# Given: The button's action is active, which is then unbound.
	await _load([_ACTION_BUTTON])
	assert_eq(InputMap.action_get_events(_ACTION_BUTTON).size(), 0, "precondition")

	# Given: The action is pressed by an injected event, as Steam publishes it.
	await _dispatch(_injected(_ACTION_BUTTON, true, 0.8))

	# When: A set keeping the action is loaded.
	await _load([_ACTION_BUTTON, _ACTION_OTHER])

	# When: The action is published again, as Steam does when its strength changes.
	await _dispatch(_injected(_ACTION_BUTTON, true, 0.9))

	# Then: The hold goes on, with no second press.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_signal_emit_count(slot, "action_released", 0)

	# When: The injected press is released.
	await _dispatch(_injected(_ACTION_BUTTON, false))

	# Then: The hold ends.
	assert_signal_emit_count(slot, "action_released", 1)


func test_input_slot_key_repeat_after_a_set_keeps_its_action_is_no_new_press() -> void:
	# Given: The key's action is active.
	await _load([_ACTION_KEY])

	# Given: The key is held.
	await _dispatch(_key(true))

	# Given: A set keeping the action is loaded.
	await _load([_ACTION_KEY, _ACTION_OTHER])

	# When: The key repeats.
	input.send(_key(true, true))

	# Then: A game polling `Input` sees no new press.
	assert_false(Input.is_action_just_pressed(_ACTION_KEY))


func test_input_slot_key_loses_its_hold_when_a_layer_takes_it() -> void:
	# Given: The key's action is active.
	var action_set := _make_set([_ACTION_KEY])
	slot.load_action_set(action_set)
	await wait_process_frames(1)

	# Given: The key is held.
	await _dispatch(_key(true))

	# When: A layer takes the key.
	var layer := _make_layer([_ACTION_STOMP])
	layer.parent = action_set
	slot.enable_action_set_layer(layer)
	await wait_process_frames(2)

	# Then: The hold ends.
	assert_signal_emit_count(slot, "action_released", 1)
	assert_false(Input.is_action_pressed(_ACTION_KEY))

	# When: The key is released.
	await _dispatch(_key(false))

	# Then: Nothing more is reported.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_signal_emit_count(slot, "action_released", 1)


func test_input_slot_stick_dropped_and_brought_back_starts_no_hold_while_down() -> void:
	# Given: The stick's action is active.
	await _load([_ACTION_STICK])

	# Given: The stick is held.
	await _dispatch(_motion(JOY_AXIS_RIGHT_Y, 1.0))

	# Given: A set without the action is loaded.
	await _load([_ACTION_OTHER])

	# Given: A set with the action is loaded.
	await _load([_ACTION_STICK])

	# When: The still-held stick reports motion.
	await _dispatch(_motion(JOY_AXIS_RIGHT_Y, 0.9))

	# Then: The first hold ended and no other started.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_signal_emit_count(slot, "action_released", 1)

	# When: The stick is let go.
	await _dispatch(_motion(JOY_AXIS_RIGHT_Y, 0.0))

	# When: The stick is pushed again.
	await _dispatch(_motion(JOY_AXIS_RIGHT_Y, 1.0))

	# Then: A hold starts.
	assert_signal_emit_count(slot, "action_pressed", 2)


func test_input_slot_key_dropped_and_brought_back_starts_no_hold_while_down() -> void:
	# Given: The key's action is active.
	await _load([_ACTION_KEY])

	# Given: The key is held.
	await _dispatch(_key(true))

	# Given: A set without the action is loaded.
	await _load([_ACTION_OTHER])

	# Given: A set with the action is loaded.
	await _load([_ACTION_KEY])

	# When: The key repeats.
	await _dispatch(_key(true, true))

	# Then: The first hold ended and no other started.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_signal_emit_count(slot, "action_released", 1)

	# When: The key is released.
	await _dispatch(_key(false))

	# When: The key is pressed again.
	await _dispatch(_key(true))

	# Then: A hold starts.
	assert_signal_emit_count(slot, "action_pressed", 2)


func test_input_slot_set_bringing_in_a_held_trigger_starts_no_hold() -> void:
	# Given: A set without the trigger's action is loaded.
	await _load([_ACTION_OTHER])

	# Given: The trigger is held.
	await _dispatch(_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))

	# Given: A set with the action is loaded.
	await _load([_ACTION_TRIGGER])

	# When: The still-held trigger reports motion.
	await _dispatch(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.9))

	# Then: No hold starts.
	assert_signal_emit_count(slot, "action_pressed", 0)


func test_input_slot_trigger_held_before_the_slot_saw_it_starts_no_hold() -> void:
	# Given: The trigger's action is active.
	await _load([_ACTION_TRIGGER])

	# Given: The trigger is held while the slot reads no input, as before it existed.
	slot.set_process_input(false)
	await _dispatch(_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	slot.set_process_input(true)
	assert_true(Input.is_action_pressed(_ACTION_TRIGGER), "precondition: pressed")

	# When: The still-held trigger reports motion.
	await _dispatch(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.9))

	# Then: No hold starts.
	assert_signal_emit_count(slot, "action_pressed", 0)

	# When: The trigger is let go and squeezed again.
	await _dispatch(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	await _dispatch(_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))

	# Then: A hold starts.
	assert_signal_emit_count(slot, "action_pressed", 1)


func test_input_slot_trigger_starts_no_hold_when_the_joypad_claim_returns() -> void:
	# Given: The trigger's action is active.
	await _load([_ACTION_TRIGGER])

	# Given: The trigger is held.
	await _dispatch(_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))

	# Given: The joypad's bindings are given up and taken back.
	actions.claim_joy_input = false
	await wait_process_frames(2)
	actions.claim_joy_input = true
	await wait_process_frames(2)

	# When: The still-held trigger reports motion.
	await _dispatch(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.9))

	# Then: The first hold ended and no other started.
	assert_signal_emit_count(slot, "action_pressed", 1)
	assert_signal_emit_count(slot, "action_released", 1)


func test_input_slot_stick_flicked_across_ends_one_hold_and_starts_the_other() -> void:
	# Given: Both directions' actions are active.
	await _load([_ACTION_LEFT, _ACTION_RIGHT])

	# Given: The stick is held left.
	await _dispatch(_motion(JOY_AXIS_LEFT_X, -0.8))

	# When: The stick is flicked right, with no report between.
	await _dispatch(_motion(JOY_AXIS_LEFT_X, 0.8))

	# Then: The left hold ended.
	assert_eq(slot.get_action_held_seconds(_ACTION_LEFT), 0.0)
	assert_signal_emit_count(slot, "action_released", 1)

	# Then: The right hold started.
	assert_gt(slot.get_action_held_seconds(_ACTION_RIGHT), 0.0)
	assert_signal_emit_count(slot, "action_pressed", 2)


func test_input_slot_stick_pushed_after_a_disconnect_starts_a_hold() -> void:
	# Given: The stick's action is active.
	await _load([_ACTION_STICK])

	# Given: The stick is held.
	await _dispatch(_motion(JOY_AXIS_RIGHT_Y, 1.0))

	# Given: The joypad disconnects, which clears `Input` with no event.
	#
	# NOTE: A headless run has no joypad to disconnect, so its effects are stood in for.
	Input.action_release(_ACTION_STICK)
	Input.joy_connection_changed.emit(0, false)
	await wait_process_frames(1)

	# When: The stick is pushed after the joypad reconnects at rest, reporting nothing.
	await _dispatch(_motion(JOY_AXIS_RIGHT_Y, 1.0))

	# Then: A hold starts.
	assert_signal_emit_count(slot, "action_pressed", 2)
	assert_gt(slot.get_action_held_seconds(_ACTION_STICK), 0.0)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	# NOTE: The component's static set names these actions, so it's forgotten too.
	DeviceActions._action_set = null
	DeviceActions._action_set_layers = []

	for action in _ACTIONS:
		InputMap.erase_action(action)
		ProjectSettings.set_setting(&"input/" + action, null)


func after_each() -> void:
	# NOTE: `Input` outlives each test, so a press left down would carry into the next.
	for action in _ACTIONS:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func before_all() -> void:
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A

	_bind(_ACTION_BUTTON, button)
	_bind(_ACTION_KEY, _make_key_binding(_KEY))
	_bind(_ACTION_LAYER, _make_key_binding(KEY_L))
	_bind(_ACTION_LEFT, _motion(JOY_AXIS_LEFT_X, -1.0))
	_bind(_ACTION_OTHER, _make_key_binding(KEY_U))
	_bind(_ACTION_RIGHT, _motion(JOY_AXIS_LEFT_X, 1.0))
	_bind(_ACTION_STICK, _motion(JOY_AXIS_RIGHT_Y, 1.0))
	_bind(_ACTION_STOMP, _make_key_binding(_KEY))
	_bind(_ACTION_TRIGGER, _motion(JOY_AXIS_TRIGGER_RIGHT, 1.0), 0.2)


func before_each() -> void:
	slot = SlotTest.make_slot()

	var scope := StdSettingsScope.new()
	scope.is_loaded = true

	actions = DeviceActions.new()
	actions.scope = scope

	slot.remove_child(slot.actions_kbm)
	slot.actions_kbm.free()
	slot.remove_child(slot.actions_joy)
	slot.actions_joy.free()
	slot.actions_kbm = actions
	slot.actions_joy = actions
	slot.add_child(actions)

	slot.claim_kbm_input = true
	slot.prefer_activate_joypad_on_ready = false
	input = await StdTestInput.mount(self, slot)
	autofree(slot.get_active_device())

	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[0])

	await wait_process_frames(1)

	watch_signals(slot)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _bind defines `action` with `event` as its default binding.
func _bind(action: StringName, event: InputEvent, deadzone: float = 0.5) -> void:
	InputMap.add_action(action, deadzone)
	ProjectSettings.set_setting(
		&"input/" + action, {"deadzone": deadzone, "events": [event]}
	)


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


## _injected returns an injected press, or a release when `pressed` is `false`, of
## `action` on joypad `0`.
func _injected(
	action: StringName, pressed: bool, strength: float = 1.0
) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.device = 0
	event.pressed = pressed
	event.strength = strength if pressed else 0.0
	return event


## _key returns a press, or a release when `pressed` is `false`, of `_KEY`.
func _key(pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = _KEY
	event.pressed = pressed
	event.echo = echo
	return event


## _load loads a new set declaring `declared` and lets the slot process the change.
func _load(declared: Array[StringName]) -> void:
	slot.load_action_set(_make_set(declared))
	await wait_process_frames(2)


## _make_key_binding returns a binding of `keycode`.
func _make_key_binding(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


## _make_layer returns a new layer declaring `declared`.
func _make_layer(declared: Array[StringName]) -> StdInputActionSetLayer:
	var layer := StdInputActionSetLayer.new()
	layer.name = &"ProbeLayer"
	layer.actions_digital = declared
	return layer


## _make_set returns a new set declaring `declared`, whose trigger is an analog action.
func _make_set(declared: Array[StringName]) -> StdInputActionSet:
	var digital: Array[StringName] = []
	var analog: Array[StringName] = []

	for action in declared:
		if action == _ACTION_TRIGGER:
			analog.append(action)
		else:
			digital.append(action)

	var action_set := StdInputActionSet.new()
	action_set.name = &"Probe"
	action_set.actions_digital = digital
	action_set.actions_analog_1d = analog
	return action_set


## _motion returns a motion of joypad `0`'s `axis` to `value`.
func _motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	return event
