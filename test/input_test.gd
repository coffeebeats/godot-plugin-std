##
## Tests pertaining to the `StdTestInput` class. These double as the spike which found
## what a click at the headless root takes; `StdTestInput` documents the result.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

const _GUT_LAYER_PATH := ^"GutRunner/GutLayer"


## Records the input events left unhandled in its viewport.
class UnhandledInputRecorder:
	extends Node

	var events: Array[InputEvent] = []

	func _unhandled_input(event: InputEvent) -> void:
		events.append(event)


# -- INITIALIZATION ------------------------------------------------------------------ #

var _ui_accept_events: Array[InputEvent] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_click_mounted_button_presses_focuses_and_hovers_it(
	params = use_parameters(
		(
			ParameterFactory
			. named_parameters(
				["at_root", "position"],
				[
					[false, Vector2(10, 10)],
					[false, Vector2(400, 300)],
					# NOTE: This is under GUT's panel.
					[true, Vector2(10, 10)],
					# NOTE: This is beyond the headless root's own size.
					[true, Vector2(400, 300)],
				]
			)
		)
	)
) -> void:
	# Given: A button at the given position.
	var button := _make_button(params.position)
	var pressed := _count_pressed(button)

	# Given: The button is mounted.
	var input := await _mount(button, params.at_root)

	# When: The button is clicked.
	input.click(button)

	# Then: The click was picked as a real one is.
	assert_eq(pressed.size(), 1)
	assert_true(button.has_focus())
	assert_eq(input.viewport.gui_get_hovered_control(), button)


func test_click_overlapping_controls_picks_topmost(
	params = use_parameters([false, true])
) -> void:
	# Given: Two buttons in the same place, the second drawn over the first.
	var scene := Control.new()
	var back := _make_button(Vector2(100, 100))
	var front := _make_button(Vector2(100, 100))
	scene.add_child(back)
	scene.add_child(front)
	var back_pressed := _count_pressed(back)
	var front_pressed := _count_pressed(front)

	# Given: The buttons are mounted.
	var input := await _mount(scene, params)

	# When: The covered button is clicked.
	input.click(back)

	# Then: The button on top took the click.
	assert_eq(front_pressed.size(), 1)
	assert_eq(back_pressed.size(), 0)


func test_mount_container_child_lays_out_before_returning(
	params = use_parameters([false, true])
) -> void:
	# Given: A button with no size of its own, centered by a full-rect container.
	var container := CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	var button := Button.new()
	button.text = "Button"
	container.add_child(button)
	var pressed := _count_pressed(button)

	# When: The container is mounted.
	var input := await _mount(container, params)

	# Then: The container fills the viewport and centers the button.
	var visible_rect := input.viewport.get_visible_rect()
	assert_eq(container.size, visible_rect.size)
	assert_true(button.get_global_rect().has_point(visible_rect.get_center()))

	# When: The button is clicked.
	input.click(button)

	# Then: The click landed on it.
	assert_eq(pressed.size(), 1)


func test_mount_at_root_free_restores_root_and_gut_layer() -> void:
	# Given: The root's size and GUT's panel before mounting.
	var root := get_tree().root
	var size_before := root.size
	var gut_layer: CanvasLayer = root.get_node(_GUT_LAYER_PATH)
	assert_true(gut_layer.visible, "precondition: GUT's panel is shown")

	# Given: A scene mounted at the root.
	var input := StdTestInput.new()
	add_child(input)
	await input.mount_at_root(Control.new())

	# Then: The root is sized for the scene and GUT's panel is hidden.
	assert_eq(input.viewport, root)
	assert_eq(
		root.size.x, ProjectSettings.get_setting(&"display/window/size/viewport_width")
	)
	assert_false(gut_layer.visible)

	# When: The helper is freed.
	input.free()

	# Then: The root and GUT's panel are as they were.
	assert_eq(root.size, size_before)
	assert_true(gut_layer.visible)


