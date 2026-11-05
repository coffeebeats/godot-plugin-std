##
## std/input/godot/keycap_texture_test.gd
##
## Tests pertaining to the keycap texture drawn by `StdInputGlyphSetKeyboardDrawn`.
##
## NOTE: A headless run rasterizes nothing, so these tests assert on what the keycap
## hands each draw rather than on pixels.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

## _HALF is a host modulate which draws at half opacity, as a disabled button might.
const _HALF := Color(1, 1, 1, 0.5)

## _KEYCAP_TEXTURE_PATH is the keycap script, loaded in `before_all`.
const _KEYCAP_TEXTURE_PATH := "keycap_texture.gd"

## _RECT is the rect a host draws the keycap into.
const _RECT := Rect2(10, 20, 64, 32)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _canvas_item := RID()
var _glyph_set: StdInputGlyphSetKeyboardDrawn = null
var _keycap: Variant = null
var _keycap_texture: GDScript = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_keycap_texture_draw_tints_the_cap_and_the_label_by_the_modulate() -> void:
	# Given: A flat cap with a red background and a blue border.
	var cap := StyleBoxFlat.new()
	cap.bg_color = Color.RED
	cap.border_color = Color.BLUE
	_glyph_set.cap = cap

	# When: A host draws the keycap at half opacity.
	_keycap.draw_rect(_canvas_item, _RECT, false, _HALF)

	# Then: The cap is drawn with its colours at half opacity.
	var drawn: StyleBoxFlat = get_call_parameters(_keycap, "_draw_cap")[2]
	assert_eq(drawn.bg_color, Color.RED * _HALF)
	assert_eq(drawn.border_color, Color.BLUE * _HALF)

	# Then: The label is drawn at half opacity.
	assert_eq(get_call_parameters(_keycap, "_draw_label")[3], Color.WHITE * _HALF)

	# Then: The set's cap keeps its colours.
	assert_eq(cap.bg_color, Color.RED)


func test_keycap_texture_draw_tints_a_texture_cap_by_the_modulate() -> void:
	# Given: A texture cap.
	_glyph_set.cap = StyleBoxTexture.new()

	# When: A host draws the keycap at half opacity.
	_keycap.draw_rect(_canvas_item, _RECT, false, _HALF)

	# Then: The cap's texture is drawn at half opacity.
	var drawn: StyleBoxTexture = get_call_parameters(_keycap, "_draw_cap")[2]
	assert_eq(drawn.modulate_color, Color.WHITE * _HALF)


func test_keycap_texture_draw_tints_a_line_cap_by_the_modulate() -> void:
	# Given: A green line cap.
	var cap := StyleBoxLine.new()
	cap.color = Color.GREEN
	_glyph_set.cap = cap

	# When: A host draws the keycap at half opacity.
	_keycap.draw_rect(_canvas_item, _RECT, false, _HALF)

	# Then: The line is drawn at half opacity.
	var drawn: StyleBoxLine = get_call_parameters(_keycap, "_draw_cap")[2]
	assert_eq(drawn.color, Color.GREEN * _HALF)


func test_keycap_texture_draw_leaves_a_cap_without_colours_untinted() -> void:
	# Given: A cap with no colour fields.
	var cap := StyleBoxEmpty.new()
	_glyph_set.cap = cap

	# When: A host draws the keycap at half opacity.
	_keycap.draw_rect(_canvas_item, _RECT, false, _HALF)

	# Then: The set's cap is drawn as it is.
	assert_same(get_call_parameters(_keycap, "_draw_cap")[2], cap)


func test_keycap_texture_draw_draws_the_icon_in_place_of_the_label() -> void:
	# Given: A keycap with an icon.
	_keycap.icon = PlaceholderTexture2D.new()

	# When: A host draws the keycap at half opacity.
	_keycap.draw_rect(_canvas_item, _RECT, false, _HALF)

	# Then: The icon is drawn at half opacity.
	assert_eq(get_call_parameters(_keycap, "_draw_icon")[2], Color.WHITE * _HALF)

	# Then: The label isn't drawn.
	assert_not_called(_keycap, "_draw_label")


