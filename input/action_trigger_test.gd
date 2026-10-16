##
## std/input/action_trigger_test.gd
##
## Tests pertaining to `StdInputActionTrigger`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const _TEST_ACTION := &"test_trigger"


## _InputRecorder records each press and release of the test action it receives, with
## whether the action read as just pressed when the event arrived.
class _InputRecorder:
	extends Node

	var seen: Array[bool] = []
	var just_pressed: Array[bool] = []

	func _input(event: InputEvent) -> void:
		if not event.is_action(_TEST_ACTION):
			return

		seen.append(event.is_pressed())
		just_pressed.append(Input.is_action_just_pressed(_TEST_ACTION))


## _Actions is a device actions component that holds whatever it is handed.
class _Actions:
	extends StdInputDeviceActions

	var action_set: StdInputActionSet = null
	var layers: Array[StdInputActionSetLayer] = []

	func _get_action_set(_device: int) -> StdInputActionSet:
		return action_set

	func _load_action_set(_device: int, next: StdInputActionSet) -> bool:
		if next == action_set:
			return false
		action_set = next
		layers = []
		return true

	func _disable_action_set_layer(_device: int, layer: StdInputActionSetLayer) -> bool:
		if layer not in layers:
			return false
		layers.erase(layer)
		return true

	func _enable_action_set_layer(_device: int, layer: StdInputActionSetLayer) -> bool:
		if layer in layers:
			return false
		layers.append(layer)
		return true

	func _list_action_set_layers(_device: int) -> Array[StdInputActionSetLayer]:
		return layers.duplicate()


# -- INITIALIZATION ------------------------------------------------------------------ #

var _recorder: _InputRecorder = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_action_trigger_pressed_raises_press_then_release() -> void:
	# Given: A button with a trigger for the test action, in a tree with no input slot.
	var button := _add_button()

	# When: The button is pressed.
	button.pressed.emit()
	await wait_idle_frames(2)

	# Then: The handler saw a press and then a release.
	assert_eq(_recorder.seen, [true, false] as Array[bool])

	# Then: The action read as just pressed as each arrived.
	assert_eq(_recorder.just_pressed, [true, true] as Array[bool])

	# Then: The action is not left pressed.
	assert_false(Input.is_action_pressed(_TEST_ACTION))


func test_action_trigger_pressed_with_action_declared_on_slot_raises_it() -> void:
	# Given: An input slot for player 1 whose loaded action set declares the action.
	var slot := _add_slot()
	var action_set := StdInputActionSet.new()
	action_set.name = &"Test"
	action_set.actions_digital = [_TEST_ACTION] as Array[StringName]
	assert_true(slot.load_action_set(action_set))

	# Given: A button with a trigger for the test action.
	var button := _add_button()

	# When: The button is pressed.
	button.pressed.emit()
	await wait_idle_frames(2)

	# Then: The handler saw a press and then a release.
	assert_eq(_recorder.seen, [true, false] as Array[bool])


func test_action_trigger_pressed_with_action_declared_on_layer_raises_it() -> void:
	# Given: An input slot for player 1 whose loaded action set declares nothing.
	var slot := _add_slot()
	var action_set := StdInputActionSet.new()
	action_set.name = &"Test"
	assert_true(slot.load_action_set(action_set))

	# Given: An enabled layer declares the action.
	var layer := StdInputActionSetLayer.new()
	layer.name = &"TestLayer"
	layer.parent = action_set
	layer.actions_digital = [_TEST_ACTION] as Array[StringName]
	assert_true(slot.enable_action_set_layer(layer))

	# Given: A button with a trigger for the test action.
	var button := _add_button()

	# When: The button is pressed.
	button.pressed.emit()
	await wait_idle_frames(2)

	# Then: The handler saw a press and then a release.
	assert_eq(_recorder.seen, [true, false] as Array[bool])


func test_action_trigger_pressed_with_action_on_another_slot_raises_it() -> void:
	# Given: Player 1's slot loads an action set that lacks the action.
	var first := _add_slot(1)
	var menu := StdInputActionSet.new()
	menu.name = &"Menu"
	assert_true(first.load_action_set(menu))

	# Given: Player 2's slot loads an action set that declares the action.
	var second := _add_slot(2, first.cursor)
	var action_set := StdInputActionSet.new()
	action_set.name = &"Test"
	action_set.actions_digital = [_TEST_ACTION] as Array[StringName]
	assert_true(second.load_action_set(action_set))

	# Given: A button with a trigger for the test action.
	var button := _add_button()

	# When: The button is pressed.
	button.pressed.emit()
	await wait_idle_frames(2)

	# Then: The handler saw a press and then a release.
	assert_eq(_recorder.seen, [true, false] as Array[bool])


