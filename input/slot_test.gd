##
## Tests pertaining to the `InputSlot` library.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var slot: InputSlot = null
var joypad_monitor: InputSlot.JoypadMonitor = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_slot_activates_keyboard_on_ready() -> void:
	# Given: Theinputslot is configuredtoclaimkeyboard + mouseinput.
	slot.claim_kbm_input = true

	# Given: Signals are monitored.
	watch_signals(slot)

	# When: The input slot is added to the scene.
	add_child_autofree(slot)

	# Then: The active device is the keyboard.
	var got := slot.get_active_device()
	assert_is(got, InputDevice)
	assert_eq(got.device_type, InputDevice.DEVICE_TYPE_KEYBOARD)

	# Then: The keyboard device is connected.
	assert_signal_emit_count(slot, "device_connected", 1)
	assert_signal_emitted_with_parameters(slot, "device_connected", [got])

	# Then: The keyboard device is activated.
	assert_signal_emit_count(slot, "device_activated", 1)
	assert_signal_emitted_with_parameters(slot, "device_activated", [got])

	# Then: The keyboard is in the list of connected devices.
	assert_eq(len(slot.get_connected_devices()), 1)
	assert_has(slot.get_connected_devices(), got)


func test_input_slot_connects_and_disconnects_joypads() -> void:
	# Given: A new `InputSlot` is instantiated.
	assert_is(slot, InputSlot)

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
	joypad_monitor.joy_connected.emit(0, InputDevice.DEVICE_TYPE_XBOX)

	# Then: The joypad is active.
	var got := slot.get_active_device()
	assert_not_null(got)
	assert_is(got, InputDevice)
	assert_eq(got.device_type, InputDevice.DEVICE_TYPE_XBOX)

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
	joypad_monitor.joy_disconnected.emit(0)

	# Then: The disconnect signal was emitted.
	assert_signal_emit_count(slot, "device_disconnected", 1)
	assert_signal_emitted_with_parameters(slot, "device_disconnected", [got])

	# Then: There are no connected devices.
	assert_eq(len(slot.get_connected_devices()), 0)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	slot = null # Dereference the input slot so it can be freed.


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	# Construct input slot scene.

	slot = InputSlot.new()
	slot.glyph_type_override_property = StdSettingsPropertyInt.new()
	slot.haptics_disabled_property = StdSettingsPropertyBool.new()
	slot.haptics_strength_property = StdSettingsPropertyFloatRange.new()

	joypad_monitor = InputSlot.JoypadMonitor.new()
	slot.joypad_monitor = joypad_monitor
	slot.add_child(joypad_monitor, false, INTERNAL_MODE_BACK)

	slot.actions_kbm = add_child_autofree(StdInputDeviceActions.new())
	slot.glyphs_kbm = add_child_autofree(StdInputDeviceGlyphs.new())
	slot.haptics_kbm = add_child_autofree(StdInputDeviceHaptics.new())
	
	slot.actions_joy = add_child_autofree(StdInputDeviceActions.new())
	slot.glyphs_joy = add_child_autofree(StdInputDeviceGlyphs.new())
	slot.haptics_joy = add_child_autofree(StdInputDeviceHaptics.new())
