##
## std/input/godot/device_actions_test.gd
##
## Tests pertaining to the Godot implementation of `StdInputDeviceActions`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const DeviceActions := preload("device_actions.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_ID_ALL := StdInputDevice.DEVICE_ID_ALL

## _DEFAULTS maps each test action to the key it is bound to by default.
const _DEFAULTS := {
	&"test_set_a": KEY_A,
	&"test_set_b": KEY_B,
	&"test_layer": KEY_L,
	&"test_layer_stomp": KEY_A,
	&"test_move_left": KEY_J,
	&"test_move_right": KEY_L,
	&"test_move_up": KEY_I,
	&"test_move_down": KEY_K,
}

## _JOY_ACTION is bound only to a joypad button, so a keyboard-only component leaves it
## unbound, as with an action which only Steam reports.
const _JOY_ACTION := &"test_joy"

## _LOCATED_ACTION is bound to the left and the right shift keys, which the input map
## keeps as one event.
const _LOCATED_ACTION := &"test_shift"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _actions: StdInputDeviceActions = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_device_actions_parentless_layer_enables_over_either_set() -> void:
	# Given: Two action sets and a layer with no parent.
	var set_a := _make_action_set(&"A", [&"test_set_a"])
	var set_b := _make_action_set(&"B", [&"test_set_b"])
	var layer := _make_layer(&"L", null, [&"test_layer"])

	# Given: The first set is loaded.
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_a))

	# When: The layer is enabled over it.
	assert_true(_actions.enable_action_set_layer(DEVICE_ID_ALL, layer))

	# Then: Both the set's and the layer's actions are bound.
	assert_true(_is_bound(&"test_set_a", KEY_A))
	assert_true(_is_bound(&"test_layer", KEY_L))

	# When: The second set is loaded.
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_b))

	# Then: The first set's and the layer's bindings are gone.
	assert_false(_is_bound(&"test_set_a", KEY_A))
	assert_false(_is_bound(&"test_layer", KEY_L))

	# Then: No layer is enabled.
	assert_eq(_actions.list_action_set_layers(DEVICE_ID_ALL).size(), 0)

	# When: The same layer is enabled over the second set.
	assert_true(_actions.enable_action_set_layer(DEVICE_ID_ALL, layer))

	# Then: The second set's and the layer's actions are bound.
	assert_true(_is_bound(&"test_set_b", KEY_B))
	assert_true(_is_bound(&"test_layer", KEY_L))


func test_device_actions_layer_takes_an_origin_from_the_set() -> void:
	# Given: An action set and a layer of it whose action shares the set's key.
	var set_a := _make_action_set(&"A", [&"test_set_a"])
	var layer := _make_layer(&"L", set_a, [&"test_layer_stomp"])

	# Given: The set is loaded.
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_a))

	# When: The layer is enabled.
	assert_true(_actions.enable_action_set_layer(DEVICE_ID_ALL, layer))

	# Then: The layer's action holds the key and the set's does not.
	assert_true(_is_bound(&"test_layer_stomp", KEY_A))
	assert_false(_is_bound(&"test_set_a", KEY_A))

	# When: The layer is disabled.
	assert_true(_actions.disable_action_set_layer(DEVICE_ID_ALL, layer))

	# Then: The set's action holds the key again.
	assert_true(_is_bound(&"test_set_a", KEY_A))
	assert_false(_is_bound(&"test_layer_stomp", KEY_A))


func test_device_actions_set_with_a_2d_analog_action_binds_its_directions() -> void:
	# Given: An action set declaring a stick, which the input map doesn't know, and its
	# four directional actions.
	var set_move := _make_action_set(
		&"Move",
		[&"test_move_left", &"test_move_right", &"test_move_up", &"test_move_down"],
	)
	set_move.actions_analog_2d = [&"test_move"]
	assert_false(InputMap.has_action(&"test_move"), "precondition: stick unknown")

	# When: The set is loaded.
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_move))

	# Then: The four directional actions are bound and the stick was left alone.
	assert_true(_is_bound(&"test_move_left", KEY_J))
	assert_true(_is_bound(&"test_move_right", KEY_L))
	assert_true(_is_bound(&"test_move_up", KEY_I))
	assert_true(_is_bound(&"test_move_down", KEY_K))
	assert_false(InputMap.has_action(&"test_move"))


func test_device_actions_layer_disable_does_not_report_a_bindings_change() -> void:
	# Given: An action set loaded with a layer enabled over it.
	var set_a := _make_action_set(&"A", [&"test_set_a"])
	var layer := _make_layer(&"L", set_a, [&"test_layer"])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_a))
	assert_true(_actions.enable_action_set_layer(DEVICE_ID_ALL, layer))
	watch_signals(_actions)

	# When: The layer is disabled.
	assert_true(_actions.disable_action_set_layer(DEVICE_ID_ALL, layer))

	# Then: No bindings change is reported, as the layer change is reported by the
	# caller, while the set's bindings are rebuilt.
	assert_signal_not_emitted(_actions, "bindings_changed")
	assert_true(_is_bound(&"test_set_a", KEY_A))
	assert_false(_is_bound(&"test_layer", KEY_L))

	# When: The bindings are reloaded.
	_actions.reload()

	# Then: A bindings change is reported once.
	assert_signal_emit_count(_actions, "bindings_changed", 1)


