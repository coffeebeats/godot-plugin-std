# gdlint:ignore=max-public-methods
##
## std/input/glyph_texture_test.gd
##
## Tests pertaining to the `StdInputGlyphTexture` class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## Glyphs is a glyph component returning the glyph `glyphs` maps each binding index to,
## and recording each device type and target size it's asked for.
class Glyphs:
	extends StdInputDeviceGlyphs

	var device_types: Array[StdInputDevice.DeviceType] = []
	var glyphs: Dictionary[int, Texture2D] = {}
	var target_sizes: Array[Vector2] = []

	func _get_action_glyph(
		_device: int,
		device_type: StdInputDevice.DeviceType,
		_action_set: StdInputActionSet,
		_action: StringName,
		index: int,
		target_size: Vector2,
	) -> Texture2D:
		device_types.append(device_type)
		target_sizes.append(target_size)
		return glyphs.get(index)

	func _get_action_origin_count(
		_device: int,
		_device_type: StdInputDevice.DeviceType,
		_action_set: StdInputActionSet,
		_action: StringName,
	) -> int:
		return 0

	func _get_action_origin_label(
		_device: int,
		_device_type: StdInputDevice.DeviceType,
		_action_set: StdInputActionSet,
		_action: StringName,
		index: int,
	) -> String:
		return "Origin %d" % index


## Region is a texture recording the source rect of each region drawn from it.
class Region:
	extends PlaceholderTexture2D

	var src_rects: Array[Rect2] = []

	func _draw_rect_region(
		_to_canvas_item: RID,
		_rect: Rect2,
		src_rect: Rect2,
		_modulate: Color,
		_transpose: bool,
		_clip_uv: bool,
	) -> void:
		src_rects.append(src_rect)


# -- INITIALIZATION ------------------------------------------------------------------ #

var _glyphs_joy: Glyphs = null
var _glyphs_kbm: Glyphs = null
var _slot: StdInputSlot = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_glyph_texture_binds_to_the_slot_when_first_measured() -> void:
	# Given: A key glyph for the primary binding.
	var key := _make_glyph(Vector2(32, 32))
	_glyphs_kbm.glyphs[0] = key

	# When: A texture for the action is measured.
	var texture := _make_texture()
	var width := texture.get_width()

	# Then: The texture draws the key glyph.
	assert_true(texture.has_glyph())
	assert_eq(width, 32)


func test_glyph_texture_binds_to_a_slot_added_after_it_was_measured() -> void:
	# Given: A key glyph for the primary binding.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))

	# Given: The player's slot is out of the scene.
	remove_child(_slot)

	# Given: A texture for the action, measured while no slot exists.
	var texture := _make_texture()
	assert_false(texture.has_glyph(), "precondition: no glyph")

	# When: The slot is added to the scene.
	add_child(_slot)

	# Then: The texture draws the key glyph.
	assert_true(texture.has_glyph())


func test_glyph_texture_measured_while_its_slot_is_out_rebinds_to_a_new_slot() -> void:
	# Given: A texture bound to the player's slot.
	var texture := _make_texture()
	texture.update()

	# Given: The slot is out of the scene.
	remove_child(_slot)

	# Given: The texture was measured meanwhile.
	texture.get_width()

	# When: The slot is freed.
	_slot.free()

	# When: A new slot with a 48px key glyph is added.
	_add_slot()
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(48, 32))

	# Then: The texture draws the new slot's glyph.
	assert_eq(texture.get_width(), 48)
	assert_eq(texture.get_origin_label(), "Origin 0")


func test_glyph_texture_measured_as_its_slot_leaves_rebinds_to_a_new_slot() -> void:
	# Given: A texture bound to the player's slot.
	var texture := _make_texture()
	texture.update()

	# Given: The texture is measured as the slot disconnects its devices.
	_slot.device_disconnected.connect(func(_device): texture.get_width())

	# When: The slot is freed.
	_slot.free()

	# When: A new slot with a 48px key glyph is added.
	_add_slot()
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(48, 32))

	# Then: The texture draws the new slot's glyph.
	assert_eq(texture.get_width(), 48)
	assert_eq(texture.get_origin_label(), "Origin 0")