func test_keycap_texture_draw_scales_the_label_with_the_rect_height() -> void:
	# Given: A rect twice the keycap's natural height.
	var natural := (
		ThemeDB.fallback_font.get_height(_glyph_set.font_size)
		+ 2 * _glyph_set.padding.y
	)
	var rect := Rect2(0, 0, 100, natural * 2)

	# When: A host draws the keycap into the rect.
	_keycap.draw_rect(_canvas_item, rect, false, Color.WHITE)

	# Then: The label is drawn at twice the set's font size.
	assert_eq(get_call_parameters(_keycap, "_draw_label")[2], _glyph_set.font_size * 2)


func test_keycap_texture_draw_follows_edits_to_the_cap() -> void:
	# Given: A flat cap.
	var cap := StyleBoxFlat.new()
	_glyph_set.cap = cap

	# Given: The keycap was drawn once at half opacity.
	_keycap.draw_rect(_canvas_item, _RECT, false, _HALF)

	# When: The cap's corner radius changes.
	cap.corner_radius_top_left = 7

	# When: The keycap is drawn again.
	_keycap.draw_rect(_canvas_item, _RECT, false, _HALF)

	# Then: The cap is drawn with the new radius.
	var drawn: StyleBoxFlat = get_call_parameters(_keycap, "_draw_cap")[2]
	assert_eq(drawn.corner_radius_top_left, 7)


func test_keycap_texture_draw_shrinks_the_label_to_fit_a_narrow_rect() -> void:
	# Given: A keycap with a long label.
	_keycap.label = "Escape"

	# When: A host draws the keycap into a rect narrower than the label.
	var rect := Rect2(0, 0, 36, 36)
	_keycap.draw_rect(_canvas_item, rect, false, Color.WHITE)

	# Then: The label fits within the rect.
	var font_size: int = get_call_parameters(_keycap, "_draw_label")[2]
	var width := (
		ThemeDB
		. fallback_font
		. get_string_size("Escape", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		. x
	)
	assert_lte(width, rect.size.x)


func test_keycap_texture_draws_the_whole_key_through_each_draw_call() -> void:
	# Given: A cap.
	_glyph_set.cap = StyleBoxEmpty.new()

	# When: A host draws the keycap at a position.
	_keycap.draw(_canvas_item, _RECT.position)

	# Then: The cap is drawn at the keycap's size.
	assert_eq(
		get_call_parameters(_keycap, "_draw_cap")[1],
		Rect2(_RECT.position, _keycap.get_size()),
	)

	# When: A host draws the keycap into a rect.
	_keycap.draw_rect(_canvas_item, _RECT, false)

	# Then: The cap is drawn over the rect.
	assert_eq(get_call_parameters(_keycap, "_draw_cap")[1], _RECT)

	# When: A host draws a region of the keycap into the rect.
	_keycap.draw_rect_region(_canvas_item, _RECT, Rect2(0, 0, 8, 8))

	# Then: The whole cap is drawn over the rect.
	assert_eq(get_call_parameters(_keycap, "_draw_cap")[1], _RECT)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	RenderingServer.free_rid(_canvas_item)


func before_all() -> void:
	var path: String = get_script().resource_path.get_base_dir().path_join(
		_KEYCAP_TEXTURE_PATH
	)
	_keycap_texture = load(path)


func before_each() -> void:
	_canvas_item = RenderingServer.canvas_item_create()

	_glyph_set = StdInputGlyphSetKeyboardDrawn.new()
	_glyph_set.device_types = [StdInputDevice.DEVICE_TYPE_KEYBOARD]

	_keycap = partial_double(_keycap_texture).new()
	_keycap.glyph_set = _glyph_set
	_keycap.label = "E"

	stub(_keycap, "_draw_cap").to_do_nothing()
	stub(_keycap, "_draw_icon").to_do_nothing()
	stub(_keycap, "_draw_label").to_do_nothing()
