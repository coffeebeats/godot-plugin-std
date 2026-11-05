##
## std/input/godot/keycap_texture.gd
##
## A texture which draws one key as a `StdInputGlyphSetKeyboardDrawn`'s cap with the
## key's label or icon centred on it. It draws on the host's canvas item at whatever
## rect the host gives it, scaling the label with the rect's height and shrinking it
## to fit a narrower rect.
##
## NOTE: A draw can't be clipped, so a host drawing a region of it gets the whole key.
##

extends Texture2D

# -- CONFIGURATION ------------------------------------------------------------------- #

## glyph_set is the drawn keyboard set whose style the keycap is drawn in.
var glyph_set: StdInputGlyphSetKeyboardDrawn = null

## height is the keycap's height in pixels, or zero for its natural height.
var height: int = 0

## icon is drawn on the cap in place of `label` when set.
var icon: Texture2D = null

## label is the text drawn on the cap.
var label: String = ""

# -- INITIALIZATION ------------------------------------------------------------------ #

# gdlint:ignore=class-definitions-order
static var _logger := StdLogger.create("std/input/godot/keycap_texture")

## _warned_caps holds the instance ID of each cap warned about being drawn untinted, so
## that the warning is logged once per cap.
static var _warned_caps := PackedInt64Array()  # gdlint:ignore=class-definitions-order

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _draw(
	to_canvas_item: RID, pos: Vector2, modulate: Color, _transpose: bool
) -> void:
	_draw_keycap(to_canvas_item, Rect2(pos, get_size()), modulate)


func _draw_rect(
	to_canvas_item: RID,
	rect: Rect2,
	_tile: bool,
	modulate: Color,
	_transpose: bool,
) -> void:
	_draw_keycap(to_canvas_item, rect, modulate)


func _draw_rect_region(
	to_canvas_item: RID,
	rect: Rect2,
	_src_rect: Rect2,
	modulate: Color,
	_transpose: bool,
	_clip_uv: bool,
) -> void:
	_draw_keycap(to_canvas_item, rect, modulate)


func _get_height() -> int:
	return height if height > 0 else ceili(_get_natural_height())


func _get_width() -> int:
	var scale := _get_height() / _get_natural_height()
	var face := _get_face_size(_get_font_size(scale))

	return ceili(
		maxf(glyph_set.min_width * scale, face.x + 2.0 * glyph_set.padding.x * scale)
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _draw_cap draws `cap` over `rect` on `canvas_item`.
func _draw_cap(canvas_item: RID, rect: Rect2, cap: StyleBox) -> void:
	cap.draw(canvas_item, rect)


## _draw_icon draws `icon` over `rect` on `canvas_item`, tinted `color`.
func _draw_icon(canvas_item: RID, rect: Rect2, color: Color) -> void:
	icon.draw_rect(canvas_item, rect, false, color)


## _draw_keycap draws the cap over `rect` and centres the label or icon on it, with
## every colour multiplied by the host's `modulate`.
func _draw_keycap(canvas_item: RID, rect: Rect2, modulate: Color) -> void:
	rect = rect.abs()

	if glyph_set.cap:
		_draw_cap(canvas_item, rect, _tint_cap(glyph_set.cap, modulate))

	var color := glyph_set.color * modulate
	var scale := rect.size.y / _get_natural_height()
	var font_size := _get_font_size(scale)
	var needed := _get_face_size(font_size).x + 2.0 * glyph_set.padding.x * scale
	if needed > rect.size.x:
		font_size = _get_font_size(scale * rect.size.x / needed)

	var face := Rect2(Vector2.ZERO, _get_face_size(font_size))
	face.position = rect.get_center() - face.size / 2.0

	if icon:
		_draw_icon(canvas_item, face, color)
		return

	var baseline := face.position + Vector2(0, _get_font().get_ascent(font_size))
	_draw_label(canvas_item, baseline, font_size, color)


## _draw_label draws `label` with its baseline starting at `baseline` on `canvas_item`,
## at `font_size` and tinted `color`.
func _draw_label(
	canvas_item: RID,
	baseline: Vector2,
	font_size: int,
	color: Color,
) -> void:
	(
		_get_font()
		. draw_string(
			canvas_item,
			baseline,
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			color,
		)
	)


## _get_face_size returns the size of the label or icon at `font_size`. An icon is as
## tall as a line of the label and keeps its aspect ratio.
func _get_face_size(font_size: int) -> Vector2:
	var font := _get_font()
	var line := font.get_height(font_size)

	if icon:
		return Vector2(line * icon.get_size().aspect(), line)

	var text := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Vector2(text.x, line)


## _get_font returns the set's font, or the theme's fallback font when it has none.
func _get_font() -> Font:
	return glyph_set.font if glyph_set.font else ThemeDB.fallback_font


## _get_font_size returns the set's font size scaled by `scale`.
func _get_font_size(scale: float) -> int:
	return maxi(1, roundi(glyph_set.font_size * scale))


## _get_natural_height returns the height of a keycap drawn at the set's font size,
## which is a line of the label plus the vertical padding.
func _get_natural_height() -> float:
	assert(glyph_set.font_size > 0, "invalid config; font size must be positive")
	return _get_font().get_height(glyph_set.font_size) + 2.0 * glyph_set.padding.y


## _tint_cap returns `cap` with its colours multiplied by `modulate`. A stylebox other
## than a `StyleBoxFlat`, `StyleBoxTexture` or `StyleBoxLine` is returned untinted.
func _tint_cap(cap: StyleBox, modulate: Color) -> StyleBox:
	if modulate == Color.WHITE:
		return cap

	if not (cap is StyleBoxFlat or cap is StyleBoxTexture or cap is StyleBoxLine):
		if cap.get_instance_id() not in _warned_caps:
			_warned_caps.append(cap.get_instance_id())
			_logger.warn("Keycap can't tint cap; drawing it untinted.", {&"cap": cap})

		return cap

	# NOTE: Each draw copies the source afresh, so an edit to the set's cap reaches tinted
	# draws; a copy kept between draws would miss it.
	var tinted_cap := cap.duplicate()

	if cap is StyleBoxFlat:
		var source := cap as StyleBoxFlat
		var tinted := tinted_cap as StyleBoxFlat
		tinted.bg_color = source.bg_color * modulate
		tinted.border_color = source.border_color * modulate
		tinted.shadow_color = source.shadow_color * modulate
	elif cap is StyleBoxTexture:
		var source := cap as StyleBoxTexture
		var tinted := tinted_cap as StyleBoxTexture
		tinted.modulate_color = source.modulate_color * modulate
	elif cap is StyleBoxLine:
		var source := cap as StyleBoxLine
		var tinted := tinted_cap as StyleBoxLine
		tinted.color = source.color * modulate

	return tinted_cap