func test_glyph_texture_redraws_on_each_slot_signal() -> void:
	# Given: A key glyph for the primary binding.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))

	# Given: A texture bound to the slot.
	var texture := _make_texture()
	texture.update()

	# Given: The texture's `changed` signal is watched.
	watch_signals(texture)

	for emit in [
		func(): _slot.action_configuration_changed.emit(),
		func(): _slot.cursor_visibility_changed.emit(true),
		func(): _slot.device_activated.emit(_slot.get_active_device()),
		func(): _slot.device_connected.emit(_slot.get_active_device()),
		func(): _slot.device_disconnected.emit(_slot.get_active_device()),
		func(): _slot.origin_labels_changed.emit(),
	]:
		# Given: A new key glyph, wider than the last.
		var width := texture.get_width() + 8
		_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(width, 32))

		# When: The slot emits the signal.
		emit.call()

		# Then: The texture draws the new glyph.
		assert_eq(texture.get_width(), width)

	# Then: The texture emitted `changed` on each signal.
	assert_signal_emit_count(texture, "changed", 6)


func test_glyph_texture_reuses_its_glyph_until_the_slot_signals() -> void:
	# Given: A key glyph for the primary binding.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))

	# Given: A texture for the action, measured once.
	var texture := _make_texture()
	texture.get_width()

	# Given: The number of glyphs fetched so far.
	var fetched := _glyphs_kbm.target_sizes.size()

	# When: The texture is measured and checked again.
	texture.get_size()
	texture.has_glyph()

	# Then: No glyph is fetched again.
	assert_eq(_glyphs_kbm.target_sizes.size(), fetched)


func test_glyph_texture_freed_while_bound_disconnects_from_the_slot() -> void:
	# Given: The slot's connections to its labels signal.
	var connections := _slot.origin_labels_changed.get_connections().size()

	# Given: A texture bound to the slot.
	var texture := _make_texture()
	texture.update()

	# Given: A weak reference to the texture.
	var ref: WeakRef = weakref(texture)

	# When: The texture is freed.
	texture = null

	# Then: The texture is gone.
	assert_null(ref.get_ref())

	# Then: The slot no longer calls it.
	assert_eq(_slot.origin_labels_changed.get_connections().size(), connections)

	# When: The slot fires.
	_slot.origin_labels_changed.emit()

	# Then: Nothing is called on the freed texture.
	assert_engine_error_count(0)


func test_glyph_texture_has_no_glyph_without_a_binding() -> void:
	# When: A texture is measured for an action with no binding.
	var texture := _make_texture()

	# Then: The texture draws nothing.
	assert_false(texture.has_glyph())


func test_glyph_texture_scales_the_glyph_to_its_size() -> void:
	# Given: A key glyph twice as wide as it's tall.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(64, 32))

	# When: A texture drawing at 48px is measured.
	var texture := _make_texture()
	texture.size = 48

	# Then: The texture is 48px tall, keeping the glyph's aspect ratio.
	assert_eq(texture.get_size(), Vector2(96, 48))

	# Then: The glyph is asked for at the texture's height.
	assert_eq(_glyphs_kbm.target_sizes.back(), Vector2(0, 48))


func test_glyph_texture_zero_size_draws_the_glyph_at_its_own_size() -> void:
	# Given: A key glyph twice as wide as it's tall.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(64, 32))

	# When: A texture with a size of zero is measured.
	var texture := _make_texture()
	texture.size = 0

	# Then: The glyph is drawn at its own size.
	assert_eq(texture.get_size(), Vector2(64, 32))


func test_glyph_texture_player_id_change_rebinds_to_that_players_slot() -> void:
	# Given: A key glyph for the primary binding.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))

	# Given: A texture bound to the slot.
	var texture := _make_texture()
	texture.update()
	assert_true(texture.has_glyph(), "precondition: glyph")

	# When: The texture is pointed at a player with no slot.
	texture.player_id = 2

	# Then: The texture draws nothing.
	assert_false(texture.has_glyph())

	# Given: The texture's `changed` signal is watched.
	watch_signals(texture)

	# When: The first player's slot signals.
	_slot.origin_labels_changed.emit()

	# Then: The texture no longer follows that slot.
	assert_signal_not_emitted(texture, "changed")

	# When: The texture is pointed back at the first player.
	texture.player_id = 1

	# Then: The texture draws the key glyph again.
	assert_true(texture.has_glyph())


func test_glyph_texture_scales_a_region_to_the_glyphs_pixels() -> void:
	# Given: A key glyph four times the texture's size.
	var glyph := Region.new()
	glyph.size = Vector2(128, 128)
	_glyphs_kbm.glyphs[0] = glyph

	# Given: A texture drawing at 32px.
	var texture := _make_texture()

	# When: A region of the texture is drawn.
	var canvas_item := RenderingServer.canvas_item_create()
	texture.draw_rect_region(canvas_item, Rect2(0, 0, 32, 32), Rect2(8, 8, 16, 16))
	RenderingServer.free_rid(canvas_item)

	# Then: The same region of the glyph is drawn.
	assert_eq(glyph.src_rects, [Rect2(32, 32, 64, 64)] as Array[Rect2])


