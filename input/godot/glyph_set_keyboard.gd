##
## std/input/action_set_keyboard.gd
##
## InputGlyphSetKeyboard is a collections of glyph icon resources for keyboard devices.
##

class_name InputGlyphSetKeyboard
extends InputGlyphSet

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Command")

@export var cmd_escape: Texture2D = null
@export var cmd_tab: Texture2D = null
@export var cmd_backspace: Texture2D = null
@export var cmd_enter: Texture2D = null
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
@export var symbol_plus: Texture2D = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_origin_glyph(event: InputEvent) -> Texture2D:
	assert(
		device_type == InputDevice.DEVICE_TYPE_KEYBOARD,
		"invalid state; wrong device type",
	)

	if event is InputEventKey:
		match event.keycode:
			# Command
			KEY_ESCAPE:
				return cmd_escape
			KEY_TAB:
				return cmd_tab
			KEY_BACKSPACE:
				return cmd_backspace
			KEY_ENTER:
				return cmd_enter
			KEY_INSERT:
				return cmd_insert
			KEY_DELETE:
				return cmd_delete
			KEY_HOME:
				return cmd_home
			KEY_END:
				return cmd_end
			KEY_PAGEUP:
				return cmd_page_up
			KEY_PAGEDOWN:
				return cmd_page_down

			# Arrow
			KEY_UP:
				return arrow_up
			KEY_DOWN:
				return arrow_down
			KEY_LEFT:
				return arrow_left
			KEY_RIGHT:
				return arrow_right

			# Modifier
			KEY_SHIFT:
				return mod_shift
			KEY_CTRL:
				return mod_control
			KEY_META:
				return mod_meta
			KEY_ALT:
				return mod_alt
			KEY_CAPSLOCK:
				return mod_capslock
			KEY_NUMLOCK:
				return mod_numlock

			# Letter
			KEY_A:
				return letter_a
			KEY_B:
				return letter_b
			KEY_C:
				return letter_c
			KEY_D:
				return letter_d
			KEY_E:
				return letter_e
			KEY_F:
				return letter_f
			KEY_G:
				return letter_g
			KEY_H:
				return letter_h
			KEY_I:
				return letter_i
			KEY_J:
				return letter_j
			KEY_K:
				return letter_k
			KEY_L:
				return letter_l
			KEY_M:
				return letter_m
			KEY_N:
				return letter_n
			KEY_O:
				return letter_o
			KEY_P:
				return letter_p
			KEY_Q:
				return letter_q
			KEY_R:
				return letter_r
			KEY_S:
				return letter_s
			KEY_T:
				return letter_t
			KEY_U:
				return letter_u
			KEY_V:
				return letter_v
			KEY_W:
				return letter_w
			KEY_X:
				return letter_x
			KEY_Y:
				return letter_y
			KEY_Z:
				return letter_z

			# Number
			KEY_0:
				return number_0
			KEY_1:
				return number_1
			KEY_2:
				return number_2
			KEY_3:
				return number_3
			KEY_4:
				return number_4
			KEY_5:
				return number_5
			KEY_6:
				return number_6
			KEY_7:
				return number_7
			KEY_8:
				return number_8
			KEY_9:
				return number_9

			# Function
			KEY_F1:
				return fn_1
			KEY_F2:
				return fn_2
			KEY_F3:
				return fn_3
			KEY_F4:
				return fn_4
			KEY_F5:
				return fn_5
			KEY_F6:
				return fn_6
			KEY_F7:
				return fn_7
			KEY_F8:
				return fn_8
			KEY_F9:
				return fn_9
			KEY_F10:
				return fn_10
			KEY_F11:
				return fn_11
			KEY_F12:
				return fn_12

			# Symbol
			KEY_ASCIITILDE:
				return symbol_tilde
			KEY_COMMA:
				return symbol_comma
			KEY_PERIOD:
				return symbol_period
			KEY_SLASH:
				return symbol_slash_forward
			KEY_BACKSLASH:
				return symbol_slash_back
			KEY_SEMICOLON:
				return symbol_semicolon
			KEY_APOSTROPHE:
				return symbol_apostrophe
			KEY_BRACKETLEFT:
				return symbol_bracket_left
			KEY_BRACKETRIGHT:
				return symbol_bracket_right
			KEY_MINUS:
				return symbol_minus
			KEY_PLUS:
				return symbol_plus

	return null
