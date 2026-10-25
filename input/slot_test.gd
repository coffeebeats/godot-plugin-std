# gdlint:ignore=max-public-methods
# gdlint:disable=max-file-lines
##
## std/input/slot_test.gd
##
## Tests pertaining to the `StdInputSlot` library. Other input tests build their slot
## with `make_slot`.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

const _TEST_ACTIONS: Array[StringName] = [&"test_action"]

## _TEST_AXIS_ACTIONS are two actions bound to the same joypad axis direction.
const _TEST_AXIS_ACTIONS: Array[StringName] = [&"test_axis_a", &"test_axis_b"]

## _TEST_DEADZONE is the deadzone of the test axis actions. It sits above the `0.5` at
## which a joypad motion event reads as pressed, so a motion between the two is a press
## which doesn't press the actions.
const _TEST_DEADZONE := 0.75

## _TEST_KEY is the key bound to the test action.
const _TEST_KEY := KEY_T


## JoypadMonitor is a fake implementation of `StdInputSlot.JoypadMonitor`.
class JoypadMonitor:
	extends StdInputSlot.JoypadMonitor

	@export var connected: Array[int] = []
	@export
	var device_type: StdInputDevice.DeviceType = StdInputDevice.DEVICE_TYPE_UNKNOWN

	func _broadcast_connected_joypads() -> void:
		for device in connected:
			joy_connected.emit(device, device_type)


## DeviceActions is a device actions component that holds whatever it is handed.
class DeviceActions:
	extends StdInputDeviceActions

	var action_set: StdInputActionSet = null
	var layers: Array[StdInputActionSetLayer] = []

	## refuses_action_sets makes every load fail, as Steam's does for a set missing from
	## its manifest.
	var refuses_action_sets: bool = false

	func _get_action_set(_device: int) -> StdInputActionSet:
		return action_set

	func _load_action_set(_device: int, next: StdInputActionSet) -> bool:
		if refuses_action_sets or next == action_set:
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

var slot: StdInputSlot = null
var _actions_joy: DeviceActions = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## make_slot returns an input slot for `player_id`, not yet in the tree, whose fake
## components are its children. Slots sharing a tree pass one `cursor` that outlives
## them, since only one cursor may exist.
static func make_slot(
	player_id: int = 1, cursor: StdInputCursor = null
) -> StdInputSlot:
	var input_slot := StdInputSlot.new()
	input_slot.player_id = player_id
	input_slot.haptics_disabled_property = StdSettingsPropertyBool.new()
	input_slot.haptics_strength_property = StdSettingsPropertyFloatRange.new()

	input_slot.joypad_monitor = JoypadMonitor.new()
	input_slot.add_child(input_slot.joypad_monitor)

	if cursor:
		input_slot.cursor = cursor
	else:
		input_slot.cursor = StdInputCursor.new()
		input_slot.add_child(input_slot.cursor)

	input_slot.actions_kbm = DeviceActions.new()
	input_slot.glyphs_kbm = StdInputDeviceGlyphs.new()
	input_slot.haptics_kbm = StdInputDeviceHaptics.new()
	input_slot.actions_joy = DeviceActions.new()
	input_slot.glyphs_joy = StdInputDeviceGlyphs.new()
	input_slot.haptics_joy = StdInputDeviceHaptics.new()

	for component in [
		input_slot.actions_kbm,
		input_slot.glyphs_kbm,
		input_slot.haptics_kbm,
		input_slot.actions_joy,
		input_slot.glyphs_joy,
		input_slot.haptics_joy,
	]:
		input_slot.add_child(component)

	return input_slot


# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_slot_activates_keyboard_on_ready() -> void:
	# Given: The input slot is configured to claim keyboard + mouseinput.
	slot.claim_kbm_input = true

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The input slot is added to the scene.
	add_child_autofree(slot)

	# Then: The active device is the keyboard.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_is(got, StdInputDevice)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# Then: The keyboard device is connected.
	assert_signal_emit_count(slot, "device_connected", 1)
	assert_signal_emitted_with_parameters(slot, "device_connected", [got])

	# Then: The keyboard device is activated.
	assert_signal_emit_count(slot, "device_activated", 1)
	assert_signal_emitted_with_parameters(slot, "device_activated", [got])

	# Then: The keyboard is in the list of connected devices.
	assert_eq(len(slot.get_connected_devices()), 1)
	assert_has(slot.get_connected_devices(), got)