func test_glyph_texture_advance_cycles_through_the_bound_origins() -> void:
	# Given: Key glyphs for the primary and tertiary bindings.
	var primary := _make_glyph(Vector2(32, 32))
	var tertiary := _make_glyph(Vector2(48, 32))
	_glyphs_kbm.glyphs[0] = primary
	_glyphs_kbm.glyphs[2] = tertiary

	# Given: A texture drawing the primary binding.
	var texture := _make_texture()
	assert_eq(texture.get_width(), 32, "precondition: draws primary")

	# When: The texture advances.
	texture.advance()

	# Then: The texture draws the tertiary binding, skipping the unbound one.
	assert_eq(texture.get_width(), 48)

	# When: The texture advances again.
	texture.advance()

	# Then: The texture starts over from the primary binding.
	assert_eq(texture.get_width(), 32)


func test_glyph_texture_cycles_from_the_binding_index_each_interval() -> void:
	# Given: Key glyphs for the primary, secondary and tertiary bindings.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))
	_glyphs_kbm.glyphs[1] = _make_glyph(Vector2(48, 32))
	_glyphs_kbm.glyphs[2] = _make_glyph(Vector2(64, 32))

	# Given: A texture for the secondary binding which cycles every half second.
	var texture := _make_cycling_texture(0.5)
	texture.binding_index = 1

	# When: Three intervals pass.
	var widths: Array[int] = [texture.get_width()]
	for i in 3:
		texture._tick(0.5)
		widths.append(texture.get_width())

	# Then: The texture drew the secondary and tertiary bindings in turn.
	assert_eq(widths, [48, 64, 48, 64] as Array[int])


func test_glyph_texture_cycles_on_the_scene_trees_frames() -> void:
	# Given: Key glyphs for the primary and secondary bindings.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))
	_glyphs_kbm.glyphs[1] = _make_glyph(Vector2(48, 32))

	# Given: A measured texture which cycles every hundredth of a second.
	var texture := _make_cycling_texture(0.01)
	texture.get_width()

	# Given: The texture's `changed` signal is watched.
	watch_signals(texture)

	# When: Frames pass for a tenth of a second.
	await wait_seconds(0.1)

	# Then: The texture advanced on its own.
	assert_signal_emitted(texture, "changed")


func test_glyph_texture_without_a_cycle_interval_does_not_tick() -> void:
	# Given: Key glyphs for the primary and secondary bindings.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))
	_glyphs_kbm.glyphs[1] = _make_glyph(Vector2(48, 32))

	# When: A texture which doesn't cycle is measured.
	var texture := _make_cycling_texture(0.0)
	texture.get_width()

	# Then: The texture doesn't follow the scene tree's frames.
	assert_false(get_tree().process_frame.is_connected(texture._on_process_frame))


func test_glyph_texture_with_one_origin_does_not_tick() -> void:
	# Given: A key glyph for the primary binding alone.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))

	# When: A texture which cycles every half second is measured.
	var texture := _make_cycling_texture(0.5)
	texture.get_width()

	# Then: The texture doesn't follow the scene tree's frames.
	assert_false(get_tree().process_frame.is_connected(texture._on_process_frame))


func test_glyph_texture_cycle_interval_set_later_starts_ticking() -> void:
	# Given: Key glyphs for the primary and secondary bindings.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))
	_glyphs_kbm.glyphs[1] = _make_glyph(Vector2(48, 32))

	# Given: A measured texture which doesn't cycle.
	var texture := _make_cycling_texture(0.0)
	texture.get_width()

	# When: The texture is set to cycle and measured again.
	texture.cycle_interval = 0.5
	texture.get_width()

	# Then: The texture follows the scene tree's frames.
	assert_true(get_tree().process_frame.is_connected(texture._on_process_frame))


func test_glyph_texture_cycle_advances_once_after_a_long_frame() -> void:
	# Given: Key glyphs for the primary, secondary and tertiary bindings.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))
	_glyphs_kbm.glyphs[1] = _make_glyph(Vector2(48, 32))
	_glyphs_kbm.glyphs[2] = _make_glyph(Vector2(64, 32))

	# Given: A texture which cycles every half second.
	var texture := _make_cycling_texture(0.5)

	# When: A frame six intervals long passes, then a short one.
	texture._tick(3.0)
	texture._tick(0.1)

	# Then: The texture advanced once, without catching up.
	assert_eq(texture.get_width(), 48)

	# When: The rest of an interval passes.
	texture._tick(0.4)

	# Then: The texture advanced again.
	assert_eq(texture.get_width(), 64)


