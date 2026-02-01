##
## Tests pertaining to the `StdInputActionSet` and `StdInputActionSetLayer` classes.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var action_set: StdInputActionSet = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_list_action_names_returns_all_action_types() -> void:
	# Given: An action set with actions of each type.
	action_set.actions_analog_1d = [&"throttle", &"brake"]
	action_set.actions_analog_2d = [&"move", &"look"]
	action_set.actions_digital = [&"jump", &"fire"]

	# When: Action names are listed.
	var got := action_set.list_action_names()

	# Then: All actions are returned in order (analog_1d, analog_2d, digital).
	assert_eq(
		got,
		PackedStringArray([&"throttle", &"brake", &"move", &"look", &"jump", &"fire"]),
	)


func test_list_action_names_handles_absolute_mouse(
	params = use_parameters(
		ParameterFactory.named_parameters(
			["include_absolute_mouse", "expected"],
			[
				[false, PackedStringArray([&"jump"])],
				[true, PackedStringArray([&"jump", &"mouse_aim"])],
			]
		)
	)
) -> void:
	# Given: An action set with an absolute mouse action.
	action_set.actions_digital = [&"jump"]
	action_set.action_absolute_mouse = &"mouse_aim"

	# When: Action names are listed with the specified flag.
	var got := action_set.list_action_names(params.include_absolute_mouse)

	# Then: The expected actions are returned.
	assert_eq(got, params.expected)


func test_list_action_names_returns_empty_for_empty_action_set() -> void:
	# Given: An empty action set.

	# When: Action names are listed.
	var got := action_set.list_action_names()

	# Then: An empty array is returned.
	assert_eq(got, PackedStringArray())


func test_is_matching_event_origin_rejects_mouse_motion() -> void:
	# Given: An action set with a digital action.
	action_set.actions_digital = [&"jump"]

	# Given: A mouse motion event.
	var event := InputEventMouseMotion.new()

	# When: The event is checked against the action.
	var got := action_set.is_matching_event_origin(&"jump", event)

	# Then: Mouse motion is rejected (fast-tracked).
	assert_false(got)


func test_is_matching_event_origin_matches_digital_actions() -> void:
	# Given: An action set with a digital action.
	action_set.actions_digital = [&"jump"]

	# Given: Various digital input events.
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_SPACE

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT

	var joy_button_event := InputEventJoypadButton.new()
	joy_button_event.button_index = JOY_BUTTON_A

	# When/Then: Digital events match digital actions.
	assert_true(action_set.is_matching_event_origin(&"jump", key_event))
	assert_true(action_set.is_matching_event_origin(&"jump", mouse_event))
	assert_true(action_set.is_matching_event_origin(&"jump", joy_button_event))


func test_is_matching_event_origin_matches_analog_1d_actions() -> void:
	# Given: An action set with a 1D analog action.
	action_set.actions_analog_1d = [&"throttle"]

	# Given: A trigger axis event.
	var trigger_event := InputEventJoypadMotion.new()
	trigger_event.axis = JOY_AXIS_TRIGGER_LEFT
	trigger_event.axis_value = 0.5

	# When/Then: Trigger axis matches 1D analog actions.
	assert_true(action_set.is_matching_event_origin(&"throttle", trigger_event))

	# Given: A stick axis event (not a trigger).
	var stick_event := InputEventJoypadMotion.new()
	stick_event.axis = JOY_AXIS_LEFT_X
	stick_event.axis_value = 0.5

	# When/Then: Stick axis does not match 1D analog actions.
	assert_false(action_set.is_matching_event_origin(&"throttle", stick_event))


func test_is_matching_event_origin_matches_analog_2d_actions() -> void:
	# Given: An action set with a 2D analog action.
	action_set.actions_analog_2d = [&"move"]

	# Given: A stick axis event.
	var stick_event := InputEventJoypadMotion.new()
	stick_event.axis = JOY_AXIS_LEFT_X
	stick_event.axis_value = 0.5

	# When/Then: Stick axis matches 2D analog actions.
	assert_true(action_set.is_matching_event_origin(&"move", stick_event))

	# Given: A trigger axis event.
	var trigger_event := InputEventJoypadMotion.new()
	trigger_event.axis = JOY_AXIS_TRIGGER_LEFT
	trigger_event.axis_value = 0.5

	# When/Then: Trigger axis does not match 2D analog actions.
	assert_false(action_set.is_matching_event_origin(&"move", trigger_event))


func test_is_matching_event_origin_allows_stick_axis_for_digital_actions() -> void:
	# Given: An action set with a digital action.
	action_set.actions_digital = [&"menu_up"]

	# Given: A stick axis event.
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = -1.0

	# When/Then: Stick axis can match digital actions (for d-pad emulation).
	assert_true(action_set.is_matching_event_origin(&"menu_up", event))


func test_is_matching_event_origin_returns_false_for_unknown_action() -> void:
	# Given: An action set with a digital action.
	action_set.actions_digital = [&"jump"]

	# Given: A key event.
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE

	# When: The event is checked against an unknown action.
	var got := action_set.is_matching_event_origin(&"unknown_action", event)

	# Then: The check returns false.
	assert_false(got)


func test_action_set_layer_has_parent_reference() -> void:
	# Given: An action set and a layer.
	var layer: StdInputActionSetLayer = autofree(StdInputActionSetLayer.new())

	# Given: The layer's parent is set.
	layer.parent = action_set

	# Then: The parent reference is correct.
	assert_eq(layer.parent, action_set)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	action_set = StdInputActionSet.new()
	action_set.name = &"test-action-set"


func after_each() -> void:
	action_set = null
