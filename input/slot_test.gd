##
## std/input/slot_test.gd
##
## Tests pertaining to the `StdInputSlot` library. Other input tests build their slot
## with `make_slot`.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

const _TEST_ACTIONS: Array[StringName] = [&"test_action"]

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
	# Given: A joypad is active under a set which lets the cursor activate the keyboard.
	var joypad := _activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_ON)

	# When: The mouse moves.
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(10, 10)
	get_viewport().push_input(event)

	# Then: The cursor is revealed and the joypad stays active.
	assert_true(slot.cursor.get_is_visible())
	assert_eq(slot.get_active_device(), joypad)


func test_input_slot_reveal_button_press_activates_kbm() -> void:
	# Given: A joypad is active under a set which lets the cursor activate the keyboard.
	_activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_ON)

	# When: A cursor reveal button is pressed.
	slot._input(_mouse_button(MOUSE_BUTTON_LEFT))

	# Then: The keyboard is active.
	assert_eq(slot.get_active_device().device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)


func test_input_slot_emulated_mouse_button_does_not_activate_kbm() -> void:
	# Given: A joypad is active under a set which lets the cursor activate the keyboard.
	var joypad := _activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_ON)

	# When: A mouse button which Godot emulated from a touch is pressed.
	var event := _mouse_button(MOUSE_BUTTON_LEFT)
	event.device = InputEvent.DEVICE_ID_EMULATION
	slot._input(event)

	# Then: The joypad stays active.
	assert_eq(slot.get_active_device(), joypad)


func test_input_slot_unlisted_mouse_button_does_not_activate_kbm() -> void:
	# Given: A joypad is active under a set which lets the cursor activate the keyboard.
	var joypad := _activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_ON)

	# When: A mouse button outside the cursor's reveal buttons is pressed.
	slot._input(_mouse_button(MOUSE_BUTTON_MIDDLE))

	# Then: The joypad stays active.
	assert_eq(slot.get_active_device(), joypad)


func test_input_slot_mouse_button_does_not_activate_kbm_when_property_off() -> void:
	# Given: A joypad is active under a set which keeps the cursor from activating the
	# keyboard.
	var joypad := _activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_OFF)

	# When: A cursor reveal button is pressed.
	slot._input(_mouse_button(MOUSE_BUTTON_LEFT))

	# Then: The joypad stays active.
	assert_eq(slot.get_active_device(), joypad)


func test_input_slot_key_press_activates_kbm_with_no_active_device() -> void:
	# Given: An input slot claiming the keyboard, with no active device.
	slot.claim_kbm_input = true
	add_child_autofree(slot)
	autofree(slot.get_active_device())
	slot._active = null

	# Given: A test action is registered as an active action.
	slot._actions = [&"test_action"]

	# When: A key bound to the action is pressed.
	var event := InputEventKey.new()
	event.keycode = _TEST_KEY
	event.pressed = true
	slot._input(event)

	# Then: The keyboard is active.
	var got: StdInputDevice = slot.get_active_device()
	assert_not_null(got)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)


func test_input_slot_connects_and_disconnects_joypads() -> void:
	# Given: A new `StdInputSlot` is instantiated.
	assert_is(slot, StdInputSlot)

	# Given: The input slot is configured to claim keyboard+mouse input.
	slot.claim_kbm_input = false

	# Given: Signals are monitored.
	watch_signals(slot)

	# Given: The input slot is added to the scene.
	add_child_autofree(slot)

	# Given: There's no active or connected devices.
	assert_null(slot.get_active_device())
	assert_signal_not_emitted(slot, "device_activated")
	assert_signal_not_emitted(slot, "device_connected")

	# When: A newly connected joypad device is broadcast.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()

	# Then: The joypad is active.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_not_null(got)
	assert_is(got, StdInputDevice)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)

	# Then: The connect signal was emitted.
	assert_signal_emit_count(slot, "device_connected", 1)
	assert_signal_emitted_with_parameters(slot, "device_connected", [got])

	# Then: The activate signal was emitted.
	assert_signal_emit_count(slot, "device_activated", 1)
	assert_signal_emitted_with_parameters(slot, "device_activated", [got])

	# Then: The joypad is in the list of connected devices.
	assert_eq(len(slot.get_connected_devices()), 1)
	assert_has(slot.get_connected_devices(), got)

	# When: The connected joypad device is disconnected.
	slot.joypad_monitor.joy_disconnected.emit(0)

	# Then: The disconnect signal was emitted.
	assert_signal_emit_count(slot, "device_disconnected", 1)
	assert_signal_emitted_with_parameters(slot, "device_disconnected", [got])

	# Then: There are no connected devices.
	assert_eq(len(slot.get_connected_devices()), 0)


func test_input_slot_swap_reconnects_joypads() -> void:
	# Given: A new `StdInputSlot` is instantiated.
	assert_is(slot, StdInputSlot)

	# Given: The input slot is configured to claim keyboard+mouse input.
	slot.claim_kbm_input = false

	# Given: The input slot is added to the scene.
	add_child_autofree(slot)

	# Given: A device ID for a single connected joypad.
	var device_id := 1

	# When: A newly connected joypad device is broadcast.
	slot.joypad_monitor.connected = [device_id] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()

	# Then: The joypad is active.
	var got: StdInputDevice = autofree(slot.get_active_device())
	assert_not_null(got)
	assert_is(got, StdInputDevice)
	assert_eq(got.device_id, device_id)
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)

	# Then: The joypad is in the list of connected devices.
	assert_eq(len(slot.get_connected_devices()), 1)
	assert_has(slot.get_connected_devices(), got)

	# Given: A new joypad monitor is created and 1 device is already connected.
	var joypad_monitor := JoypadMonitor.new()
	joypad_monitor.connected = [device_id]
	joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	add_child_autofree(joypad_monitor)

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The joypad monitor is swapped.
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

	# Then: The same joypad is active (the `InputDevice` may be different though).
	var got_next: StdInputDevice = autofree(slot.get_active_device())
	assert_not_null(got_next)
	assert_is(got_next, StdInputDevice)
	assert_eq(got_next.device_id, device_id)
	assert_eq(got_next.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)

	# Then: The disconnect signal was emitted.
	assert_signal_emit_count(slot, "device_disconnected", 1)
	assert_signal_emitted_with_parameters(slot, "device_disconnected", [got])

	# Then: The connect signal was emitted.
	assert_signal_emit_count(slot, "device_connected", 1)
	assert_signal_emitted_with_parameters(slot, "device_connected", [got_next])

	# Then: There is 1 connected device.
	assert_eq(len(slot.get_connected_devices()), 1)


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


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _TEST_ACTIONS:
		InputMap.erase_action(action)


func before_all() -> void:
	for action in _TEST_ACTIONS:
		InputMap.add_action(action)

	var key := InputEventKey.new()
	key.keycode = _TEST_KEY
	InputMap.action_add_event(&"test_action", key)


func before_each() -> void:
	slot = make_slot()
	_actions_joy = slot.actions_joy as DeviceActions


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _activate_joypad_under_set adds the slot to the scene with the keyboard claimed, a
## joypad connected and active, an action set loaded whose `cursor_activates_kbm` is
## `status`, and the cursor hidden. Returns the joypad.
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
	action_set.cursor_activates_kbm = status
	assert_true(slot.load_action_set(action_set), "precondition: action set loaded")

	slot.cursor.hide_cursor()
	assert_false(slot.cursor.get_is_visible(), "precondition: cursor hidden")

	return joypad


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