func test_glyph_texture_update_restarts_the_cycle() -> void:
	# Given: Key glyphs for the primary and secondary bindings.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))
	_glyphs_kbm.glyphs[1] = _make_glyph(Vector2(48, 32))

	# Given: A texture which cycles every half second, advanced once.
	var texture := _make_cycling_texture(0.5)
	texture._tick(0.5)
	assert_eq(texture.get_width(), 48, "precondition: advanced")

	# Given: Part of the next interval passed.
	texture._tick(0.25)

	# When: The texture is updated.
	texture.update()

	# Then: The texture draws the primary binding again.
	assert_eq(texture.get_width(), 32)

	# When: The same part of an interval passes.
	texture._tick(0.25)

	# Then: The texture waits out a whole interval before advancing.
	assert_eq(texture.get_width(), 32)


func test_glyph_texture_cycle_freezes_while_the_tree_is_paused() -> void:
	# Given: Key glyphs for the primary and secondary bindings.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))
	_glyphs_kbm.glyphs[1] = _make_glyph(Vector2(48, 32))

	# Given: A texture which cycles every half second, but not while paused.
	var texture := _make_cycling_texture(0.5)
	texture.cycle_process_always = false

	# Given: Half an interval passed.
	texture._tick(0.25)

	# When: An interval passes while the tree is paused.
	get_tree().paused = true
	texture._tick(0.5)

	# Then: The texture didn't advance.
	assert_eq(texture.get_width(), 32)

	# When: The rest of the interval passes after the tree resumes.
	get_tree().paused = false
	texture._tick(0.25)

	# Then: The texture advanced.
	assert_eq(texture.get_width(), 48)


func test_glyph_texture_cycle_runs_while_the_tree_is_paused() -> void:
	# Given: Key glyphs for the primary and secondary bindings.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))
	_glyphs_kbm.glyphs[1] = _make_glyph(Vector2(48, 32))

	# Given: A texture which cycles every half second.
	var texture := _make_cycling_texture(0.5)

	# When: An interval passes while the tree is paused.
	get_tree().paused = true
	texture._tick(0.5)

	# Then: The texture advanced.
	assert_eq(texture.get_width(), 48)


func test_glyph_texture_draws_a_secondary_binding_with_no_primary() -> void:
	# Given: A key glyph for the secondary binding alone.
	_glyphs_kbm.glyphs[1] = _make_glyph(Vector2(32, 32))

	# When: A texture for the primary binding is measured.
	var texture := _make_texture()

	# Then: The texture draws the secondary binding.
	assert_true(texture.has_glyph())
	assert_eq(texture.get_origin_label(), "Origin 1")


func test_glyph_texture_fallback_with_no_binding_in_the_active_category() -> void:
	# Given: A joypad glyph for the action and no key glyph.
	_glyphs_joy.glyphs[0] = _make_glyph(Vector2(40, 32))

	# Given: A texture for the action, with the keyboard active.
	var texture := _make_texture()

	# When: The texture falls back to the other category.
	texture.fallback = StdInputGlyphTexture.Fallback.OTHER_CATEGORY

	# Then: The texture draws the joypad glyph.
	assert_eq(texture.get_size(), Vector2(40, 32))

	# When: The texture falls back to nothing.
	texture.fallback = StdInputGlyphTexture.Fallback.NONE

	# Then: The texture draws nothing at its size.
	assert_false(texture.has_glyph())
	assert_eq(texture.get_size(), Vector2(32, 32))

	# When: The texture hides as its fallback.
	texture.fallback = StdInputGlyphTexture.Fallback.HIDE

	# Then: The texture draws nothing at no size.
	assert_false(texture.has_glyph())
	assert_eq(texture.get_size(), Vector2.ZERO)


func test_glyph_texture_locked_without_a_binding_ignores_its_fallback() -> void:
	# Given: A joypad glyph for the action and no key glyph.
	_glyphs_joy.glyphs[0] = _make_glyph(Vector2(40, 32))

	# Given: A texture locked to the keyboard.
	var texture := _make_texture()
	texture.device_type = StdInputDevice.DEVICE_TYPE_KEYBOARD

	for value in StdInputGlyphTexture.Fallback.values():
		# When: The texture's fallback is set.
		texture.fallback = value

		# Then: The texture draws nothing at its size.
		assert_false(texture.has_glyph())
		assert_eq(texture.get_size(), Vector2(32, 32))