func test_input_slot_does_not_swap_device_for_synthetic_action() -> void:
	# Given: The input slot claims keyboard + mouse input.
	slot.claim_kbm_input = true
	slot.prefer_activate_joypad_on_ready = false

	# Given: The input slot is added to the scene.
	add_child_autofree(slot)

	# Given: A joypad with device ID 0 is connected.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()

	# Given: The active device is the keyboard.
	var kbm: StdInputDevice = autofree(slot.get_active_device())
	assert_eq(kbm.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# Given: A joypad device reference for cleanup.
	autofree(slot.get_connected_devices(false)[0])

	# Given: A test action is registered as an active action.
	slot._actions = [&"test_action"]

	# When: A synthetic InputEventAction with DEVICE_ID_SYNTHETIC
	# is dispatched.
	var event := InputEventAction.new()
	event.action = &"test_action"
	event.device = StdInputEvent.DEVICE_ID_SYNTHETIC
	event.pressed = true
	slot._input(event)

	# Then: The active device is still the keyboard.
	var got: StdInputDevice = slot.get_active_device()
	assert_eq(got, kbm)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)


func test_input_slot_swaps_device_for_action_with_matching_id() -> void:
	# Given: The input slot claims keyboard + mouse input.
	slot.claim_kbm_input = true
	slot.prefer_activate_joypad_on_ready = false

	# Given: The input slot is added to the scene.
	add_child_autofree(slot)

	# Given: A joypad with device ID 0 is connected.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()

	# Given: The active device is the keyboard.
	var kbm: StdInputDevice = autofree(slot.get_active_device())
	assert_eq(kbm.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# Given: A test action is registered as an active action.
	slot._actions = [&"test_action"]

	# When: An InputEventAction with a device ID matching the
	# connected joypad is dispatched (e.g. from Steam Input).
	var event := InputEventAction.new()
	event.action = &"test_action"
	event.device = 0
	event.pressed = true
	slot._input(event)

	# Then: The active device is the joypad.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_ne(got, kbm)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)


func test_input_slot_mouse_motion_reveals_cursor_without_activating_kbm() -> void:
	# Given: A joypad is active under a set where a click activates the keyboard.
	var joypad := _activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_ON)

	# When: The mouse moves.
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(10, 10)
	event.screen_relative = Vector2(10, 10)
	get_viewport().push_input(event)

	# Then: The cursor is revealed.
	assert_true(slot.cursor.get_is_visible())

	# Then: The joypad stays active.
	assert_eq(slot.get_active_device(), joypad)


func test_input_slot_reveal_button_press_activates_kbm() -> void:
	# Given: A joypad is active under a set where a click activates the keyboard.
	_activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_ON)

	# When: A cursor reveal button is pressed.
	slot._input(_mouse_button(MOUSE_BUTTON_LEFT))

	# Then: The keyboard is active.
	assert_eq(slot.get_active_device().device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)


func test_input_slot_emulated_mouse_button_does_not_activate_kbm() -> void:
	# Given: A joypad is active under a set where a click activates the keyboard.
	var joypad := _activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_ON)

	# When: A mouse button which Godot emulated from a touch is pressed.
	var event := _mouse_button(MOUSE_BUTTON_LEFT)
	event.device = InputEvent.DEVICE_ID_EMULATION
	slot._input(event)

	# Then: The joypad stays active.
	assert_eq(slot.get_active_device(), joypad)


func test_input_slot_unlisted_mouse_button_does_not_activate_kbm() -> void:
	# Given: A joypad is active under a set where a click activates the keyboard.
	var joypad := _activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_ON)

	# When: A mouse button outside the cursor's reveal buttons is pressed.
	slot._input(_mouse_button(MOUSE_BUTTON_MIDDLE))

	# Then: The joypad stays active.
	assert_eq(slot.get_active_device(), joypad)


func test_input_slot_mouse_button_does_not_activate_kbm_when_property_off() -> void:
	# Given: A joypad is active under a set where a click doesn't activate the keyboard.
	var joypad := _activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_OFF)

	# When: A cursor reveal button is pressed.
	slot._input(_mouse_button(MOUSE_BUTTON_LEFT))

	# Then: The joypad stays active.
	assert_eq(slot.get_active_device(), joypad)


