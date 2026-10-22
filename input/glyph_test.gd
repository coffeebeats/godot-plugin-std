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

	func _update_glyph(device_type: DeviceType) -> bool:
		device_types.append(device_type)
		drawn.append(binding_index)
		return true


## Glyphs is a glyph component reporting no glyph for every action and recording the
## device each glyph was asked for.
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


# -- INITIALIZATION ------------------------------------------------------------------ #

var slot: StdInputSlot = null
var glyphs: Glyphs = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_glyph_generic_override_draws_the_connected_joypad_family() -> void:
	# Given: The keyboard stays active when a joypad connects.
	slot.prefer_activate_joypad_on_ready = false

	# Given: A glyph locked to generic controller prompts.
	var glyph := _make_glyph(0)
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
	var glyph := _make_glyph(0)
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


## _make_glyph adds a glyph for the test action to the scene, drawing binding `index`.
func _make_glyph(index: int) -> Glyph:
	var action_set := StdInputActionSet.new()
	action_set.name = &"Test"
	action_set.actions_digital = [&"test_action"]

	var glyph := Glyph.new()
	glyph.action_set = action_set
	glyph.action = &"test_action"
	glyph.binding_index = index
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