func test_glyph_texture_generic_lock_draws_the_connected_joypad_family() -> void:
	# Given: A connected PlayStation 5 joypad, with the keyboard kept active.
	_connect_joypad(StdInputDevice.DEVICE_TYPE_PS_5)

	# Given: A texture locked to a controller.
	var texture := _make_texture()
	texture.device_type = StdInputDevice.DEVICE_TYPE_GENERIC

	# When: The texture is measured.
	texture.get_width()

	# Then: The joypad's family is drawn.
	assert_eq(_glyphs_joy.device_types.back(), StdInputDevice.DEVICE_TYPE_PS_5)


func test_glyph_texture_generic_lock_draws_the_players_controller_setting() -> void:
	# Given: A connected Xbox joypad, with the keyboard kept active.
	_connect_joypad(StdInputDevice.DEVICE_TYPE_XBOX_ONE)

	# Given: A texture locked to a controller.
	var texture := _make_texture()
	texture.device_type = StdInputDevice.DEVICE_TYPE_GENERIC

	# Given: The player chose PlayStation 5 glyphs.
	texture.device_type_override = _make_override(StdInputDevice.DEVICE_TYPE_PS_5)

	# When: The texture is measured.
	texture.get_width()

	# Then: The player's choice is drawn.
	assert_eq(_glyphs_joy.device_types.back(), StdInputDevice.DEVICE_TYPE_PS_5)


func test_glyph_texture_restricted_ignores_a_setting_in_the_other_category() -> void:
	# Given: A key glyph for the action, with the keyboard active.
	_glyphs_kbm.glyphs[0] = _make_glyph(Vector2(32, 32))

	# Given: A texture for a player who chose PlayStation 5 glyphs.
	var texture := _make_texture()
	texture.device_type_override = _make_override(StdInputDevice.DEVICE_TYPE_PS_5)

	# Given: The texture is restricted to the active category.
	texture.restrict_to_device_category = true

	# When: The texture is measured.
	texture.get_width()

	# Then: The keyboard is drawn.
	assert_eq(_glyphs_kbm.device_types.back(), StdInputDevice.DEVICE_TYPE_KEYBOARD)
	assert_eq(_glyphs_joy.device_types, [] as Array[StdInputDevice.DeviceType])


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	get_tree().paused = false


func before_each() -> void:
	_add_slot()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_slot adds a slot for the player, whose glyph components are `Glyphs` ones.
func _add_slot() -> void:
	_slot = SlotTest.make_slot()
	_slot.prefer_activate_joypad_on_ready = false

	_glyphs_kbm = _replace_glyphs(&"glyphs_kbm")
	_glyphs_joy = _replace_glyphs(&"glyphs_joy")

	add_child_autofree(_slot)
	autofree(_slot.get_active_device())


## _connect_joypad connects a joypad of `device_type` to the slot without activating it.
func _connect_joypad(device_type: StdInputDevice.DeviceType) -> void:
	_slot.joypad_monitor.connected = [0] as Array[int]
	_slot.joypad_monitor.device_type = device_type
	_slot.joypad_monitor.broadcast_connected_joypads()
	autofree(_slot.get_connected_devices(false)[0])


## _make_cycling_texture returns a texture for the test action's primary binding which
## cycles every `interval` seconds.
func _make_cycling_texture(interval: float) -> StdInputGlyphTexture:
	var texture := _make_texture()
	texture.cycle_interval = interval
	return texture


## _make_glyph returns a glyph of `size`.
func _make_glyph(size: Vector2) -> Texture2D:
	var glyph := PlaceholderTexture2D.new()
	glyph.size = size
	return glyph


## _make_override returns a device type setting whose value defaults to `value`, in a
## new scope which isn't loaded yet.
func _make_override(value: StdInputDevice.DeviceType) -> StdSettingsPropertyInt:
	var property := StdSettingsPropertyInt.new()
	property.scope = StdSettingsScope.new()
	property.category = &"test"
	property.name = &"device_type"
	property.default = value
	return property


## _make_texture returns a texture for the test action's primary binding.
func _make_texture() -> StdInputGlyphTexture:
	var action_set := StdInputActionSet.new()
	action_set.name = &"Test"
	action_set.actions_digital = [&"test_action"]

	var texture := StdInputGlyphTexture.new()
	texture.action_set = action_set
	texture.action = &"test_action"
	return texture


## _replace_glyphs swaps the slot's glyph component `property` for a `Glyphs` one and
## returns it.
func _replace_glyphs(property: StringName) -> Glyphs:
	_slot.get(property).free()

	var glyphs := Glyphs.new()
	_slot.add_child(glyphs)
	_slot.set(property, glyphs)

	return glyphs