func test_input_slot_bound_key_press_activates_kbm_when_property_off() -> void:
	# Given: A joypad is active under a set where a click doesn't activate the keyboard.
	_activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_OFF)

	# When: A key bound to the test action is pressed.
	slot._input(_key())

	# Then: The keyboard is active.
	assert_eq(slot.get_active_device().device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)


func test_input_slot_bound_key_press_activates_kbm_with_no_active_device() -> void:
	# Given: A joypad is active under a set where a click doesn't activate the keyboard.
	_activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_OFF)

	# Given: The joypad monitor is swapped for an empty one, leaving no device active.
	var joypad_monitor := JoypadMonitor.new()
	add_child_autofree(joypad_monitor)

	var joypad_monitor_prev := slot.joypad_monitor
	(
		slot
		. swap_joypad_components(
			joypad_monitor,
			slot.actions_joy,
			slot.glyphs_joy,
			slot.haptics_joy,
		)
	)
	joypad_monitor_prev.free()
	assert_null(slot.get_active_device(), "precondition: no device active")

	# When: A key bound to the test action is pressed.
	slot._input(_key())

	# Then: The keyboard is active.
	var got: StdInputDevice = slot.get_active_device()
	assert_not_null(got)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)


func test_input_slot_get_joypad_device_type_returns_generic_without_joypads() -> void:
	# Given: An input slot added to the scene with no joypad connected.
	add_child_autofree(slot)
	autofree(slot.get_active_device())

	# Then: The joypad device type is generic.
	assert_eq(slot.get_joypad_device_type(), StdInputDevice.DEVICE_TYPE_GENERIC)


func test_input_slot_get_joypad_device_type_falls_back_to_first_connected() -> void:
	# Given: An input slot added to the scene with the keyboard kept active.
	slot.prefer_activate_joypad_on_ready = false
	add_child_autofree(slot)
	autofree(slot.get_active_device())

	# Given: A PlayStation 5 joypad connects without becoming active.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_PS_5
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[0])
	assert_eq(
		slot.get_active_device().device_type,
		StdInputDevice.DEVICE_TYPE_KEYBOARD,
		"precondition: keyboard active",
	)

	# Then: The joypad device type is the connected joypad's.
	assert_eq(slot.get_joypad_device_type(), StdInputDevice.DEVICE_TYPE_PS_5)


func test_input_slot_get_joypad_device_type_prefers_last_active_joypad() -> void:
	# Given: An input slot added to the scene with the keyboard claimed.
	slot.claim_kbm_input = true
	add_child_autofree(slot)
	autofree(slot.get_active_device())

	# Given: A Steam Deck joypad connects and becomes active.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_STEAM_DECK
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_active_device())

	# Given: A key bound to an active action returns the keyboard to active.
	slot._actions = [&"test_action"]
	var event := InputEventKey.new()
	event.keycode = _TEST_KEY
	event.pressed = true
	slot._input(event)
	assert_eq(
		slot.get_active_device().device_type,
		StdInputDevice.DEVICE_TYPE_KEYBOARD,
		"precondition: keyboard active",
	)

	# Then: The joypad device type is the last active joypad's.
	assert_eq(slot.get_joypad_device_type(), StdInputDevice.DEVICE_TYPE_STEAM_DECK)


func test_input_slot_actions_include_every_action_of_the_set_and_its_layers() -> void:
	# Given: An input slot added to the scene.
	add_child_autofree(slot)
	autofree(slot.get_active_device())

	# Given: An action set declaring an action of every kind is loaded.
	var action_set := _make_action_set(&"Test")
	action_set.actions_analog_1d = [&"throttle"]
	action_set.actions_analog_2d = [&"move"]
	action_set.actions_digital = [
		&"test_action", &"move_left", &"move_right", &"move_up", &"move_down"
	]
	action_set.action_absolute_mouse = &"aim"
	assert_true(slot.load_action_set(action_set), "precondition: action set loaded")

	# When: A layer declaring its own digital and absolute mouse actions is enabled.
	var layer := _make_layer(&"TestLayer", action_set)
	layer.actions_digital = [&"fire"]
	layer.action_absolute_mouse = &"look"
	assert_true(slot.enable_action_set_layer(layer))

	# Then: Every action of the set and the layer is active, in any order.
	var got: Array[String] = slot._actions.duplicate()
	got.sort()
	assert_eq(
		got,
		(
			[
				"aim",
				"fire",
				"look",
				"move",
				"move_down",
				"move_left",
				"move_right",
				"move_up",
				"test_action",
				"throttle",
			]
			as Array[String]
		),
	)


