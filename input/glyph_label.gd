##
## std/input/glyph.gd
##
## StdInputGlyphLabel is an implementation of `StdInputGlyph` which drives the contents
## of a `Label` node used to display input origin labels.
##

@tool
class_name StdInputGlyphLabel
extends StdInputGlyph

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _update_target() -> void:
	var label := _target as Label
	if not label:
		assert(false, "invalid state; wrong target node type")
		return

	label.text = _slot.get_action_origin_label(action_set.name, action)
