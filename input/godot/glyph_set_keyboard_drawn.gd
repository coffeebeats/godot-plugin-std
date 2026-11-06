##
## std/input/godot/glyph_set_keyboard_drawn.gd
##
## StdInputGlyphSetKeyboardDrawn is a keyboard glyph set which draws each key from one
## keycap style, so every layout and language gets glyphs with no art per key. A glyph
## dims with the host's modulate, as a texture does.
##
## NOTE: Each size is for a keycap of natural height, which is a line of the label
## plus the vertical padding, and scales with the height a host asks for.
##

class_name StdInputGlyphSetKeyboardDrawn
extends StdInputGlyphSet

# -- DEPENDENCIES -------------------------------------------------------------------- #

const KeycapTexture := preload("keycap_texture.gd")
const Origin := preload("origin.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## cap is the style drawn behind each key's label; left empty, the label is drawn alone.
##
## NOTE: Only a `StyleBoxFlat`, `StyleBoxTexture` or `StyleBoxLine` is tinted by the
## host's modulate. Any other stylebox is drawn untinted, with a warning.
@export var cap: StyleBox = null

## font draws each key's label; left empty, the theme's fallback font is used.
@export var font: Font = null

## font_size is the size of each key's label on a keycap of natural height; a host
## drawing the keycap taller or shorter scales it to match.
@export var font_size: int = 16

## color is the colour of each key's label or icon.
@export var color: Color = Color.WHITE

## padding is the space between a key's label and its cap's edge, on each side, on a
## keycap of natural height; it scales with the keycap as `font_size` does.
@export var padding: Vector2 = Vector2(8, 4)

## min_width is the narrowest a keycap of natural height is drawn, so that short labels
## share a width; it scales with the keycap as `font_size` does.
@export var min_width: float = 0.0

## labels maps a key's label to the label drawn in its place, such as "Escape" to "Esc".
##
## NOTE: The label drawn is then translated, so a game's translations can name keys in
## the player's language. Untranslated, a key with no printed character keeps its
## English name.
@export var labels: Dictionary[String, String] = {}

## icons maps a key to the icon drawn on its cap in place of its label, such as an
## arrow. An icon is tinted `color`, as a label is.
@export var icons: Dictionary[Key, Texture2D] = {}

# -- INITIALIZATION ------------------------------------------------------------------ #

## _keycaps maps each icon, label and height, as an `Array`, to a weak reference to the
## keycap drawn for them.
##
## NOTE: A keycap holds its set, so the references are weak to keep the set freeable;
## a keycap no host holds is freed and drawn anew when next asked for.
var _keycaps: Dictionary[Array, WeakRef] = {}

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_origin_glyph(
	event: InputEvent,
	target_size: Vector2,
) -> Texture2D:
	assert(
		(
			len(device_types) == 1
			&& device_types[0] == StdInputDevice.DEVICE_TYPE_KEYBOARD
		),
		"invalid state; wrong device type",
	)

	if not event is InputEventKey:
		return null

	var keycode: Key = (
		event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	)

	var icon: Texture2D = icons.get(keycode)

	var label := ""
	if not icon:
		label = Origin.get_key_label(event)
		label = labels.get(label, label)

		if not label:
			return null

		label = tr(label)

	var height := roundi(target_size.y) if target_size.y > 0 else 0

	var key: Array = [icon, label, height]
	var ref: WeakRef = _keycaps.get(key)

	var keycap: KeycapTexture = ref.get_ref() if ref else null
	if keycap:
		return keycap

	keycap = KeycapTexture.new()
	keycap.glyph_set = self
	keycap.height = height
	keycap.icon = icon
	keycap.label = label

	_keycaps[key] = weakref(keycap)

	return keycap