func test_input_slot_absolute_mouse_action_activates_joypad() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# Given: An action set declaring an absolute mouse action is loaded.
	var action_set := _make_action_set(&"Test")
	action_set.action_absolute_mouse = &"aim"
	assert_true(slot.load_action_set(action_set), "precondition: action set loaded")

	# When: The joypad's absolute mouse action is published as pressed.
	slot._input(_injected_action(0, 1.0, &"aim"))

	# Then: The joypad is active.
	var got: StdInputDevice = slot.get_active_device()
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)


func test_input_slot_load_of_another_action_set_clears_layers() -> void:
	# Given: An input slot with a loaded action set.
	add_child_autofree(slot)
	autofree(slot.get_active_device())
	var action_set := _make_action_set(&"Test")
	assert_true(slot.load_action_set(action_set))

	# Given: An enabled layer.
	var layer := _make_layer(&"TestLayer", action_set)
	assert_true(slot.enable_action_set_layer(layer))

	# When: Another action set is loaded.
	assert_true(slot.load_action_set(_make_action_set(&"Other")))

	# Then: No layer is enabled.
	assert_eq(slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])


func test_input_slot_load_of_the_active_action_set_keeps_layers() -> void:
	# Given: An input slot with a loaded action set.
	add_child_autofree(slot)
	autofree(slot.get_active_device())
	var action_set := _make_action_set(&"Test")
	assert_true(slot.load_action_set(action_set))

	# Given: An enabled layer.
	var layer := _make_layer(&"TestLayer", action_set)
	assert_true(slot.enable_action_set_layer(layer))

	# When: The same action set is loaded again.
	assert_false(slot.load_action_set(action_set))

	# Then: The layer is still enabled.
	assert_eq(slot.list_action_set_layers(), [layer] as Array[StdInputActionSetLayer])


func test_input_slot_layer_enabled_before_any_device_reaches_a_later_joypad() -> void:
	# Given: An input slot claiming no keyboard, with no joypad connected.
	slot.claim_kbm_input = false
	add_child_autofree(slot)
	assert_eq(len(slot.get_connected_devices()), 0)

	# Given: An action set is loaded and a layer enabled with no device to take them.
	var action_set := _make_action_set(&"Test")
	var layer := _make_layer(&"TestLayer", action_set)
	assert_true(slot.load_action_set(action_set))
	assert_true(slot.enable_action_set_layer(layer))

	# When: A joypad connects.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_active_device())

	# Then: The joypad holds the action set and the layer.
	assert_eq(_actions_joy.action_set, action_set)
	assert_eq(_actions_joy.layers, [layer] as Array[StdInputActionSetLayer])


func test_input_slot_connected_joypad_gets_layers_when_its_set_is_unchanged() -> void:
	# Given: An input slot claiming no keyboard.
	slot.claim_kbm_input = false
	add_child_autofree(slot)

	# Given: An action set loaded with a layer enabled, before any joypad connects.
	var action_set := _make_action_set(&"Test")
	var layer := _make_layer(&"TestLayer", action_set)
	assert_true(slot.load_action_set(action_set))
	assert_true(slot.enable_action_set_layer(layer))

	# Given: The joypad component already holds the action set.
	_actions_joy.action_set = action_set

	# When: A joypad connects.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_active_device())

	# Then: The joypad holds the layer too.
	assert_eq(_actions_joy.layers, [layer] as Array[StdInputActionSetLayer])


