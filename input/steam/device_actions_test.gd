##
## std/input/steam/device_actions_test.gd
##
## Tests pertaining to the Steam implementation of `StdInputDeviceActions`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SteamDeviceActions := preload("device_actions.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _TEST_ACTIONS are the directional actions of the `move` stick, registered in the
## `InputMap` with `_TEST_DEADZONE`.
const _TEST_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down"
]

## _TEST_DEADZONE is the deadzone of the registered test actions.
const _TEST_DEADZONE := 0.2

## _TEST_KEY is the key bound to `move_right`.
const _TEST_KEY := KEY_D

# -- INITIALIZATION ------------------------------------------------------------------ #

var _actions: SteamDeviceActions = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_split_analog_2d_presses_each_direction_past_its_deadzone() -> void:
	# When: A stick deflected left and up is split for the `move` action on slot 0.
	var got := SteamDeviceActions.split_analog_2d(&"move", Vector2(-0.5, 0.25), 0)

	# Then: The four directional actions are in `Input.get_vector` order.
	assert_eq(
		got.map(func(e): return e.action),
		[&"move_left", &"move_right", &"move_up", &"move_down"],
	)

	# Then: Each carries the strength of its half of the axis and is pressed past the
	# action's deadzone.
	assert_eq(got.map(func(e): return e.strength), [0.5, 0.0, 0.25, 0.0])
	assert_eq(got.map(func(e): return e.pressed), [true, false, true, false])

	# Then: Each carries the slot and names no bound event.
	for event in got:
		assert_eq(event.device, 0)
		assert_eq(event.event_index, -1)


func test_split_analog_2d_presses_an_unknown_action_from_half_strength() -> void:
	# When: A stick deflected up is split for an action the `InputMap` doesn't know.
	var got := SteamDeviceActions.split_analog_2d(&"look", Vector2(0.0, 0.25), 0)

	# Then: The direction is released below half strength.
	assert_eq(got.map(func(e): return e.pressed), [false, false, false, false])


func test_get_press_threshold_reads_the_input_map_deadzone() -> void:
	# When/Then: A registered action's threshold is its deadzone, and an unknown
	# action's is half strength.
	assert_almost_eq(
		SteamDeviceActions.get_press_threshold(&"move_up"), _TEST_DEADZONE, 0.001
	)
	assert_eq(SteamDeviceActions.get_press_threshold(&"unknown"), 0.5)


func test_publish_input_event_presses_an_action_once_per_state_change() -> void:
	# When: A direction is published pressed twice at the same strength.
	_publish(_action(&"move_up", 0.75, true))
	_publish(_action(&"move_up", 0.75, true))

	# Then: The action is pressed at that strength.
	assert_true(Input.is_action_pressed(&"move_up"))
	assert_eq(Input.get_action_strength(&"move_up"), 0.75)

	# When: A frame passes and the still-held direction is published again.
	await wait_process_frames(1)
	_publish(_action(&"move_up", 0.75, true))

	# Then: The action isn't just pressed again.
	assert_false(Input.is_action_just_pressed(&"move_up"))

	# When: The direction is published released, then released again a frame later.
	_publish(_action(&"move_up", 0.0, false))
	await wait_process_frames(1)
	_publish(_action(&"move_up", 0.0, false))

	# Then: The action is released, but not just released again.
	assert_false(Input.is_action_pressed(&"move_up"))
	assert_false(Input.is_action_just_released(&"move_up"))


func test_publish_input_event_skips_a_release_of_an_unpressed_action() -> void:
	# Given: A frame in which nothing was published.
	await wait_process_frames(1)

	# When: A direction which was never pressed is published released.
	_publish(_action(&"move_down", 0.0, false))

	# Then: The action doesn't read as just released.
	assert_false(Input.is_action_just_released(&"move_down"))


func test_publish_input_event_release_keeps_a_key_held_for_the_action() -> void:
	# Given: The key bound to a direction is held.
	var key := InputEventKey.new()
	key.keycode = _TEST_KEY
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	assert_true(Input.is_action_pressed(&"move_right"), "precondition: key held")

	# When: A stick presses and then releases the same direction.
	_publish(_action(&"move_right", 1.0, true))
	_publish(_action(&"move_right", 0.0, false))

	# Then: The action is still pressed by the key.
	assert_true(Input.is_action_pressed(&"move_right"))

	# Cleanup: The key is released, with a new event since one can't be parsed twice.
	var release := InputEventKey.new()
	release.keycode = _TEST_KEY
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func test_joypad_disconnect_releases_the_actions_it_held() -> void:
	# Given: A joypad in slot 0 holds a direction.
	_publish(_action(&"move_left", 1.0, true))
	assert_true(Input.is_action_pressed(&"move_left"), "precondition: pressed")

	# When: The joypad disconnects.
	_actions._on_joypad_disconnected(0)
	Input.flush_buffered_events()

	# Then: The direction is released and the slot's state is forgotten.
	assert_false(Input.is_action_pressed(&"move_left"))
	assert_false(_actions._published.has(0))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _TEST_ACTIONS:
		InputMap.erase_action(action)


func after_each() -> void:
	# NOTE: Any action left pressed is released, so a test can't leak into the next.
	for action in _TEST_ACTIONS:
		Input.action_release(action)


func before_all() -> void:
	for action in _TEST_ACTIONS:
		InputMap.add_action(action, _TEST_DEADZONE)

	var key := InputEventKey.new()
	key.keycode = _TEST_KEY
	InputMap.action_add_event(&"move_right", key)


func before_each() -> void:
	# NOTE: The component isn't added to the scene, since its `_ready` needs Steam Input;
	# publishing only touches `Input` and the instance's own state.
	_actions = autofree(SteamDeviceActions.new())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _action returns an injected action event for `action` on slot 0.
func _action(action: StringName, strength: float, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.device = 0
	event.strength = strength
	event.pressed = pressed
	return event


## _publish publishes `event` through the component and flushes `Input`, which buffers
## parsed events until the next frame.
func _publish(event: InputEventAction) -> void:
	_actions._publish_input_event(event)
	Input.flush_buffered_events()
