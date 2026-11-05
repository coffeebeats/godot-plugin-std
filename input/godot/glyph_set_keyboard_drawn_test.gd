##
## std/input/godot/glyph_set_keyboard_drawn_test.gd
##
## Tests pertaining to the `StdInputGlyphSetKeyboardDrawn` class.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var _glyph_set: StdInputGlyphSetKeyboardDrawn = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_keyboard_drawn_glyph_widens_for_a_longer_label() -> void:
	# Given: The glyph of a key with a one-letter label.
	var short := _glyph_set.get_origin_glyph(_key(KEY_E))

	# When: The glyph of a key with a longer label is fetched.
	var long := _glyph_set.get_origin_glyph(_key(KEY_ESCAPE))

	# Then: The longer label's cap is wider.
	assert_gt(long.get_width(), short.get_width())


func test_keyboard_drawn_glyph_holds_a_short_label_to_the_min_width() -> void:
	# Given: A minimum keycap width wider than a one-letter label.
	_glyph_set.min_width = 100.0

	# When: The glyph of a key with a one-letter label is fetched.
	var got := _glyph_set.get_origin_glyph(_key(KEY_E))

	# Then: The cap is the minimum width.
	assert_eq(got.get_width(), 100)


func test_keyboard_drawn_glyph_draws_an_icon_over_the_label() -> void:
	# Given: An icon for the up arrow key.
	var icon := PlaceholderTexture2D.new()
	_glyph_set.icons[KEY_UP] = icon

	# When: The up arrow key's glyph is fetched.
	var got: Variant = _glyph_set.get_origin_glyph(_key(KEY_UP))

	# Then: The keycap draws the icon in place of the key's label.
	assert_eq(got.icon, icon)
	assert_eq(got.label, "")


func test_keyboard_drawn_glyph_applies_a_label_override() -> void:
	# Given: A shorter label for the escape key.
	_glyph_set.labels["Escape"] = "Esc"

	# When: The escape key's glyph is fetched.
	var got: Variant = _glyph_set.get_origin_glyph(_key(KEY_ESCAPE))

	# Then: The keycap draws the shorter label.
	assert_eq(got.label, "Esc")


func test_keyboard_drawn_glyph_is_as_tall_as_the_target_size() -> void:
	# When: A key's glyph is fetched for a host 48px tall.
	var got := _glyph_set.get_origin_glyph(_key(KEY_E), Vector2(0, 48))

	# Then: The keycap is 48px tall.
	assert_eq(got.get_height(), 48)


func test_keyboard_drawn_glyph_has_its_natural_height_without_a_target() -> void:
	# Given: The height of a line of the label plus the vertical padding.
	var want := ceili(
		(
			ThemeDB.fallback_font.get_height(_glyph_set.font_size)
			+ 2 * _glyph_set.padding.y
		)
	)

	# When: A key's glyph is fetched with no target size.
	var got := _glyph_set.get_origin_glyph(_key(KEY_E))

	# Then: The keycap is its natural height.
	assert_eq(got.get_height(), want)


func test_keyboard_drawn_glyph_reuses_the_keycap_at_one_height() -> void:
	# Given: A key's glyph, fetched for a host 48px tall.
	var first := _glyph_set.get_origin_glyph(_key(KEY_E), Vector2(0, 48))

	# When: The key's glyph is fetched again at that height.
	var again := _glyph_set.get_origin_glyph(_key(KEY_E), Vector2(0, 48))

	# When: The key's glyph is fetched at another height.
	var other := _glyph_set.get_origin_glyph(_key(KEY_E), Vector2(0, 24))

	# Then: The same keycap is returned at the same height only.
	assert_same(again, first)
	assert_not_same(other, first)


func test_keyboard_drawn_glyph_returns_null_for_a_mouse_button() -> void:
	# Given: A binding to a mouse button.
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT

	# When: The glyph is fetched for the binding.
	var got := _glyph_set.get_origin_glyph(event)

	# Then: No glyph is returned, so a mouse set can supply one.
	assert_null(got)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_glyph_set = StdInputGlyphSetKeyboardDrawn.new()
	_glyph_set.device_types = [StdInputDevice.DEVICE_TYPE_KEYBOARD]


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _key returns a binding to the physical key `keycode`.
func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event