func test_device_actions_unchanged_action_stays_pressed_through_binding_changes(
) -> void:
	# Given: An action set and a layer of it, which leaves the action's binding alone.
	var set_a := _make_action_set(&"A", [&"test_set_a"])
	var layer := _make_layer(&"L", set_a, [&"test_layer"])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_a))

	# Given: The action's key is held.
	_send_key(KEY_A, true)
	assert_true(Input.is_action_pressed(&"test_set_a"), "precondition: pressed")

	# When: A layer is enabled.
	assert_true(_actions.enable_action_set_layer(DEVICE_ID_ALL, layer))

	# Then: The action is still pressed.
	assert_true(Input.is_action_pressed(&"test_set_a"))

	# When: The layer is disabled.
	assert_true(_actions.disable_action_set_layer(DEVICE_ID_ALL, layer))

	# Then: The action is still pressed.
	assert_true(Input.is_action_pressed(&"test_set_a"))

	# When: The bindings are reloaded.
	_actions.reload()

	# Then: The action is still pressed.
	assert_true(Input.is_action_pressed(&"test_set_a"))

	# When: A set keeping the action is loaded.
	var set_b := _make_action_set(&"B", [&"test_set_a", &"test_set_b"])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_b))

	# Then: The action is still pressed.
	assert_true(Input.is_action_pressed(&"test_set_a"))

	# When: The key is released.
	_send_key(KEY_A, false)

	# Then: The action is released.
	assert_false(Input.is_action_pressed(&"test_set_a"))


func test_device_actions_action_bound_at_two_key_locations_stays_pressed() -> void:
	# Given: An action set declaring an action bound to both shift keys.
	var set_a := _make_action_set(&"A", [_LOCATED_ACTION])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_a))
	assert_eq(
		InputMap.action_get_events(_LOCATED_ACTION).size(), 1, "precondition: one event"
	)

	# Given: The left shift key is held.
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	assert_true(Input.is_action_pressed(_LOCATED_ACTION), "precondition: pressed")

	# When: A set keeping the action is loaded.
	var set_b := _make_action_set(&"B", [_LOCATED_ACTION, &"test_set_b"])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_b))

	# Then: The action is still pressed.
	assert_true(Input.is_action_pressed(_LOCATED_ACTION))

	# When: The key is released.
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)

	# Then: The action is released.
	assert_false(Input.is_action_pressed(_LOCATED_ACTION))


func test_device_actions_action_losing_its_origin_is_released() -> void:
	# Given: An action set and a layer of it whose action shares the set's key.
	var set_a := _make_action_set(&"A", [&"test_set_a"])
	var layer := _make_layer(&"L", set_a, [&"test_layer_stomp"])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_a))

	# Given: The key is held.
	_send_key(KEY_A, true)
	assert_true(Input.is_action_pressed(&"test_set_a"), "precondition: pressed")

	# When: The layer takes the key.
	assert_true(_actions.enable_action_set_layer(DEVICE_ID_ALL, layer))

	# Then: The set's action is released.
	assert_false(Input.is_action_pressed(&"test_set_a"))


func test_device_actions_dropped_action_is_released() -> void:
	# Given: An action set is loaded.
	var set_a := _make_action_set(&"A", [&"test_set_a"])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_a))

	# Given: The action's key is held.
	_send_key(KEY_A, true)
	assert_true(Input.is_action_pressed(&"test_set_a"), "precondition: pressed")

	# When: A set without the action is loaded.
	var set_b := _make_action_set(&"B", [&"test_set_b"])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_b))

	# Then: The action is released.
	assert_false(Input.is_action_pressed(&"test_set_a"))


func test_device_actions_injected_press_ends_after_its_action_gains_a_binding() -> void:
	# Given: The keyboard isn't claimed, so the action is unbound.
	_actions.claim_kbm_input = false

	# Given: An action set is loaded.
	var set_a := _make_action_set(&"A", [&"test_set_a"])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_a))
	assert_eq(
		InputMap.action_get_events(&"test_set_a").size(), 0, "precondition: unbound"
	)

	# Given: The action is pressed by an injected event.
	_send_action(&"test_set_a", true)
	assert_true(Input.is_action_pressed(&"test_set_a"), "precondition: pressed")

	# Given: The action gains a binding.
	_actions.claim_kbm_input = true

	# When: The injected press is released.
	_send_action(&"test_set_a", false)

	# Then: The action is released.
	assert_false(Input.is_action_pressed(&"test_set_a"))