func test_action_trigger_press_mode_button_holds_action_until_released() -> void:
	# Given: A press-mode button held down by the mouse.
	var parts := await _hold_button()
	var viewport: SubViewport = parts[0]

	# When: The mouse releases the button.
	viewport.push_input(_mouse_left(false))
	await wait_idle_frames(2)

	# Then: The handler saw the release.
	assert_eq(_recorder.seen, [true, false] as Array[bool])

	# Then: The action is no longer pressed.
	assert_false(Input.is_action_pressed(_TEST_ACTION))


func test_action_trigger_press_mode_button_hidden_while_held_releases() -> void:
	# Given: A press-mode button held down by the mouse.
	var parts := await _hold_button()
	var button: Button = parts[1]

	# When: The button is hidden while held.
	button.hide()
	await wait_idle_frames(2)

	# Then: The handler saw the release.
	assert_eq(_recorder.seen, [true, false] as Array[bool])

	# Then: The action is no longer pressed.
	assert_false(Input.is_action_pressed(_TEST_ACTION))


func test_action_trigger_press_mode_button_disabled_while_held_releases() -> void:
	# Given: A press-mode button held down by the mouse.
	var parts := await _hold_button()
	var button: Button = parts[1]

	# When: The button is disabled while held.
	button.disabled = true
	await wait_idle_frames(2)

	# Then: The handler saw the release.
	assert_eq(_recorder.seen, [true, false] as Array[bool])

	# Then: The action is no longer pressed.
	assert_false(Input.is_action_pressed(_TEST_ACTION))


func test_action_trigger_press_mode_button_freed_while_held_releases() -> void:
	# Given: A press-mode button held down by the mouse.
	var parts := await _hold_button()
	var button: Button = parts[1]

	# When: The button is freed while held.
	button.free()
	await wait_idle_frames(2)

	# Then: The handler saw the release.
	assert_eq(_recorder.seen, [true, false] as Array[bool])

	# Then: The action is no longer pressed.
	assert_false(Input.is_action_pressed(_TEST_ACTION))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	InputMap.erase_action(_TEST_ACTION)


func before_all() -> void:
	InputMap.add_action(_TEST_ACTION)


func before_each() -> void:
	_recorder = _InputRecorder.new()
	add_child_autofree(_recorder)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_button adds a button carrying a trigger for the test action under `parent`,
## which defaults to the test.
func _add_button(
	parent: Node = null,
	action_mode: BaseButton.ActionMode = BaseButton.ACTION_MODE_BUTTON_RELEASE,
) -> Button:
	var button := Button.new()
	button.action_mode = action_mode
	button.size = Vector2(100, 40)

	var trigger := StdInputActionTrigger.new()
	trigger.action = _TEST_ACTION
	button.add_child(trigger)

	if parent:
		parent.add_child(button)
		autofree(button)
	else:
		add_child_autofree(button)

	return button


## _hold_button adds a press-mode button inside a SubViewport and presses it with the
## mouse, checking that the trigger holds the action. Returns the viewport and button.
##
## NOTE: The root viewport dispatches no GUI input in headless mode; see
## https://github.com/godotengine/godot/issues/73557.
func _hold_button() -> Array:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 300)
	add_child_autofree(viewport)

	var button := _add_button(viewport, BaseButton.ACTION_MODE_BUTTON_PRESS)
	await wait_idle_frames(1)

	viewport.push_input(_mouse_left(true))
	await wait_idle_frames(2)

	assert_true(button.is_pressed(), "precondition: button should be held")
	assert_eq(_recorder.seen, [true] as Array[bool], "precondition: press only")
	assert_true(Input.is_action_pressed(_TEST_ACTION), "precondition: action held")

	return [viewport, button]


## _mouse_left returns a left mouse button event over the held button.
func _mouse_left(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(50, 20)
	return event


## _add_slot adds an input slot for `player_id` to the tree, with device components
## that hold whatever they are handed. A second slot passes the first's `cursor`, since
## only one cursor may exist.
func _add_slot(player_id: int = 1, cursor: StdInputCursor = null) -> StdInputSlot:
	var slot := StdInputSlot.new()
	slot.player_id = player_id
	slot.haptics_disabled_property = StdSettingsPropertyBool.new()
	slot.haptics_strength_property = StdSettingsPropertyFloatRange.new()

	slot.joypad_monitor = SlotTest.JoypadMonitor.new()
	slot.add_child(slot.joypad_monitor)

	if cursor:
		slot.cursor = cursor
	else:
		slot.cursor = StdInputCursor.new()
		slot.add_child(slot.cursor)

	slot.actions_kbm = add_child_autofree(_Actions.new())
	slot.glyphs_kbm = add_child_autofree(StdInputDeviceGlyphs.new())
	slot.haptics_kbm = add_child_autofree(StdInputDeviceHaptics.new())

	slot.actions_joy = add_child_autofree(_Actions.new())
	slot.glyphs_joy = add_child_autofree(StdInputDeviceGlyphs.new())
	slot.haptics_joy = add_child_autofree(StdInputDeviceHaptics.new())

	add_child_autofree(slot)
	autofree(slot.get_active_device())

	return slot
