# gdlint:ignore=max-public-methods
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

## _JOYPAD_MONITOR_PATH is the joypad monitor script, loaded as `_DEVICE_ACTIONS_PATH`.
const _JOYPAD_MONITOR_PATH := "joypad_monitor.gd"

## _STEAM_ERROR is the condition GodotSteam reports when it rejects a call because
## Steam Input isn't running, as under test.
const _STEAM_ERROR := "SteamAPI_SteamInput() == nullptr"

## _TEST_HANDLE is the Steam handle of the controller connected in slot 0.
const _TEST_HANDLE := 7

## _TEST_SET_HANDLES are the handles of the test sets and layers in the manifest.
const _TEST_SET_HANDLES := {
	&"Menu": 1,
	&"Gameplay": 2,
	&"Tabs": 3,
	&"Options_Menu": 4,
	&"Options_Gameplay": 5,
}

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
var _joypad_monitor: Variant = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_get_action_for_event_resolves_a_handle_by_the_event_type() -> void:
	# Given: A digital action and an analog action which share a handle, as Steam
	# numbers each kind separately.
	_device_actions._digital_actions[1] = &"move_up"
	_device_actions._analog_actions[1] = &"move"

	# When/Then: The event type picks the action, and an unknown handle has no name.
	assert_eq(
		_device_actions.get_action_for_event(
			Steam.INPUT_ACTION_EVENT_TYPE_DIGITAL_ACTION, 1
		),
		&"move_up",
	)
	assert_eq(
		_device_actions.get_action_for_event(
			Steam.INPUT_ACTION_EVENT_TYPE_ANALOG_ACTION, 1
		),
		&"move",
	)
	assert_eq(
		_device_actions.get_action_for_event(
			Steam.INPUT_ACTION_EVENT_TYPE_DIGITAL_ACTION, 2
		),
		&"",
	)


func test_get_action_handles_keep_a_shared_handle_per_kind() -> void:
	# Given: A digital action and an analog action whose handles are known and equal.
	_device_actions._is_initialized = true
	_device_actions._digital_action_handles[&"move_up"] = 1
	_device_actions._analog_action_handles[&"move"] = 1

	# When: Each handle is fetched again.
	var digital: int = _device_actions.get_digital_action_handle(&"move_up")
	var analog: int = _device_actions.get_analog_action_handle(&"move")

	# Then: Both are found, and each kind maps the handle back to its own action.
	assert_eq(digital, 1)
	assert_eq(analog, 1)
	assert_eq(_device_actions._digital_actions[1], &"move_up")
	assert_eq(_device_actions._analog_actions[1], &"move")


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


func test_exit_tree_releases_every_held_action() -> void:
	# Given: The component's dependencies, which it disconnects from on exit.
	_actions.joypad_monitor = autofree(_joypad_monitor.new())
	_actions.steam_input_enabled_property = StdSettingsPropertyBool.new()
	_actions.steam_input_enabled_property.scope = StdSettingsScope.new()

	# Given: Joypads in slots 0 and 1 each hold a direction.
	_publish(_action(&"move_left", 1.0, true))

	var event := _action(&"move_right", 1.0, true)
	event.device = 1
	_publish(event)

	assert_true(Input.is_action_pressed(&"move_left"), "precondition: pressed")
	assert_true(Input.is_action_pressed(&"move_right"), "precondition: pressed")

	# When: The component leaves the scene, after which Steam reports nothing to it.
	_actions._exit_tree()
	Input.flush_buffered_events()

	# Then: Every direction is released and no slot's state is kept.
	assert_false(Input.is_action_pressed(&"move_left"))
	assert_false(Input.is_action_pressed(&"move_right"))
	assert_true(_actions._held.is_empty())


func test_exit_tree_keeps_the_recorded_stack_of_a_connected_joypad() -> void:
	# Given: A controller connected in slot 0.
	_connect_joypad()

	# Given: The settings property the component disconnects from on exit.
	_actions.steam_input_enabled_property = StdSettingsPropertyBool.new()
	_actions.steam_input_enabled_property.scope = StdSettingsScope.new()

	# Given: An action set loaded for the controller.
	var menu := _make_action_set(&"Menu")
	_actions.load_action_set(0, menu)
	_list_steam_calls()

	# Given: The controller holds a direction.
	_publish(_action(&"move_left", 1.0, true))

	# When: The component leaves the scene while the controller stays connected.
	_actions._exit_tree()
	Input.flush_buffered_events()

	# Then: The direction is released.
	assert_false(Input.is_action_pressed(&"move_left"))

	# Then: The controller's set is still recorded.
	assert_eq(_actions.get_action_set(0), menu)


func test_load_action_set_reports_the_recorded_set_at_once() -> void:
	# Given: A controller connected in slot 0.
	_connect_joypad()
	var menu := _make_action_set(&"Menu")

	# When: An action set is loaded.
	var got: bool = _actions.load_action_set(0, menu)

	# Then: The load reports a change.
	assert_true(got)

	# Then: The set reads back in the same frame.
	assert_eq(_actions.get_action_set(0), menu)

	# Then: Steam drops every layer and activates the set.
	assert_eq(
		_list_steam_calls(), ["deactivateAllActionSetLayers", "activateActionSet"]
	)

	# When: The same action set is loaded again.
	got = _actions.load_action_set(0, menu)

	# Then: No change is reported.
	assert_false(got)

	# Then: Steam isn't called.
	assert_eq(_list_steam_calls(), [])