func test_input_slot_connected_joypad_gets_no_layers_when_its_set_is_refused() -> void:
	# Given: An input slot claiming no keyboard.
	slot.claim_kbm_input = false
	add_child_autofree(slot)

	# Given: An action set loaded with a layer enabled, before any joypad connects.
	var action_set := _make_action_set(&"Test")
	var layer := _make_layer(&"TestLayer", action_set)
	assert_true(slot.load_action_set(action_set))
	assert_true(slot.enable_action_set_layer(layer))

	# Given: The joypad component refuses the action set.
	_actions_joy.refuses_action_sets = true

	# When: A joypad connects.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_active_device())

	# Then: The joypad holds no action set.
	assert_null(_actions_joy.action_set)

	# Then: The joypad holds no layer without its set.
	assert_eq(_actions_joy.layers, [] as Array[StdInputActionSetLayer])


func test_input_slot_joypad_connected_before_player_input_activates() -> void:
	# Given: An input slot added to the scene with the keyboard active and a joypad
	# preferred.
	slot.claim_kbm_input = true
	slot.prefer_activate_joypad_on_ready = true
	add_child_autofree(slot)
	autofree(slot.get_active_device())

	# When: A joypad connects before the player has pressed anything.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()

	# Then: The joypad is active.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)


func test_input_slot_joypad_connected_after_player_input_stays_inactive() -> void:
	# Given: An input slot added to the scene with the keyboard active and a joypad
	# preferred.
	slot.claim_kbm_input = true
	slot.prefer_activate_joypad_on_ready = true
	add_child_autofree(slot)
	autofree(slot.get_active_device())
	slot._actions = [&"test_action"]
	watch_signals(slot)

	# Given: The player presses and releases a key bound to an action.
	slot._input(_key())
	slot._input(_key(false))

	# When: A joypad connects.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[0])

	# Then: The keyboard stays active and nothing was activated.
	var got: StdInputDevice = slot.get_active_device()
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)
	assert_signal_not_emitted(slot, "device_activated")


func test_input_slot_emulated_mouse_button_is_not_player_input() -> void:
	# Given: An input slot added to the scene with the keyboard active and a joypad
	# preferred, under a set where a click activates the keyboard.
	slot.claim_kbm_input = true
	slot.prefer_activate_joypad_on_ready = true
	add_child_autofree(slot)
	autofree(slot.get_active_device())
	var action_set := _make_action_set(&"Test")
	action_set.cursor_click_activates_kbm = StdInputActionSet.PROPERTY_STATUS_ON
	assert_true(slot.load_action_set(action_set), "precondition: action set loaded")

	# Given: A mouse button Godot emulated from a touch was pressed.
	var event := _mouse_button(MOUSE_BUTTON_LEFT)
	event.device = InputEvent.DEVICE_ID_EMULATION
	slot._input(event)
	assert_false(slot._has_player_input, "precondition: no player input")

	# When: A joypad connects.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()

	# Then: The joypad is active, as the touch showed no preference.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)


func test_input_slot_unbound_key_is_not_player_input() -> void:
	# Given: An input slot added to the scene with the keyboard active and the test
	# action active.
	slot.claim_kbm_input = true
	add_child_autofree(slot)
	autofree(slot.get_active_device())
	slot._actions = [&"test_action"]

	# When: A key bound to no action is pressed.
	var event := InputEventKey.new()
	event.keycode = KEY_A
	event.pressed = true
	slot._input(event)

	# Then: The slot has seen no player input.
	assert_false(slot._has_player_input)

	# When: The key bound to the test action is pressed.
	slot._input(_key())

	# Then: The slot has seen player input.
	assert_true(slot._has_player_input)


func test_input_slot_unbound_joypad_motion_is_not_player_input() -> void:
	# Given: The keyboard is active beside a connected joypad.
	_activate_kbm_with_joypad_connected()

	# Given: The test axis actions are active.
	slot._actions = [&"test_axis_a", &"test_axis_b"]

	# When: The right stick, which no active action is bound to, moves.
	var event := _joypad_motion(0, 1.0)
	event.axis = JOY_AXIS_RIGHT_X
	slot._input(event)

	# Then: The slot has seen no player input.
	assert_false(slot._has_player_input)

	# When: The stick bound to the test axis actions moves.
	slot._input(_joypad_motion(0, 1.0))

	# Then: The slot has seen player input.
	assert_true(slot._has_player_input)


func test_input_slot_joypad_motion_inside_deadzone_is_not_player_input() -> void:
	# Given: The keyboard is active beside a connected joypad.
	_activate_kbm_with_joypad_connected()

	# Given: The test axis actions are active.
	slot._actions = [&"test_axis_a", &"test_axis_b"]

	# When: The bound stick moves far enough to read as a press but stays inside the
	# actions' deadzone.
	slot._input(_joypad_motion(0, (0.5 + _TEST_DEADZONE) / 2.0))

	# Then: The slot has seen no player input.
	assert_false(slot._has_player_input)


