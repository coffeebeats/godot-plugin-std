##
## std/input/godot/origin_names.gd
##
## `StdInputOriginNames` maps the origins of specific device types to the translation
## keys of their display names, for the Godot glyph provider to translate.
##

class_name StdInputOriginNames
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## device_types is a list of input device types to which these names pertain.
@export var device_types: Array[StdInputDevice.DeviceType] = []

## joy_buttons maps joypad buttons to the translation keys of their names.
@export var joy_buttons: Dictionary[JoyButton, StringName] = {}

## joy_axes_negative maps joypad axes to the translation keys of their names when moved
## toward negative values, such as a stick pushed up or left.
@export var joy_axes_negative: Dictionary[JoyAxis, StringName] = {}

## joy_axes_positive maps joypad axes to the translation keys of their names when moved
## toward positive values, such as a stick pushed down or right, or a pulled trigger.
@export var joy_axes_positive: Dictionary[JoyAxis, StringName] = {}

## mouse_buttons maps mouse buttons to the translation keys of their names.
@export var mouse_buttons: Dictionary[MouseButton, StringName] = {}

## keys maps physical keycodes to the translation keys of their names. A key with no
## entry is named by its label in the player's keyboard layout, so entries suit named
## keys such as Enter rather than letters and symbols.
@export var keys: Dictionary[Key, StringName] = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_origin_name_key returns the translation key naming the origin which `event`
## binds, or an empty `StringName` if these names have no entry for it.
func get_origin_name_key(event: InputEvent) -> StringName:
	if event is InputEventJoypadButton:
		return joy_buttons.get(event.button_index, &"")

	if event is InputEventJoypadMotion:
		var axes: Dictionary[JoyAxis, StringName] = (
			joy_axes_negative if event.axis_value < 0 else joy_axes_positive
		)
		return axes.get(event.axis, &"") if event.axis_value else &""

	if event is InputEventMouseButton:
		return mouse_buttons.get(event.button_index, &"")

	if event is InputEventKey:
		# NOTE: Bindings store the physical keycode; a keycode-only event, as from
		# project settings, names its key by keycode instead.
		var keycode: Key = event.physical_keycode
		if keycode == KEY_NONE:
			keycode = event.keycode

		return keys.get(keycode, &"")

	return &""


## matches returns whether these names can be used for the specified device type.
func matches(device_type: StdInputDevice.DeviceType) -> bool:
	assert(device_types, "invalid config; missing device type")
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: unknown device type",
	)

	return device_type in device_types
