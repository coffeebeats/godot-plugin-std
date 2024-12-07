##
## std/input/action_set_joy.gd
##
## InputGlyphSetJoy is a collections of glyph icon resources for joypad devices.
##

class_name InputGlyphSetJoy
extends InputGlyphSet

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Joysticks")

@export var stick_left_direction_up: Texture2D = null
@export var stick_left_direction_down: Texture2D = null
@export var stick_left_direction_left: Texture2D = null
@export var stick_left_direction_right: Texture2D = null

@export var stick_right_direction_up: Texture2D = null
@export var stick_right_direction_down: Texture2D = null
@export var stick_right_direction_left: Texture2D = null
@export var stick_right_direction_right: Texture2D = null

@export_group("Buttons")

@export_subgroup("Face")

@export var button_a: Texture2D = null
@export var button_b: Texture2D = null
@export var button_x: Texture2D = null
@export var button_y: Texture2D = null

@export_subgroup("Navigation")

@export var button_back: Texture2D = null
@export var button_guide: Texture2D = null
@export var button_start: Texture2D = null

@export_subgroup("Joystick")

@export var button_stick_left: Texture2D = null
@export var button_stick_right: Texture2D = null

@export_subgroup("Shoulder")

@export var button_shoulder_left: Texture2D = null
@export var button_shoulder_right: Texture2D = null

@export_subgroup("D-pad")

@export var button_dpad_up: Texture2D = null
@export var button_dpad_down: Texture2D = null
@export var button_dpad_left: Texture2D = null
@export var button_dpad_right: Texture2D = null

@export_subgroup("Miscellaneous")

@export var button_misc: Texture2D = null
@export var button_paddle_1: Texture2D = null
@export var button_paddle_2: Texture2D = null
@export var button_paddle_3: Texture2D = null
@export var button_paddle_4: Texture2D = null
@export var button_touchpad: Texture2D = null

@export_group("Analog triggers")

@export var analog_trigger_left: Texture2D = null
@export var analog_trigger_right: Texture2D = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_origin_glyph(event: InputEvent) -> Texture2D:
	assert(
		device_type != InputDevice.DEVICE_TYPE_KEYBOARD,
		"invalid state; wrong device type",
	)

	if event is InputEventJoypadButton:
		match event.button_index:
			# Face
			JOY_BUTTON_A:
				return button_a
			JOY_BUTTON_B:
				return button_b
			JOY_BUTTON_X:
				return button_x
			JOY_BUTTON_Y:
				return button_y

			# Navigation
			JOY_BUTTON_BACK:
				return button_back
			JOY_BUTTON_GUIDE:
				return button_guide
			JOY_BUTTON_START:
				return button_start

			# Joystick
			JOY_BUTTON_LEFT_STICK:
				return button_stick_left
			JOY_BUTTON_RIGHT_STICK:
				return button_stick_right

			# Shoulder
			JOY_BUTTON_LEFT_SHOULDER:
				return button_shoulder_left
			JOY_BUTTON_RIGHT_SHOULDER:
				return button_shoulder_right

			# D-pad
			JOY_BUTTON_DPAD_UP:
				return button_dpad_up
			JOY_BUTTON_DPAD_DOWN:
				return button_dpad_down
			JOY_BUTTON_DPAD_LEFT:
				return button_dpad_left
			JOY_BUTTON_DPAD_RIGHT:
				return button_dpad_right

			# Miscellaneous
			JOY_BUTTON_MISC1:
				return button_misc
			JOY_BUTTON_PADDLE1:
				return button_paddle_1
			JOY_BUTTON_PADDLE2:
				return button_paddle_2
			JOY_BUTTON_PADDLE3:
				return button_paddle_3
			JOY_BUTTON_PADDLE4:
				return button_paddle_4
			JOY_BUTTON_TOUCHPAD:
				return button_touchpad

	if event is InputEventJoypadMotion:
		match event.axis:
			# Joysticks
			JOY_AXIS_LEFT_X:
				match event.axis_value:
					-1.0:
						return stick_left_direction_left
					1.0:
						return stick_left_direction_right
			JOY_AXIS_LEFT_Y:
				match event.axis_value:
					-1.0:
						return stick_left_direction_up
					1.0:
						return stick_left_direction_down
			JOY_AXIS_RIGHT_X:
				match event.axis_value:
					-1.0:
						return stick_right_direction_left
					1.0:
						return stick_right_direction_right
			JOY_AXIS_RIGHT_Y:
				match event.axis_value:
					-1.0:
						return stick_right_direction_up
					1.0:
						return stick_right_direction_down

			# Analog triggers
			JOY_AXIS_TRIGGER_LEFT:
				return analog_trigger_left
			JOY_AXIS_TRIGGER_RIGHT:
				return analog_trigger_right

	return null  # gdlint:ignore=max-returns
