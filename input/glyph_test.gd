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


## Glyph records the binding index it's asked to draw on each update.
class Glyph:
	extends StdInputGlyph

	var drawn: Array[int] = []

	func _update_glyph(_device_type: DeviceType) -> bool:
		drawn.append(get_binding_index())
		return true


## Glyphs is a glyph component reporting a fixed number of origins for every action.
class Glyphs:
	extends StdInputDeviceGlyphs

	var origin_count: int = 0

	func _get_action_origin_count(
		_device: int,
		_device_type: StdInputDevice.DeviceType,
		_action_set: StdInputActionSet,
		_action: StringName,
	) -> int:
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