func test_device_actions_injected_press_on_a_kept_unbound_action_stays_pressed(
) -> void:
	# Given: An action set declaring an action which is left unbound.
	var set_a := _make_action_set(&"A", [_JOY_ACTION])
	var layer := _make_layer(&"L", set_a, [&"test_layer"])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_a))
	assert_eq(
		InputMap.action_get_events(_JOY_ACTION).size(), 0, "precondition: unbound"
	)

	# Given: The action is pressed by an injected event, as Steam publishes it.
	_send_action(_JOY_ACTION, true)
	assert_true(Input.is_action_pressed(_JOY_ACTION), "precondition: pressed")

	# When: A layer is enabled and then disabled.
	assert_true(_actions.enable_action_set_layer(DEVICE_ID_ALL, layer))
	assert_true(_actions.disable_action_set_layer(DEVICE_ID_ALL, layer))

	# Then: The action is still pressed.
	assert_true(Input.is_action_pressed(_JOY_ACTION))

	# When: A set keeping the action is loaded.
	var set_b := _make_action_set(&"B", [_JOY_ACTION, &"test_set_b"])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_b))

	# Then: The action is still pressed.
	assert_true(Input.is_action_pressed(_JOY_ACTION))

	# When: The injected press is released.
	_send_action(_JOY_ACTION, false)

	# Then: The action is released.
	assert_false(Input.is_action_pressed(_JOY_ACTION))


func test_device_actions_injected_press_on_a_dropped_unbound_action_is_released(
) -> void:
	# Given: An action set declaring an action which is left unbound.
	var set_a := _make_action_set(&"A", [_JOY_ACTION])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_a))

	# Given: The action is pressed by an injected event, as Steam publishes it.
	_send_action(_JOY_ACTION, true)
	assert_true(Input.is_action_pressed(_JOY_ACTION), "precondition: pressed")

	# When: A set without the action is loaded.
	var set_b := _make_action_set(&"B", [&"test_set_b"])
	assert_true(_actions.load_action_set(DEVICE_ID_ALL, set_b))

	# Then: The action is released.
	assert_false(Input.is_action_pressed(_JOY_ACTION))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	# NOTE: The component's static set names these actions, so it's forgotten too.
	DeviceActions._action_set = null
	DeviceActions._action_set_layers = []

	for action in [_JOY_ACTION, _LOCATED_ACTION]:
		InputMap.erase_action(action)
		ProjectSettings.set_setting(&"input/" + action, null)

	for action in _DEFAULTS:
		InputMap.erase_action(action)
		ProjectSettings.set_setting(&"input/" + action, null)


func after_each() -> void:
	# NOTE: `Input` outlives each test, so a press left down would carry into the next.
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)


func before_all() -> void:
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A

	InputMap.add_action(_JOY_ACTION)
	ProjectSettings.set_setting(
		&"input/" + _JOY_ACTION, {"deadzone": 0.5, "events": [button]}
	)

	var shifts: Array[InputEvent] = []
	for location in [KEY_LOCATION_LEFT, KEY_LOCATION_RIGHT]:
		var shift := InputEventKey.new()
		shift.keycode = KEY_SHIFT
		shift.location = location
		shifts.append(shift)

	InputMap.add_action(_LOCATED_ACTION)
	ProjectSettings.set_setting(
		&"input/" + _LOCATED_ACTION, {"deadzone": 0.5, "events": shifts}
	)

	for action in _DEFAULTS:
		InputMap.add_action(action)

		var event := InputEventKey.new()
		event.keycode = _DEFAULTS[action]
		ProjectSettings.set_setting(
			&"input/" + action, {"deadzone": 0.5, "events": [event]}
		)


func before_each() -> void:
	var scope := StdSettingsScope.new()
	scope.is_loaded = true

	_actions = DeviceActions.new()
	_actions.scope = scope
	_actions.claim_joy_input = false
	add_child_autofree(_actions)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _is_bound returns whether `action` has `key` among its events in the input map.
func _is_bound(action: StringName, key: Key) -> bool:
	return InputMap.action_get_events(action).any(
		func(event: InputEvent) -> bool:
			return event is InputEventKey and event.keycode == key
	)


## _make_action_set returns an action set called `id` declaring `actions`.
func _make_action_set(id: StringName, actions: Array[StringName]) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = id
	action_set.actions_digital = actions
	return action_set


## _make_layer returns a layer called `id` under `parent`, declaring `actions`.
func _make_layer(
	id: StringName, parent: StdInputActionSet, actions: Array[StringName]
) -> StdInputActionSetLayer:
	var layer := StdInputActionSetLayer.new()
	layer.name = id
	layer.parent = parent
	layer.actions_digital = actions
	return layer


## _send_action sends `Input` an injected press or release of `action`.
func _send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0

	Input.parse_input_event(event)
	Input.flush_buffered_events()


## _send_key sends `Input` a press or release of `key`, at `location` on the keyboard.
func _send_key(
	key: Key, pressed: bool, location: KeyLocation = KEY_LOCATION_UNSPECIFIED
) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.location = location
	event.pressed = pressed

	Input.parse_input_event(event)
	Input.flush_buffered_events()
