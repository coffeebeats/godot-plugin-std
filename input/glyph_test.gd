##
## std/input/glyph_test.gd
##
## Tests pertaining to the `StdInputGlyph` class.
##

# NOTE: `StdInputGlyph` is a tool script, so a subclass must be one as well.
@tool
extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## Glyph records the binding index and device type it's asked to draw on each update.
class Glyph:
	extends StdInputGlyph

	var device_types: Array[DeviceType] = []
	var drawn: Array[int] = []

	func _update_glyph(device_type: DeviceType, index: int) -> bool:
		device_types.append(device_type)
		drawn.append(index)
		return true


## Glyphs is a glyph component reporting no glyph and a fixed number of origins for
## every action, recording the device each was asked for.
class Glyphs:
	extends StdInputDeviceGlyphs

	var devices: Array[int] = []
	var origin_count: int = 0

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
		return origin_count


# -- INITIALIZATION ------------------------------------------------------------------ #

var slot: StdInputSlot = null
var glyphs: Glyphs = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_glyph_cycles_through_every_origin_from_the_binding_index() -> void:
	# Given: A slot whose glyph component reports three origins for the action.
	glyphs.origin_count = 3

	# Given: A glyph for the secondary binding which cycles every half second.
	var glyph := _make_glyph(1, 0.5)
	glyph.update()

	# When: Three intervals pass.
	for i in 3:
		glyph._process(0.5)

	# Then: The glyph drew the secondary and tertiary bindings in turn.
	assert_eq(glyph.drawn, [1, 2, 1, 2] as Array[int])


func test_glyph_without_cycle_interval_keeps_binding_index() -> void:
	# Given: A slot whose glyph component reports three origins for the action.
	glyphs.origin_count = 3

	# Given: A glyph for the primary binding which doesn't cycle.
	var glyph := _make_glyph(0, 0.0)
	glyph.update()

	# When: Time passes.
	glyph._process(1.0)

	# Then: The glyph only drew the primary binding.
	assert_eq(glyph.drawn, [0] as Array[int])


func test_glyph_with_one_origin_does_not_cycle() -> void:
	# Given: A slot whose glyph component reports one origin for the action.
	glyphs.origin_count = 1

	# Given: A glyph for the primary binding which cycles every half second.
	var glyph := _make_glyph(0, 0.5)
	glyph.update()

	# When: Time passes.
	glyph._process(1.0)

	# Then: The glyph only drew the primary binding.
	assert_eq(glyph.drawn, [0] as Array[int])


func test_glyph_advances_once_after_a_long_frame() -> void:
	# Given: A slot whose glyph component reports three origins for the action.
	glyphs.origin_count = 3

	# Given: A glyph for the primary binding which cycles every half second.
	var glyph := _make_glyph(0, 0.5)
	glyph.update()

	# When: A frame six intervals long passes, then a short one.
	glyph._process(3.0)
	glyph._process(0.1)

	# Then: The glyph advanced once, without catching up.
	assert_eq(glyph.drawn, [0, 1] as Array[int])

	# When: The rest of an interval passes.
	glyph._process(0.4)

	# Then: The glyph advanced again.
	assert_eq(glyph.drawn, [0, 1, 2] as Array[int])


func test_glyph_cycle_interval_set_after_ready_starts_cycling() -> void:
	# Given: A slot whose glyph component reports two origins for the action.
	glyphs.origin_count = 2

	# Given: A glyph for the primary binding which doesn't cycle.
	var glyph := _make_glyph(0, 0.0)
	glyph.update()

	# When: Cycling is enabled and an interval passes.
	glyph.cycle_interval = 0.5
	glyph._process(0.5)

	# Then: The glyph redrew on the change and then advanced.
	assert_eq(glyph.drawn, [0, 0, 1] as Array[int])


func test_glyph_update_restarts_the_cycle() -> void:
	# Given: A slot whose glyph component reports three origins for the action.
	glyphs.origin_count = 3

	# Given: A glyph for the primary binding which cycles every half second and has
	# advanced once.
	var glyph := _make_glyph(0, 0.5)
	glyph.update()
	glyph._process(0.5)
	assert_eq(glyph.drawn, [0, 1] as Array[int], "precondition: advanced")

	# When: The glyph is updated and an interval passes.
	glyph.update()
	glyph._process(0.5)

	# Then: The cycle restarted from the primary binding.
	assert_eq(glyph.drawn, [0, 1, 0, 1] as Array[int])


