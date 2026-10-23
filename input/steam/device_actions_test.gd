##
## std/input/steam/device_actions_test.gd
##
## Tests pertaining to the Steam implementation of `StdInputDeviceActions`.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

## _DEVICE_ACTIONS_PATH is the component script, loaded in `before_all` rather than
## preloaded, since it can't be parsed without the `Steam` singleton the GodotSteam
## extension registers and `should_skip_script` skips this script without it.
const _DEVICE_ACTIONS_PATH := "device_actions.gd"

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

var _actions: StdInputDeviceActions = null
var _device_actions: Variant = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_split_analog_2d_presses_each_direction_the_stick_deflects() -> void:
	# When: A stick deflected left, and up inside the deadzone, is split for slot 0.
	var got: Array[InputEventAction] = _device_actions.split_analog_2d(
		&"move", Vector2(-0.5, 0.125), 0
	)

	# Then: The four directional actions are in `Input.get_vector` order.
	assert_eq(
		got.map(func(e): return e.action),
		[&"move_left", &"move_right", &"move_up", &"move_down"],
	)

	# Then: Each carries the strength of its half of the axis.
	assert_eq(got.map(func(e): return e.strength), [0.5, 0.0, 0.125, 0.0])

	# Then: Each is pressed at any strength, since Steam applied its own deadzone.
	assert_eq(got.map(func(e): return e.pressed), [true, false, true, false])

	# Then: Each carries the slot and names no bound event.
	for event in got:
		assert_eq(event.device, 0)
		assert_eq(event.event_index, -1)


func test_clear_stick_deadzones_lasts_until_steam_input_stops() -> void:
	# Given: An action set whose `move` stick drives the test actions.
	var action_set := _make_stick_action_set()

	# When: Steam Input takes over the stick's deadzone.
	_device_actions._clear_stick_deadzones(action_set)

	# Then: Each direction's deadzone is all but zero.
	for action in _TEST_ACTIONS:
		assert_almost_eq(InputMap.action_get_deadzone(action), 0.0, 0.0001)

	# When: Steam Input stops.
	_actions._on_steam_input_state_changed(false)

	# Then: Each direction's deadzone is the one it had before.
	for action in _TEST_ACTIONS:
		assert_almost_eq(InputMap.action_get_deadzone(action), _TEST_DEADZONE, 0.0001)


func test_get_vector_reads_a_steam_stick_without_a_second_deadzone() -> void:
	# Given: Steam Input has taken over the `move` stick's deadzone.
	_device_actions._clear_stick_deadzones(_make_stick_action_set())

	# When: The stick is deflected right and up inside the test actions' deadzone.
	for event in _device_actions.split_analog_2d(&"move", Vector2(0.125, 0.125), 0):
		_publish(event)

	# Then: `Input.get_vector` reads the deflection as Steam reported it.
	var got := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	assert_almost_eq(got.x, 0.125, 0.001)
	assert_almost_eq(got.y, -0.125, 0.001)


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
	assert_false(_actions._held.has(0))


func test_publish_input_event_holds_an_action_at_its_strongest_source() -> void:
	# Given: A stick holds a direction at half strength.
	_publish(_action(&"move_left", 0.5, true), &"move")

	# When: A button bound to the same direction is pressed.
	_publish(_action(&"move_left", 1.0, true), &"move_left")

	# Then: The action is pressed at the button's strength.
	assert_eq(Input.get_action_strength(&"move_left"), 1.0)

	# When: The stick returns to rest.
	_publish(_action(&"move_left", 0.0, false), &"move")

	# Then: The action is still pressed by the button.
	assert_true(Input.is_action_pressed(&"move_left"))
	assert_eq(Input.get_action_strength(&"move_left"), 1.0)

	# When: The stick is deflected again and the button is released.
	_publish(_action(&"move_left", 0.25, true), &"move")
	_publish(_action(&"move_left", 0.0, false), &"move_left")

	# Then: The action is pressed at the stick's strength.
	assert_true(Input.is_action_pressed(&"move_left"))
	assert_eq(Input.get_action_strength(&"move_left"), 0.25)

	# When: The stick returns to rest.
	_publish(_action(&"move_left", 0.0, false), &"move")

	# Then: The action is released.
	assert_false(Input.is_action_pressed(&"move_left"))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _TEST_ACTIONS:
		InputMap.erase_action(action)


func after_each() -> void:
	# NOTE: Any action left pressed is released, and any deadzone Steam took over is
	# restored, so a test can't leak into the next.
	for action in _TEST_ACTIONS:
		Input.action_release(action)

	_device_actions._restore_stick_deadzones()


func before_all() -> void:
	var path: String = get_script().resource_path.get_base_dir().path_join(
		_DEVICE_ACTIONS_PATH
	)
	_device_actions = load(path)

	for action in _TEST_ACTIONS:
		InputMap.add_action(action, _TEST_DEADZONE)

	var key := InputEventKey.new()
	key.keycode = _TEST_KEY
	InputMap.action_add_event(&"move_right", key)


func before_each() -> void:
	# NOTE: The component isn't added to the scene, since its `_ready` needs Steam Input;
	# publishing only touches `Input` and the instance's own state.
	_actions = autofree(_device_actions.new())


func should_skip_script():
	if not ClassDB.class_exists(&"Steam"):
		return "the GodotSteam extension isn't available on this platform"

	return false


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _action returns an injected action event for `action` on slot 0.
func _action(action: StringName, strength: float, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.device = 0
	event.strength = strength
	event.pressed = pressed
	return event


## _make_stick_action_set returns an action set whose `move` stick drives the test
## actions.
func _make_stick_action_set() -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.actions_analog_2d = [&"move"] as Array[StringName]
	action_set.actions_digital = _TEST_ACTIONS.duplicate()
	return action_set


## _publish publishes `event` through the component as pressed by the Steam action
## `source`, and flushes `Input`, which buffers parsed events until the next frame.
func _publish(event: InputEventAction, source: StringName = &"move") -> void:
	_actions._publish_input_event(event, source)
	Input.flush_buffered_events()
