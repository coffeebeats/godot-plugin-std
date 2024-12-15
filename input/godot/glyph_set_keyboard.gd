##
## std/input/action_set_keyboard.gd
##
## StdInputGlyphSetKeyboard is a collections of glyph icon resources for keyboard
## devices.
##

class_name StdInputGlyphSetKeyboard
extends StdInputGlyphSet

# -- CONFIGURATION ------------------------------------------------------------------- #

## include_label defines whether an origin label is included in the returned glyph data.
@export var include_label: bool = false

## capitalize_label controls whether the returned origin label is capitalized. Only used
## if `include_label` is `true`.
@export var capitalize_label: bool = true

@export_subgroup("Command")

@export var cmd_escape: Texture2D = null
@export var cmd_tab: Texture2D = null
@export var cmd_backspace: Texture2D = null
@export var cmd_enter: Texture2D = null
@export var cmd_space: Texture2D = null
@export var cmd_insert: Texture2D = null
@export var cmd_delete: Texture2D = null
@export var cmd_home: Texture2D = null
@export var cmd_end: Texture2D = null
@export var cmd_page_up: Texture2D = null
@export var cmd_page_down: Texture2D = null

@export_subgroup("Arrow")

@export var arrow_up: Texture2D = null
@export var arrow_down: Texture2D = null
@export var arrow_left: Texture2D = null
@export var arrow_right: Texture2D = null

@export_subgroup("Modifier")

@export var mod_shift: Texture2D = null
@export var mod_control: Texture2D = null
@export var mod_meta: Texture2D = null
@export var mod_alt: Texture2D = null
@export var mod_capslock: Texture2D = null
@export var mod_numlock: Texture2D = null

@export_subgroup("Letter")

@export var letter_a: Texture2D = null
@export var letter_b: Texture2D = null
@export var letter_c: Texture2D = null
@export var letter_d: Texture2D = null
@export var letter_e: Texture2D = null
@export var letter_f: Texture2D = null
@export var letter_g: Texture2D = null
@export var letter_h: Texture2D = null
@export var letter_i: Texture2D = null
@export var letter_j: Texture2D = null
@export var letter_k: Texture2D = null
@export var letter_l: Texture2D = null
@export var letter_m: Texture2D = null
@export var letter_n: Texture2D = null
@export var letter_o: Texture2D = null
@export var letter_p: Texture2D = null
@export var letter_q: Texture2D = null
@export var letter_r: Texture2D = null
@export var letter_s: Texture2D = null
@export var letter_t: Texture2D = null
@export var letter_u: Texture2D = null
@export var letter_v: Texture2D = null
@export var letter_w: Texture2D = null
@export var letter_x: Texture2D = null
@export var letter_y: Texture2D = null
@export var letter_z: Texture2D = null

@export_subgroup("Number")

@export var number_0: Texture2D = null
@export var number_1: Texture2D = null
@export var number_2: Texture2D = null
@export var number_3: Texture2D = null
@export var number_4: Texture2D = null
@export var number_5: Texture2D = null
@export var number_6: Texture2D = null
@export var number_7: Texture2D = null
@export var number_8: Texture2D = null
@export var number_9: Texture2D = null

@export_subgroup("Function")

@export var fn_1: Texture2D = null
@export var fn_2: Texture2D = null
@export var fn_3: Texture2D = null
@export var fn_4: Texture2D = null
@export var fn_5: Texture2D = null
@export var fn_6: Texture2D = null
@export var fn_7: Texture2D = null
@export var fn_8: Texture2D = null
@export var fn_9: Texture2D = null
@export var fn_10: Texture2D = null
@export var fn_11: Texture2D = null
@export var fn_12: Texture2D = null

@export_subgroup("Symbol")

