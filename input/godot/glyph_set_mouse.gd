##
## std/input/action_set_mouse.gd
##
## StdInputGlyphSetMouse is a collections of glyph icon resources for mouse devices.
##

class_name StdInputGlyphSetMouse
extends StdInputGlyphSet

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Primary")

@export var button_left: Texture2D = null
@export var button_right: Texture2D = null
@export var button_middle: Texture2D = null

@export_subgroup("Wheel")

@export var button_wheel_up: Texture2D = null
@export var button_wheel_down: Texture2D = null
@export var button_wheel_left: Texture2D = null
@export var button_wheel_right: Texture2D = null

@export_subgroup("Side")

@export var button_side_1: Texture2D = null
@export var button_side_2: Texture2D = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_origin_glyph(event: InputEvent) -> GlyphData:
	assert(
		len(device_types) == 1 && device_types[0] == StdInputDevice.DEVICE_TYPE_KEYBOARD,
		"invalid state; wrong device type",
	)

	var texture: Texture2D = null

	if event is InputEventMouseButton:
		match event.button_index:
			# Primary
			MOUSE_BUTTON_LEFT:
				texture = button_left
			MOUSE_BUTTON_RIGHT:
				texture = button_left
			MOUSE_BUTTON_MIDDLE:
				texture = button_middle

			# Wheel
			MOUSE_BUTTON_WHEEL_UP:
				texture = button_wheel_up
			MOUSE_BUTTON_WHEEL_DOWN:
				texture = button_wheel_down
			MOUSE_BUTTON_WHEEL_LEFT:
				texture = button_wheel_left
			MOUSE_BUTTON_WHEEL_RIGHT:
				texture = button_wheel_right

			# Side
			MOUSE_BUTTON_XBUTTON1:
				texture = button_side_1
			MOUSE_BUTTON_XBUTTON2:
				texture = button_side_2

	if not texture:
		return null

	var data := GlyphData.new()
	data.texture = texture

	return data
