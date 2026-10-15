##
## std/input/action_trigger_test.gd
##
## Tests pertaining to `StdInputActionTrigger`.
##

extends GutTest

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


## _JoypadMonitor is a joypad monitor that reports no joypads.
class _JoypadMonitor:
	extends StdInputSlot.JoypadMonitor

	func _broadcast_connected_joypads() -> void:
		pass


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


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	InputMap.erase_action(_TEST_ACTION)


func before_all() -> void:
	InputMap.add_action(_TEST_ACTION)


func before_each() -> void:
	_recorder = _InputRecorder.new()
	add_child_autofree(_recorder)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_button adds a button carrying a trigger for the test action to the tree.
func _add_button() -> Button:
	var button := Button.new()

	var trigger := StdInputActionTrigger.new()
	trigger.action = _TEST_ACTION
	button.add_child(trigger)

	add_child_autofree(button)

	return button


## _add_slot adds an input slot for player 1 to the tree, with device components that
## hold whatever they are handed.
func _add_slot() -> StdInputSlot:
	var slot := StdInputSlot.new()
	slot.player_id = 1
	slot.haptics_disabled_property = StdSettingsPropertyBool.new()
	slot.haptics_strength_property = StdSettingsPropertyFloatRange.new()

	slot.joypad_monitor = _JoypadMonitor.new()
	slot.add_child(slot.joypad_monitor)

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
