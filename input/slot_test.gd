# gdlint:ignore=max-public-methods
##
## std/input/slot_test.gd
##
## Tests pertaining to the `StdInputSlot` library. Other input tests build their slot
## with `make_slot`.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

const _TEST_ACTIONS: Array[StringName] = [&"test_action"]

## _TEST_DEADZONE is the deadzone of the test action.
const _TEST_DEADZONE := 0.5

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


func test_input_slot_injected_action_below_deadzone_does_not_activate_joypad() -> void:
	# Given: The keyboard is active with a joypad connected.
	var kbm := _activate_kbm_with_joypad_connected()

	# When: An injected analog action from the joypad is pressed below its deadzone.
	slot._input(_injected_action(0, _TEST_DEADZONE - 0.1))

	# Then: The keyboard stays active.
	assert_eq(slot.get_active_device(), kbm)


func test_input_slot_injected_action_above_deadzone_activates_joypad() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()

	# When: An injected analog action from the joypad is pressed past its deadzone.
	slot._input(_injected_action(0, _TEST_DEADZONE + 0.1))

	# Then: The joypad is active.
	var got: StdInputDevice = slot.get_active_device()
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)


func test_input_slot_mouse_motion_reveals_cursor_without_activating_kbm() -> void:
	# Given: A joypad is active under a set which lets the cursor activate the keyboard.
	var joypad := _activate_joypad_under_set(StdInputActionSet.PROPERTY_STATUS_ON)

	# When: The mouse moves.
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(10, 10)
	event.screen_relative = Vector2(10, 10)
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


func test_input_slot_actions_include_absolute_mouse() -> void:
	# Given: An input slot added to the scene.
	add_child_autofree(slot)
	autofree(slot.get_active_device())

	# When: An action set with an absolute mouse action is loaded.
	var action_set := _make_action_set(&"Test")
	action_set.action_absolute_mouse = &"aim"
	assert_true(slot.load_action_set(action_set))

	# Then: The absolute mouse action is among the active actions.
	assert_has(slot._actions, "aim")


func test_input_slot_absolute_mouse_action_activates_joypad() -> void:
	# Given: The keyboard is active with a joypad connected.
	_activate_kbm_with_joypad_connected()
	slot._actions = [&"aim"]

	# When: The joypad's absolute mouse action is published as pressed.
	slot._input(_injected_action(0, 1.0, &"aim"))

	# Then: The joypad is active.
	var got: StdInputDevice = slot.get_active_device()
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_GENERIC)


func test_input_slot_forwards_component_bindings_changed() -> void:
	# Given: An input slot added to the scene, with its signals watched.
	add_child_autofree(slot)
	autofree(slot.get_active_device())
	watch_signals(slot)

	# When: The keyboard's actions component reports changed bindings.
	slot.actions_kbm.bindings_changed.emit()

	# Then: The slot reports a changed action configuration.
	assert_signal_emit_count(slot, "action_configuration_changed", 1)

	# When: The joypad's actions component reports changed bindings.
	slot.actions_joy.bindings_changed.emit()

	# Then: The slot reports it again.
	assert_signal_emit_count(slot, "action_configuration_changed", 2)


func test_input_slot_swap_forwards_the_next_components_bindings_changed() -> void:
	# Given: An input slot added to the scene.
	add_child_autofree(slot)
	autofree(slot.get_active_device())
	var actions_prev := slot.actions_joy

	# Given: The joypad components are swapped for new ones.
	var joypad_monitor := JoypadMonitor.new()
	add_child_autofree(joypad_monitor)
	var actions_next := DeviceActions.new()
	add_child_autofree(actions_next)
	slot.swap_joypad_components(
		joypad_monitor, actions_next, slot.glyphs_joy, slot.haptics_joy
	)
	watch_signals(slot)

	# When: The previous actions component reports changed bindings.
	actions_prev.bindings_changed.emit()

	# Then: The slot ignores it.
	assert_signal_not_emitted(slot, "action_configuration_changed")

	# When: The next actions component reports changed bindings.
	actions_next.bindings_changed.emit()

	# Then: The slot reports a changed action configuration.
	assert_signal_emit_count(slot, "action_configuration_changed", 1)


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

	# Given: The player presses a key bound to an action.
	slot._input(_key())

	# When: A joypad connects.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_GENERIC
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[0])

	# Then: The keyboard stays active and nothing was activated.
	var got: StdInputDevice = slot.get_active_device()
	assert_eq(got.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)
	assert_signal_not_emitted(slot, "device_activated")


func test_input_slot_held_joypad_action_does_not_reactivate_after_key_release() -> void:
	# Given: The keyboard is active with a joypad connected, and a held joypad action
	# the InputMap doesn't know activates the joypad.
	_activate_kbm_with_joypad_connected()
	slot._actions = [&"aim", &"test_action"]
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


func test_input_slot_joypad_disconnect_clears_tracked_actions() -> void:
	# Given: The keyboard is active with a joypad connected, and a held joypad action
	# activates the joypad.
	_activate_kbm_with_joypad_connected()
	slot._actions = [&"aim"]
	slot._input(_injected_action(0, 1.0, &"aim"))
	assert_has(slot._pressed, "aim", "precondition: action tracked")

	# When: The joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(0)

	# Then: No action is tracked.
	assert_true(slot._pressed.is_empty())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _TEST_ACTIONS:
		InputMap.erase_action(action)


func before_all() -> void:
	for action in _TEST_ACTIONS:
		InputMap.add_action(action, _TEST_DEADZONE)

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


## _activate_kbm_with_joypad_connected adds the slot to the scene with the keyboard
## active, joypad `0` connected, and the test action active. Returns the keyboard.
func _activate_kbm_with_joypad_connected() -> StdInputDevice:
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

	return kbm


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