func test_enable_action_set_layer_reports_the_recorded_layer_at_once() -> void:
	# Given: A controller connected in slot 0.
	_connect_joypad()

	# Given: An action set loaded for the controller.
	var menu := _make_action_set(&"Menu")
	_actions.load_action_set(0, menu)
	_list_steam_calls()

	# When: A layer is enabled.
	var tabs := _make_layer(&"Tabs", menu)
	var got: bool = _actions.enable_action_set_layer(0, tabs)

	# Then: The enable reports a change.
	assert_true(got)

	# Then: The layer reads back in the same frame.
	assert_eq(
		_actions.list_action_set_layers(0), [tabs] as Array[StdInputActionSetLayer]
	)

	# Then: Steam is given the set and its layers afresh.
	assert_eq(
		_list_steam_calls(),
		["deactivateAllActionSetLayers", "activateActionSet", "activateActionSetLayer"],
	)

	# When: The same layer is enabled again.
	got = _actions.enable_action_set_layer(0, tabs)

	# Then: No change is reported.
	assert_false(got)

	# Then: Steam isn't called.
	assert_eq(_list_steam_calls(), [])


func test_layer_disabled_and_enabled_in_one_frame_stays_enabled() -> void:
	# Given: A controller connected in slot 0.
	_connect_joypad()

	# Given: An action set loaded with a layer enabled.
	var menu := _make_action_set(&"Menu")
	var tabs := _make_layer(&"Tabs", menu)
	_actions.load_action_set(0, menu)
	_actions.enable_action_set_layer(0, tabs)
	_list_steam_calls()

	# When: The layer is disabled and enabled again in the same frame.
	assert_true(_actions.disable_action_set_layer(0, tabs))
	assert_true(_actions.enable_action_set_layer(0, tabs))

	# Then: The layer is enabled.
	assert_eq(
		_actions.list_action_set_layers(0), [tabs] as Array[StdInputActionSetLayer]
	)

	# Then: The last stack Steam was given holds the layer.
	assert_eq(_list_steam_calls().back(), "activateActionSetLayer")


func test_load_action_set_drops_the_recorded_layers() -> void:
	# Given: A controller connected in slot 0.
	_connect_joypad()

	# Given: An action set loaded with a layer enabled.
	var menu := _make_action_set(&"Menu")
	_actions.load_action_set(0, menu)
	_actions.enable_action_set_layer(0, _make_layer(&"Tabs", menu))
	_list_steam_calls()

	# When: Another action set is loaded.
	var gameplay := _make_action_set(&"Gameplay")
	assert_true(_actions.load_action_set(0, gameplay))

	# Then: The new set is recorded with no layers.
	assert_eq(_actions.get_action_set(0), gameplay)
	assert_eq(_actions.list_action_set_layers(0), [] as Array[StdInputActionSetLayer])

	# Then: Steam is given the new set with no layers.
	assert_eq(
		_list_steam_calls(), ["deactivateAllActionSetLayers", "activateActionSet"]
	)


func test_resolve_action_set_name_reads_the_recorded_set() -> void:
	# Given: A controller connected in slot 0.
	_connect_joypad()

	# Given: The `Gameplay` set loaded for the controller.
	_actions.load_action_set(0, _make_action_set(&"Gameplay"))
	_list_steam_calls()

	# When/Then: A layer with no parent resolves to its copy under `Gameplay`.
	var options := _make_layer(&"Options", null)
	assert_eq(_device_actions.resolve_action_set_name(options, 0), &"Options_Gameplay")

	# When/Then: A slot with nothing recorded keeps the layer's own name.
	assert_eq(_device_actions.resolve_action_set_name(options, 1), &"Options")

	# When/Then: A layer with a parent keeps its own name.
	var tabs := _make_layer(&"Tabs", _make_action_set(&"Menu"))
	assert_eq(_device_actions.resolve_action_set_name(tabs, 0), &"Tabs")


func test_is_applied_compares_the_reported_stack_in_order() -> void:
	# Given: A controller connected in slot 0.
	_connect_joypad()

	# Given: The `Menu` set loaded with two layers enabled.
	var menu := _make_action_set(&"Menu")
	_actions.load_action_set(0, menu)
	_actions.enable_action_set_layer(0, _make_layer(&"Options", null))
	_actions.enable_action_set_layer(0, _make_layer(&"Tabs", menu))
	_list_steam_calls()

	# When/Then: The recorded set with its layers in stack order is applied.
	assert_true(_device_actions._is_applied(0, 1, [4, 3]))

	# When/Then: A set with no layers, as a configuration load leaves, isn't.
	assert_false(_device_actions._is_applied(0, 1, []))

	# When/Then: Another set isn't, nor the layers out of order.
	assert_false(_device_actions._is_applied(0, 2, [4, 3]))
	assert_false(_device_actions._is_applied(0, 1, [3, 4]))

	# When/Then: A slot with nothing recorded holds anything.
	assert_true(_device_actions._is_applied(1, 0, []))


