##
## std/input/glyph.gd
##
## StdInputGlyphLabel is an implementation of `StdInputGlyph` which drives the contents
## of a `Label` node used to display input origin glyph icons.
##

@tool
class_name StdInputGlyphTextureRect
extends StdInputGlyph

# -- CONFIGURATION ------------------------------------------------------------------- #

## use_target_size controls whether the glyph target `Control` node's size is used as
## the requested glyph icon size.
@export var use_target_size: bool = false:
	set(value):
		use_target_size = value

		if use_target_size and target_size_override != Vector2.ZERO:
			target_size_override = Vector2.ZERO

## target_size_override is a specific target size for the rendered origin glyph. This
## will be ignored if `use_target_size` is `true`. A zero value will not constrain the
## texture's size.
@export var target_size_override: Vector2 = Vector2.ZERO

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _update_target() -> void:
	var texture_rect := _target as TextureRect
	if not texture_rect:
		assert(false, "invalid state; wrong target node type")
		return

	texture_rect.texture = (
		_slot
		. get_action_glyph(
			action_set.name,
			action,
			texture_rect.size if use_target_size else target_size_override,
		)
	)
