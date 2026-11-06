##
## std/input/slot_glyphs_test.gd
##
## Tests pertaining to how a `StdInputSlot` routes glyph queries to a joypad.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## Glyphs is a glyph component which draws nothing and records the device each query
## was for.
class Glyphs:
	extends StdInputDeviceGlyphs

	var devices: Array[int] = []

	func _get_action_glyph(
		device: int,
		_device_type: StdInputDevice.DeviceType,
		_action_set: StdInputActionSet,
		_action: StringName,
		_index: int,
		_target_size: Vector2,
	) -> Texture2D:
		devices.append(device)
		return null

	func _get_action_origin_count(
		device: int,
		_device_type: StdInputDevice.DeviceType,
		_action_set: StdInputActionSet,
		_action: StringName,
	) -> int:
		devices.append(device)
		return 0


# -- INITIALIZATION ------------------------------------------------------------------ #

var action_set: StdInputActionSet = null
var glyphs: Glyphs = null
var slot: StdInputSlot = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_slot_action_glyph_reads_the_first_joypad_with_none_active() -> void:
	# Given: A joypad connected while the keyboard stays active.
	_connect_inactive_joypad(5)

	# When: A controller glyph is requested through the slot.
	slot.get_action_glyph(
		action_set, &"test_action", 0, Vector2.ZERO, StdInputDevice.DEVICE_TYPE_PS_5
	)

	# Then: The connected joypad's device was queried.
	assert_eq(glyphs.devices.back(), 5)


func test_input_slot_origin_count_reads_the_first_joypad_with_none_active() -> void:
	# Given: A joypad connected while the keyboard stays active.
	_connect_inactive_joypad(5)

	# When: A controller origin count is requested through the slot.
	slot.get_action_origin_count(
		action_set, &"test_action", StdInputDevice.DEVICE_TYPE_PS_5
	)

	# Then: The connected joypad's device was queried.
	assert_eq(glyphs.devices.back(), 5)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	action_set = StdInputActionSet.new()
	action_set.name = &"Test"
	action_set.actions_digital = [&"test_action"]

	slot = SlotTest.make_slot()

	glyphs = Glyphs.new()
	slot.glyphs_joy = glyphs
	slot.add_child(glyphs)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _connect_inactive_joypad adds the slot to the scene with the keyboard active and
## connects a PlayStation 5 joypad `device`, which never becomes active.
func _connect_inactive_joypad(device: int) -> void:
	slot.prefer_activate_joypad_on_ready = false
	add_child_autofree(slot)
	autofree(slot.get_active_device())

	slot.joypad_monitor.connected = [device] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_PS_5
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[0])
	assert_null(slot.get_last_active_joypad_device(), "precondition: none active")