func test_process_applies_the_stack_again_once_steam_drops_it() -> void:
	# Given: A controller connected in slot 0.
	_connect_joypad()

	# Given: An action set loaded with a layer enabled.
	var menu := _make_action_set(&"Menu")
	_actions.load_action_set(0, menu)
	_actions.enable_action_set_layer(0, _make_layer(&"Tabs", menu))
	_list_steam_calls()

	# When: A frame is processed right after the stack was applied.
	_actions._process(0.0)

	# Then: Steam isn't read back, since it reports a change a frame late.
	assert_eq(_list_steam_calls(), [])

	# When: Two frames pass, and Steam reports no set or layers.
	await wait_process_frames(2)
	_actions._process(0.0)

	# Then: Steam is read back, then given the set and its layers afresh.
	assert_eq(
		_list_steam_calls(),
		[
			"getCurrentActionSet",
			"getActiveActionSetLayers",
			"deactivateAllActionSetLayers",
			"activateActionSet",
			"activateActionSetLayer",
		],
	)

	# When: The next frame is processed.
	_actions._process(0.0)

	# Then: Steam isn't read back yet.
	assert_eq(_list_steam_calls(), [])


func test_configuration_load_applies_the_stack_at_once() -> void:
	# Given: A controller connected in slot 0.
	_connect_joypad()

	# Given: An action set loaded for the controller this frame.
	_actions.load_action_set(0, _make_action_set(&"Menu"))
	_list_steam_calls()

	# Given: The component's signals are watched.
	watch_signals(_actions)

	# When: Steam loads the controller's configuration in the same frame.
	_actions._on_input_configuration_loaded(480, _TEST_HANDLE, {})

	# Then: Steam is given the set again.
	assert_eq(
		_list_steam_calls(), ["deactivateAllActionSetLayers", "activateActionSet"]
	)

	# Then: The bindings are reported changed.
	assert_signal_emitted(_actions, "bindings_changed")

	# When: Steam loads another controller's configuration.
	_actions._on_input_configuration_loaded(480, _TEST_HANDLE + 1, {})

	# Then: Steam isn't given anything.
	assert_eq(_list_steam_calls(), [])


func test_joypad_disconnect_forgets_the_recorded_stack() -> void:
	# Given: A controller connected in slot 0.
	_connect_joypad()

	# Given: An action set loaded for the controller.
	_actions.load_action_set(0, _make_action_set(&"Menu"))
	_list_steam_calls()

	# When: The controller disconnects.
	_actions._on_joypad_disconnected(0)

	# Then: Nothing is recorded for the slot.
	assert_null(_actions.get_action_set(0))

	# When: Two frames pass, and a frame is processed.
	await wait_process_frames(2)
	_actions._process(0.0)

	# Then: Steam isn't called.
	assert_eq(_list_steam_calls(), [])


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

	# NOTE: The handle maps and stacks are static, so a test's entries are dropped here.
	_device_actions._is_initialized = false
	_device_actions._action_set_handles.clear()
	_device_actions._actions_seen_action_sets.clear()
	_device_actions._analog_actions.clear()
	_device_actions._analog_action_handles.clear()
	_device_actions._digital_actions.clear()
	_device_actions._digital_action_handles.clear()
	_device_actions._stacks.clear()


func before_all() -> void:
	var path: String = get_script().resource_path.get_base_dir().path_join(
		_DEVICE_ACTIONS_PATH
	)
	_device_actions = load(path)
	_joypad_monitor = load(path.get_base_dir().path_join(_JOYPAD_MONITOR_PATH))

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


## _connect_joypad gives the component a joypad monitor with the controller
## `_TEST_HANDLE` connected in slot 0, and a manifest holding `_TEST_SET_HANDLES`.
func _connect_joypad() -> void:
	var monitor: StdInputSlot.JoypadMonitor = autofree(_joypad_monitor.new())
	monitor._connected = PackedInt64Array([_TEST_HANDLE])
	_actions.joypad_monitor = monitor

	_device_actions._is_initialized = true
	_device_actions._action_set_handles.merge(_TEST_SET_HANDLES)


## _list_steam_calls returns the name of each Steam Input call made since it was last
## called, in order. GodotSteam rejects each call while Steam Input isn't running, with
## an error naming it, which this marks as expected.
func _list_steam_calls() -> Array[String]:
	var calls: Array[String] = []

	for error in get_errors():
		if error.handled or not error.contains_text(_STEAM_ERROR):
			continue

		error.handled = true
		calls.append(error.rationale.get_slice(": ", 1))

	return calls


## _make_action_set returns an action set called `id` declaring no actions.
func _make_action_set(id: StringName) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = id
	return action_set


## _make_layer returns a layer called `id` under `parent`, declaring no actions.
func _make_layer(id: StringName, parent: StdInputActionSet) -> StdInputActionSetLayer:
	var layer := StdInputActionSetLayer.new()
	layer.name = id
	layer.parent = parent
	return layer


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