func test_mount_free_frees_mounted_scene(
	params = use_parameters([false, true])
) -> void:
	# Given: A mounted scene.
	var scene := Control.new()
	var input := StdTestInput.new()
	add_child(input)
	if params:
		await input.mount_at_root(scene)
	else:
		await input.mount(scene)

	# When: The helper is freed.
	input.free()

	# Then: The scene is freed with it.
	assert_false(is_instance_valid(scene))


func test_press_action_focused_button_holds_action_and_presses_on_release(
	params = use_parameters([false, true])
) -> void:
	# Given: A mounted, focused button.
	var button := _make_button(Vector2(100, 100))
	var pressed := _count_pressed(button)
	var input := await _mount(button, params)
	button.grab_focus()

	# When: An action which activates the button is pressed.
	input.press_action(&"ui_accept")

	# Then: The action is held and the button hasn't fired yet.
	assert_true(Input.is_action_pressed(&"ui_accept"))
	assert_eq(pressed.size(), 0)

	# When: The action is released.
	input.release_action(&"ui_accept")

	# Then: The action is no longer held and the button fired.
	assert_false(Input.is_action_pressed(&"ui_accept"))
	assert_eq(pressed.size(), 1)


func test_press_action_held_at_free_is_released() -> void:
	# Given: A mounted scene with an action held.
	var input := StdTestInput.new()
	add_child(input)
	await input.mount(Control.new())
	input.press_action(&"ui_accept")
	assert_true(Input.is_action_pressed(&"ui_accept"), "precondition: action held")

	# When: The helper is freed.
	input.free()

	# Then: The action is no longer held.
	assert_false(Input.is_action_pressed(&"ui_accept"))


func test_press_key_focused_button_presses_on_release(
	params = use_parameters([false, true])
) -> void:
	# Given: A mounted, focused button.
	var button := _make_button(Vector2(100, 100))
	var pressed := _count_pressed(button)
	var input := await _mount(button, params)
	button.grab_focus()

	# When: A key bound to `ui_accept` is pressed and released.
	input.press_key(KEY_ENTER)
	input.release_key(KEY_ENTER)

	# Then: The button fired.
	assert_eq(pressed.size(), 1)


func test_press_key_with_nothing_focused_reaches_unhandled_input(
	params = use_parameters([false, true])
) -> void:
	# Given: A mounted scene recording unhandled input.
	var recorder := UnhandledInputRecorder.new()
	var input := await _mount(recorder, params)

	# When: A key is pressed and released.
	input.press_key(KEY_ESCAPE)
	input.release_key(KEY_ESCAPE)

	# Then: The recorder saw the press and then the release of that key.
	assert_eq(recorder.events.size(), 2)
	assert_eq(recorder.events[0].keycode, KEY_ESCAPE)
	assert_true(recorder.events[0].pressed)
	assert_eq(recorder.events[1].keycode, KEY_ESCAPE)
	assert_false(recorder.events[1].pressed)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	# NOTE: Other suites leave every action's bindings cleared, so bind this explicitly.
	_ui_accept_events = InputMap.action_get_events(&"ui_accept")
	InputMap.action_erase_events(&"ui_accept")

	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	InputMap.action_add_event(&"ui_accept", enter)


func after_each() -> void:
	InputMap.action_erase_events(&"ui_accept")
	for event in _ui_accept_events:
		InputMap.action_add_event(&"ui_accept", event)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _count_pressed returns an array which grows by one each time `button` is pressed.
func _count_pressed(button: BaseButton) -> Array[bool]:
	var pressed: Array[bool] = []
	button.pressed.connect(func() -> void: pressed.append(true))
	return pressed


func _make_button(position: Vector2) -> Button:
	var button := Button.new()
	button.position = position
	button.size = Vector2(100, 40)
	return button


## _mount adds a helper which is freed with the test and mounts `scene` with it, at the
## root when `at_root` is set.
func _mount(scene: Node, at_root: bool) -> StdTestInput:
	var input: StdTestInput = add_child_autofree(StdTestInput.new())

	if at_root:
		await input.mount_at_root(scene)
	else:
		await input.mount(scene)

	return input