func test_glyph_generic_override_draws_the_connected_joypad_family() -> void:
	# Given: The keyboard stays active when a joypad connects.
	slot.prefer_activate_joypad_on_ready = false

	# Given: A glyph locked to generic controller prompts.
	var glyph := _make_glyph(0, 0.0)
	glyph.device_type_override = _make_override(StdInputDevice.DEVICE_TYPE_GENERIC)
	glyph.update()

	# Then: The glyph draws generic prompts while no joypad is connected.
	assert_eq(glyph.device_types.back(), StdInputDevice.DEVICE_TYPE_GENERIC)

	# When: A PlayStation 5 joypad connects without becoming active.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_PS_5
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[0])

	# Then: The glyph draws the connected joypad's family.
	assert_eq(glyph.device_types.back(), StdInputDevice.DEVICE_TYPE_PS_5)


func test_glyph_refreshes_when_a_joypad_connects_and_disconnects() -> void:
	# Given: A glyph for the primary binding, with the keyboard kept active.
	slot.prefer_activate_joypad_on_ready = false
	var glyph := _make_glyph(0, 0.0)
	glyph.update()
	assert_eq(glyph.drawn.size(), 1, "precondition: drawn once")

	# When: A joypad connects.
	slot.joypad_monitor.connected = [0] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_PS_5
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[0])

	# Then: The glyph redrew.
	assert_eq(glyph.drawn.size(), 2)

	# When: The joypad disconnects.
	slot.joypad_monitor.joy_disconnected.emit(0)

	# Then: The glyph redrew again.
	assert_eq(glyph.drawn.size(), 3)


func test_slot_glyphs_draw_the_first_connected_joypad_when_none_was_active() -> void:
	# Given: A joypad connected while the keyboard stays active.
	slot.prefer_activate_joypad_on_ready = false
	slot.joypad_monitor.connected = [5] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_PS_5
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[0])
	assert_null(slot.get_last_active_joypad_device(), "precondition: none active")

	# When: A controller glyph is requested through the slot.
	var action_set := StdInputActionSet.new()
	action_set.name = &"Test"
	action_set.actions_digital = [&"test_action"]
	slot.get_action_glyph(
		action_set, &"test_action", 0, Vector2.ZERO, StdInputDevice.DEVICE_TYPE_PS_5
	)

	# Then: The connected joypad's device was queried.
	assert_eq(glyphs.devices.back(), 5)


func test_slot_glyphs_query_the_first_connected_joypad_when_none_was_active() -> void:
	# Given: A joypad connected while the keyboard stays active.
	slot.prefer_activate_joypad_on_ready = false
	slot.joypad_monitor.connected = [5] as Array[int]
	slot.joypad_monitor.device_type = StdInputDevice.DEVICE_TYPE_PS_5
	slot.joypad_monitor.broadcast_connected_joypads()
	autofree(slot.get_connected_devices(false)[0])
	assert_null(slot.get_last_active_joypad_device(), "precondition: none active")

	# When: A controller origin count is requested through the slot.
	var action_set := StdInputActionSet.new()
	action_set.name = &"Test"
	action_set.actions_digital = [&"test_action"]
	slot.get_action_origin_count(
		action_set, &"test_action", StdInputDevice.DEVICE_TYPE_PS_5
	)

	# Then: The connected joypad's device was queried.
	assert_eq(glyphs.devices.back(), 5)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	slot = SlotTest.make_slot()

	glyphs = Glyphs.new()
	slot.add_child(glyphs)
	slot.glyphs_kbm = glyphs
	slot.glyphs_joy = glyphs

	add_child_autofree(slot)
	autofree(slot.get_active_device())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _make_glyph adds a glyph for the test action to the scene, drawing binding `index`
## and cycling every `interval` seconds.
func _make_glyph(index: int, interval: float) -> Glyph:
	var action_set := StdInputActionSet.new()
	action_set.name = &"Test"
	action_set.actions_digital = [&"test_action"]

	var glyph := Glyph.new()
	glyph.action_set = action_set
	glyph.action = &"test_action"
	glyph.binding_index = index
	glyph.cycle_interval = interval
	add_child_autofree(glyph)

	return glyph


## _make_override returns a glyph type override property whose value defaults to
## `value`, in a new scope which isn't loaded yet.
func _make_override(value: StdInputDevice.DeviceType) -> StdSettingsPropertyInt:
	var property := StdSettingsPropertyInt.new()
	property.scope = StdSettingsScope.new()
	property.category = &"test"
	property.name = &"device_type"
	property.default = value
	return property