func test_input_slot_joypad_pressed_before_connecting_activates_on_connect() -> void:
	# Given: An input slot added to the scene with the keyboard active, a joypad
	# preferred, and the test axis actions active.
	slot.claim_kbm_input = true
	slot.prefer_activate_joypad_on_ready = true
	add_child_autofree(slot)
	autofree(slot.get_active_device())
	slot._actions = [&"test_axis_a", &"test_axis_b"]

	# Given: A joypad its monitor hasn't reported yet moves the bound stick.
	slot._input(_joypad_motion(0, 1.0))

	# When: The monitor reports the joypad.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()

	# Then: The joypad is active, as its press showed a preference for it.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)


func test_input_slot_held_joypad_action_does_not_reactivate_after_key_release() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# Given: An action the InputMap doesn't know and the test action are active.
	slot._actions = [&"aim", &"test_action"]

	# Given: The joypad holds the unknown action, which activates it.
	slot._input(_injected_action(0, 1.0, &"aim"))
	assert_eq(
		slot.get_active_device().device_type,
		StdInputDevice.DEVICE_TYPE_GENERIC,
		"precondition: joypad active",
	)

	# Given: A key bound to an action is pressed and released, activating the keyboard.
	slot._input(_key())
	slot._input(_key(false))
	assert_eq(
		slot.get_active_device().device_type,
		StdInputDevice.DEVICE_TYPE_KEYBOARD,
		"precondition: keyboard active",
	)

	# When: The still-held joypad action reports pressed again.
	slot._input(_injected_action(0, 1.0, &"aim"))

	# Then: The keyboard stays active.
	var got: StdInputDevice = slot.get_active_device()
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)


func test_input_slot_joypad_held_before_switching_does_not_reactivate() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# Given: Two joypad actions and the test action are active.
	slot._actions = [&"aim", &"fire", &"test_action"]

	# Given: A joypad press activates the joypad.
	slot._input(_injected_action(0, 1.0, &"fire"))
	assert_eq(
		slot.get_active_device().device_type,
		StdInputDevice.DEVICE_TYPE_GENERIC,
		"precondition: joypad active",
	)

	# Given: A second action is pressed and held while the joypad is active.
	slot._input(_injected_action(0, 1.0, &"aim"))

	# Given: A key bound to an action is pressed and released, activating the keyboard.
	slot._input(_key())
	slot._input(_key(false))
	assert_eq(
		slot.get_active_device().device_type,
		StdInputDevice.DEVICE_TYPE_KEYBOARD,
		"precondition: keyboard active",
	)

	# When: The still-held joypad action reports pressed again.
	slot._input(_injected_action(0, 1.0, &"aim"))

	# Then: The keyboard stays active.
	var got: StdInputDevice = slot.get_active_device()
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)


func test_input_slot_held_axis_bound_to_two_actions_does_not_reactivate() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# Given: Two actions bound to the same axis and the test action are active.
	slot._actions = [&"test_axis_a", &"test_axis_b", &"test_action"]

	# Given: The joypad holds the axis, which activates it.
	slot._input(_joypad_motion(0, 1.0))
	assert_eq(
		slot.get_active_device().device_type,
		StdInputDevice.DEVICE_TYPE_GENERIC,
		"precondition: joypad active",
	)

	# Given: A key bound to an action is pressed and released, activating the keyboard.
	slot._input(_key())
	slot._input(_key(false))
	assert_eq(
		slot.get_active_device().device_type,
		StdInputDevice.DEVICE_TYPE_KEYBOARD,
		"precondition: keyboard active",
	)

	# When: The still-held axis reports motion again.
	slot._input(_joypad_motion(0, 0.9))

	# Then: The keyboard stays active.
	var got: StdInputDevice = slot.get_active_device()
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)


