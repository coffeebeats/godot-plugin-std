##
## std/input/glyph.gd
##
## StdInputGlyphTextureButton is an implementation of `StdInputGlyph` which drives the
## contents of a `TextureButton` node used to rebind input origin labels.
##

@tool
class_name StdInputGlyphTextureButton
extends StdInputGlyphTextureRect

# -- CONFIGURATION ------------------------------------------------------------------- #

## update_texture_disabled determines whether the `texture_disabled` property is updated.
@export var update_texture_disabled: bool = true

## update_texture_hovered determines whether the `texture_hovered` property is updated.
@export var update_texture_hovered: bool = true

## update_texture_normal determines whether the `texture_normal` property is updated.
@export var update_texture_normal: bool = true

## update_texture_pressed determines whether the `texture_pressed` property is updated.
@export var update_texture_pressed: bool = true

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _update_target() -> void:
	var button := _target as TextureButton
	if not button:
		assert(false, "invalid state; wrong target node type")
		return

	var texture := (
		_slot
		. get_action_glyph(
			action_set.name,
			action,
			button.size if use_target_size else target_size_override,
		)
	)

	if update_texture_disabled:
		button.texture_disabled = texture
	if update_texture_hovered:
		button.texture_hovered = texture
	if update_texture_normal:
		button.texture_normal = texture
	if update_texture_pressed:
		button.texture_pressed = texture