@export var symbol_tilde: Texture2D = null
@export var symbol_comma: Texture2D = null
@export var symbol_period: Texture2D = null
@export var symbol_slash_forward: Texture2D = null
@export var symbol_slash_back: Texture2D = null
@export var symbol_semicolon: Texture2D = null
@export var symbol_apostrophe: Texture2D = null
@export var symbol_bracket_left: Texture2D = null
@export var symbol_bracket_right: Texture2D = null
@export var symbol_minus: Texture2D = null
@export var symbol_equal: Texture2D = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_origin_glyph(event: InputEvent) -> GlyphData:
	assert(
		(
			len(device_types) == 1
			&& device_types[0] == StdInputDevice.DEVICE_TYPE_KEYBOARD
		),
		"invalid state; wrong device type",
	)

	if not event is InputEventKey:
		return null

	if (
		event.keycode != KEY_NONE
		and event.physical_keycode != KEY_NONE
		and event.keycode != event.physical_keycode
	):
		assert(false, "invalid input; found conflicting keycodes")
		return null

	# NOTE: Only one of these properties can be set, so take the union of them in order
	# to handle all of them.
	var keycode: Key = event.keycode | event.physical_keycode

	var texture: Texture2D = null

	match keycode:
		# Command
		KEY_ESCAPE:
			texture = cmd_escape
		KEY_TAB:
			texture = cmd_tab
		KEY_BACKSPACE:
			texture = cmd_backspace
		KEY_ENTER:
			texture = cmd_enter
		KEY_SPACE:
			texture = cmd_space
		KEY_INSERT:
			texture = cmd_insert
		KEY_DELETE:
			texture = cmd_delete
		KEY_HOME:
			texture = cmd_home
		KEY_END:
			texture = cmd_end
		KEY_PAGEUP:
			texture = cmd_page_up
		KEY_PAGEDOWN:
			texture = cmd_page_down

		# Arrow
		KEY_UP:
			texture = arrow_up
		KEY_DOWN:
			texture = arrow_down
		KEY_LEFT:
			texture = arrow_left
		KEY_RIGHT:
			texture = arrow_right

		# Modifier
		KEY_SHIFT:
			texture = mod_shift
		KEY_CTRL:
			texture = mod_control
		KEY_META:
			texture = mod_meta
		KEY_ALT:
			texture = mod_alt
		KEY_CAPSLOCK:
			texture = mod_capslock
		KEY_NUMLOCK:
			texture = mod_numlock

		# Letter
		KEY_A:
			texture = letter_a
		KEY_B:
			texture = letter_b
		KEY_C:
			texture = letter_c
		KEY_D:
			texture = letter_d
		KEY_E:
			texture = letter_e
		KEY_F:
			texture = letter_f
		KEY_G:
			texture = letter_g
		KEY_H:
			texture = letter_h
		KEY_I:
			texture = letter_i
		KEY_J:
			texture = letter_j
		KEY_K:
			texture = letter_k
		KEY_L:
			texture = letter_l
		KEY_M:
			texture = letter_m
		KEY_N:
			texture = letter_n
		KEY_O:
			texture = letter_o
		KEY_P:
			texture = letter_p
		KEY_Q:
			texture = letter_q
		KEY_R:
			texture = letter_r
		KEY_S:
			texture = letter_s
		KEY_T:
			texture = letter_t
		KEY_U:
			texture = letter_u
		KEY_V:
			texture = letter_v
		KEY_W:
			texture = letter_w
		KEY_X:
			texture = letter_x
		KEY_Y:
			texture = letter_y
		KEY_Z:
			texture = letter_z

		# Number
		KEY_0:
			texture = number_0
		KEY_1:
			texture = number_1
		KEY_2:
			texture = number_2
		KEY_3:
			texture = number_3
		KEY_4:
			texture = number_4
		KEY_5:
			texture = number_5
		KEY_6:
			texture = number_6
		KEY_7:
			texture = number_7
		KEY_8:
			texture = number_8
		KEY_9:
			texture = number_9

		# Function
		KEY_F1:
			texture = fn_1
		KEY_F2:
			texture = fn_2
		KEY_F3:
			texture = fn_3
		KEY_F4:
			texture = fn_4
		KEY_F5:
			texture = fn_5
		KEY_F6:
			texture = fn_6
		KEY_F7:
			texture = fn_7
		KEY_F8:
			texture = fn_8
		KEY_F9:
			texture = fn_9
		KEY_F10:
			texture = fn_10
		KEY_F11:
			texture = fn_11
		KEY_F12:
			texture = fn_12

		# Symbol
		KEY_ASCIITILDE:
			texture = symbol_tilde
		KEY_COMMA:
			texture = symbol_comma
		KEY_PERIOD:
			texture = symbol_period
		KEY_SLASH:
			texture = symbol_slash_forward
		KEY_BACKSLASH:
			texture = symbol_slash_back
		KEY_SEMICOLON:
			texture = symbol_semicolon
		KEY_APOSTROPHE:
			texture = symbol_apostrophe
		KEY_BRACKETLEFT:
			texture = symbol_bracket_left
		KEY_BRACKETRIGHT:
			texture = symbol_bracket_right
		KEY_MINUS:
			texture = symbol_minus
		KEY_EQUAL:
			texture = symbol_equal

	if not texture and not include_label:
		return null

	var data := GlyphData.new()
	data.texture = texture

	if include_label:
		data.label = OS.get_keycode_string(event.keycode)

		if capitalize_label:
			data.label = data.label.to_upper()

	return data