func test_input_slot_held_action_pressed_on_another_joypad_activates_it() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# Given: A second joypad connects.
	slot.joypad_monitor.connected = [0, 1] as Array[int]
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[1])

	# Given: A joypad action is active.
	slot._actions = [&"aim"]

	# Given: The first joypad holds the action, which activates it.
	slot._input(_injected_action(0, 1.0, &"aim"))
	assert_eq(
		slot.get_active_device().device_id, 0, "precondition: first joypad active"
	)

	# When: The second joypad presses the same action.
	slot._input(_injected_action(1, 1.0, &"aim"))

	# Then: The second joypad is active.
	var got: StdInputDevice = slot.get_active_device()
	assert_eq(got.device_id, 1)


func test_input_slot_opposite_axis_motion_releases_a_tracked_action() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# Given: Two actions bound to the same axis are active.
	slot._actions = [&"test_axis_a", &"test_axis_b"]

	# Given: The joypad holds the axis.
	slot._input(_joypad_motion(0, 1.0))
	assert_has(slot._pressed[0], "test_axis_a", "precondition: action tracked")

	# When: The axis flicks to the opposite side without a centered event.
	slot._input(_joypad_motion(0, -1.0))

	# Then: The action is no longer tracked.
	assert_does_not_have(slot._pressed[0], "test_axis_a")


func test_input_slot_layer_change_does_not_rearm_a_held_joypad_action() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# Given: An action set declaring a joypad action and the test action is loaded.
	var action_set := _make_action_set(&"Test")
	action_set.actions_digital = [&"aim", &"test_action"]
	assert_true(slot.load_action_set(action_set), "precondition: action set loaded")

	# Given: The joypad holds the joypad action, which activates it.
	slot._input(_injected_action(0, 1.0, &"aim"))
	assert_eq(
		slot.get_active_device().device_type,
		StdInputDevice.DEVICE_TYPE_GENERIC,
		"precondition: joypad active",
	)

	# Given: A key bound to an action is pressed and released, activating the keyboard.
	slot._input(_key())
	slot._input(_key(false))
	assert_eq(
		slot.get_active_device().device_type,
		StdInputDevice.DEVICE_TYPE_KEYBOARD,
		"precondition: keyboard active",
	)

	# When: A layer is enabled.
	assert_true(slot.enable_action_set_layer(_make_layer(&"TestLayer", action_set)))

	# When: The still-held joypad action reports pressed again.
	slot._input(_injected_action(0, 1.0, &"aim"))

	# Then: The keyboard stays active.
	var got: StdInputDevice = slot.get_active_device()
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)


func test_input_slot_joypad_disconnect_clears_tracked_actions() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# Given: A joypad action is active.
	slot._actions = [&"aim"]

	# Given: The joypad holds the action.
	slot._input(_injected_action(0, 1.0, &"aim"))
	assert_has(slot._pressed[0], "aim", "precondition: action tracked")

	# When: The joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(0)

	# Then: No action is tracked.
	assert_true(slot._pressed.is_empty())


func test_input_slot_joypad_disconnect_keeps_another_joypads_tracked_action() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# Given: A second joypad connects.
	slot.joypad_monitor.connected = [0, 1] as Array[int]
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[1])

	# Given: Two joypad actions are active.
	slot._actions = [&"aim", &"fire"]

	# Given: Each joypad holds one of the actions.
	slot._input(_injected_action(0, 1.0, &"aim"))
	slot._input(_injected_action(1, 1.0, &"fire"))
	assert_has(slot._pressed[0], "aim", "precondition: action tracked")
	assert_has(slot._pressed[1], "fire", "precondition: action tracked")

	# When: The first joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(0)

	# Then: Only the second joypad's action is still tracked.
	assert_does_not_have(slot._pressed, 0)
	assert_has(slot._pressed[1], "fire")


func test_input_slot_release_from_another_joypad_keeps_a_tracked_action() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# Given: A joypad action is active.
	slot._actions = [&"aim"]

	# Given: The joypad holds the action.
	slot._input(_injected_action(0, 1.0, &"aim"))
	assert_has(slot._pressed[0], "aim", "precondition: action tracked")

	# When: Another joypad releases the same action.
	var event := _injected_action(1, 0.0, &"aim")
	event.pressed = false
	slot._input(event)

	# Then: The action is still tracked for the first joypad.
	assert_has(slot._pressed[0], "aim")

	# When: The first joypad releases it.
	event.device = 0
	slot._input(event)

	# Then: The action is no longer tracked.
	assert_does_not_have(slot._pressed[0], "aim")


