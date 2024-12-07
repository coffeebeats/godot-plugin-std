##
## std/input/action_set_mouse.gd
##
## InputGlyphSetMouse is a collections of glyph icon resources for mouse devices.
##

class_name InputGlyphSetMouse
extends InputGlyphSet

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


func _get_origin_glyph(event: InputEvent) -> Texture2D:
	assert(
		device_type == InputDevice.DEVICE_TYPE_KEYBOARD,
		"invalid state; wrong device type",
	)

	if event is InputEventMouseButton:
		match event.button_index:
			# Primary
			MOUSE_BUTTON_LEFT:
				return button_left
			MOUSE_BUTTON_RIGHT:
				return button_left
			MOUSE_BUTTON_MIDDLE:
				return button_middle

			# Wheel
			MOUSE_BUTTON_WHEEL_UP:
				return button_wheel_up
			MOUSE_BUTTON_WHEEL_DOWN:
				return button_wheel_down
			MOUSE_BUTTON_WHEEL_LEFT:
				return button_wheel_left
			MOUSE_BUTTON_WHEEL_RIGHT:
				return button_wheel_right

			# Side
			MOUSE_BUTTON_XBUTTON1:
				return button_side_1
			MOUSE_BUTTON_XBUTTON2:
				return button_side_2

	return null  # gdlint:ignore=max-returns