func test_input_slot_set_change_drops_a_tracked_action_it_no_longer_binds() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# Given: An action set declaring a joypad action and the test action is loaded.
	var action_set := _make_action_set(&"Test")
	action_set.actions_digital = [&"aim", &"test_action"]
	assert_true(slot.load_action_set(action_set), "precondition: action set loaded")

	# Given: The joypad holds the joypad action.
	slot._input(_injected_action(0, 1.0, &"aim"))
	assert_has(slot._pressed[0], "aim", "precondition: action tracked")

	# When: A set without the held action is loaded.
	var other := _make_action_set(&"Other")
	assert_true(slot.load_action_set(other), "precondition: action set loaded")

	# Then: The action is no longer tracked.
	assert_does_not_have(slot._pressed[0], "aim")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _TEST_ACTIONS + _TEST_AXIS_ACTIONS:
		InputMap.erase_action(action)


func before_all() -> void:
	for action in _TEST_ACTIONS:
		InputMap.add_action(action)

	var key := InputEventKey.new()
	key.keycode = _TEST_KEY
	InputMap.action_add_event(&"test_action", key)

	for action in _TEST_AXIS_ACTIONS:
		InputMap.add_action(action, _TEST_DEADZONE)
		InputMap.action_add_event(action, _joypad_motion(0, 1.0))


func before_each() -> void:
	slot = make_slot()
	_actions_joy = slot.actions_joy as DeviceActions


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _activate_joypad_under_set adds the slot to the scene with the keyboard claimed, a
## joypad connected and active, an action set loaded whose `cursor_click_activates_kbm`
## is `status`, and the cursor hidden. Returns the joypad.
func _activate_joypad_under_set(
	status: StdInputActionSet.PropertyStatus,
) -> StdInputDevice:
	slot.claim_kbm_input = true
	slot.prefer_activate_joypad_on_ready = true
	add_child_autofree(slot)
	autofree(slot.get_active_device())

	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()

	var joypad: StdInputDevice = autofree(slot.get_active_device())
	assert_eq(
		joypad.device_type,
		StdInputDevice.DEVICE_TYPE_GENERIC,
		"precondition: joypad active",
	)

	var action_set := _make_action_set(&"Test")
	action_set.cursor_click_activates_kbm = status
	assert_true(slot.load_action_set(action_set), "precondition: action set loaded")

	slot.cursor.hide_cursor()
	assert_false(slot.cursor.get_is_visible(), "precondition: cursor hidden")

	return joypad


## _activate_kbm_with_joypad_connected adds the slot to the scene with the keyboard
## active, joypad `0` connected, and the test action active.
func _activate_kbm_with_joypad_connected() -> void:
	slot.claim_kbm_input = true
	slot.prefer_activate_joypad_on_ready = false
	add_child_autofree(slot)

	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[0])

	var kbm: StdInputDevice = autofree(slot.get_active_device())
	assert_eq(
		kbm.device_type,
		StdInputDevice.DEVICE_TYPE_KEYBOARD,
		"precondition: keyboard active",
	)

	slot._actions = [&"test_action"]


## _injected_action returns a press of `action` injected for joypad `device` at
## `strength`, as the Steam actions component publishes analog actions.
func _injected_action(
	device: int, strength: float, action: StringName = &"test_action"
) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.device = device
	event.pressed = true
	event.strength = strength
	return event


## _joypad_motion returns a motion of the left stick's horizontal axis on joypad
## `device` to `value`.
func _joypad_motion(device: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event


## _key returns a press, or a release when `pressed` is `false`, of the key bound to the
## test action.
func _key(pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = _TEST_KEY
	event.pressed = pressed
	return event


## _make_action_set returns an action set called `id` declaring the test action.
func _make_action_set(id: StringName) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = id
	action_set.actions_digital = _TEST_ACTIONS.duplicate()
	return action_set


## _make_layer returns a layer called `id` under `parent`, declaring nothing.
func _make_layer(id: StringName, parent: StdInputActionSet) -> StdInputActionSetLayer:
	var layer := StdInputActionSetLayer.new()
	layer.name = id
	layer.parent = parent
	return layer


## _mouse_button returns a press of the mouse button `index`.
func _mouse_button(index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = true
	return event
