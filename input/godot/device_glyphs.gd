##
## std/input/godot/device_glyphs.gd
##
## An implemention of `StdInputDeviceGlyphs` which maps joypad names and origins to
## custom glyphs using Godot's built-in `Input` class/SDL controller database.
##

extends StdInputDeviceGlyphs

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Bindings := preload("binding.gd")
const Origin := preload("origin.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _JOY_AXIS_STICKS maps each stick axis to the stick's name and the direction names of
## the axis's negative and positive values.
const _JOY_AXIS_STICKS := {
	JOY_AXIS_LEFT_X: ["Left Stick", "Left", "Right"],
	JOY_AXIS_LEFT_Y: ["Left Stick", "Up", "Down"],
	JOY_AXIS_RIGHT_X: ["Right Stick", "Left", "Right"],
	JOY_AXIS_RIGHT_Y: ["Right Stick", "Up", "Down"],
}

## _JOY_BUTTON_LABELS_DEFAULT names every joypad button for a device type which has no
## name of its own for it in `_JOY_BUTTON_LABELS`.
const _JOY_BUTTON_LABELS_DEFAULT := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "LS",
	JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
	JOY_BUTTON_MISC1: "Misc 1",
	JOY_BUTTON_PADDLE1: "Paddle 1",
	JOY_BUTTON_PADDLE2: "Paddle 2",
	JOY_BUTTON_PADDLE3: "Paddle 3",
	JOY_BUTTON_PADDLE4: "Paddle 4",
	JOY_BUTTON_TOUCHPAD: "Touchpad",
	JOY_BUTTON_MISC2: "Misc 2",
	JOY_BUTTON_MISC3: "Misc 3",
	JOY_BUTTON_MISC4: "Misc 4",
	JOY_BUTTON_MISC5: "Misc 5",
	JOY_BUTTON_MISC6: "Misc 6",
}

## _JOY_BUTTON_LABELS_NINTENDO holds the names shared by Nintendo's device types.
##
## NOTE: Godot's face buttons are positional, so `JOY_BUTTON_A` is the bottom button,
## which Nintendo labels "B".
const _JOY_BUTTON_LABELS_NINTENDO := {
	JOY_BUTTON_A: "B",
	JOY_BUTTON_B: "A",
	JOY_BUTTON_X: "Y",
	JOY_BUTTON_Y: "X",
	JOY_BUTTON_BACK: "−",
	JOY_BUTTON_GUIDE: "Home",
	JOY_BUTTON_START: "+",
	JOY_BUTTON_LEFT_STICK: "Left Stick",
	JOY_BUTTON_RIGHT_STICK: "Right Stick",
	JOY_BUTTON_LEFT_SHOULDER: "L",
	JOY_BUTTON_RIGHT_SHOULDER: "R",
	JOY_BUTTON_MISC1: "Capture",
}

## _JOY_BUTTON_LABELS maps a device type to the names it gives its buttons, which take
## precedence over `_JOY_BUTTON_LABELS_DEFAULT`.
const _JOY_BUTTON_LABELS := {
	StdInputDevice.DEVICE_TYPE_PS_4:
	{
		JOY_BUTTON_A: "Cross",
		JOY_BUTTON_B: "Circle",
		JOY_BUTTON_X: "Square",
		JOY_BUTTON_Y: "Triangle",
		JOY_BUTTON_BACK: "Share",
		JOY_BUTTON_GUIDE: "PS",
		JOY_BUTTON_START: "Options",
		JOY_BUTTON_LEFT_STICK: "L3",
		JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_LEFT_SHOULDER: "L1",
		JOY_BUTTON_RIGHT_SHOULDER: "R1",
	},
	StdInputDevice.DEVICE_TYPE_PS_5:
	{
		JOY_BUTTON_A: "Cross",
		JOY_BUTTON_B: "Circle",
		JOY_BUTTON_X: "Square",
		JOY_BUTTON_Y: "Triangle",
		JOY_BUTTON_BACK: "Create",
		JOY_BUTTON_GUIDE: "PS",
		JOY_BUTTON_START: "Options",
		JOY_BUTTON_LEFT_STICK: "L3",
		JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_LEFT_SHOULDER: "L1",
		JOY_BUTTON_RIGHT_SHOULDER: "R1",
		JOY_BUTTON_MISC1: "Mute",
	},
	StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER:
	{
		JOY_BUTTON_GUIDE: "Steam",
	},
	StdInputDevice.DEVICE_TYPE_STEAM_DECK:
	{
		JOY_BUTTON_BACK: "View",
		JOY_BUTTON_GUIDE: "Steam",
		JOY_BUTTON_START: "Menu",
		JOY_BUTTON_LEFT_STICK: "L3",
		JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_LEFT_SHOULDER: "L1",
		JOY_BUTTON_RIGHT_SHOULDER: "R1",
	},
	StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_PAIR: _JOY_BUTTON_LABELS_NINTENDO,
	StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_SINGLE: _JOY_BUTTON_LABELS_NINTENDO,
	StdInputDevice.DEVICE_TYPE_SWITCH_PRO: _JOY_BUTTON_LABELS_NINTENDO,
	StdInputDevice.DEVICE_TYPE_XBOX_ONE:
	{
		JOY_BUTTON_BACK: "View",
		JOY_BUTTON_GUIDE: "Xbox",
		JOY_BUTTON_START: "Menu",
		JOY_BUTTON_MISC1: "Share",
	},
}

## _JOY_TRIGGER_LABELS_DEFAULT names the triggers of a device type which has no names of
## its own for them in `_JOY_TRIGGER_LABELS`.
const _JOY_TRIGGER_LABELS_DEFAULT := {
	JOY_AXIS_TRIGGER_LEFT: "LT",
	JOY_AXIS_TRIGGER_RIGHT: "RT",
}

## _JOY_TRIGGER_LABELS_NINTENDO holds the trigger names of Nintendo's device types.
const _JOY_TRIGGER_LABELS_NINTENDO := {
	JOY_AXIS_TRIGGER_LEFT: "ZL",
	JOY_AXIS_TRIGGER_RIGHT: "ZR",
}

## _JOY_TRIGGER_LABELS_NUMBERED holds the trigger names of the device types which number
## their shoulders.
const _JOY_TRIGGER_LABELS_NUMBERED := {
	JOY_AXIS_TRIGGER_LEFT: "L2",
	JOY_AXIS_TRIGGER_RIGHT: "R2",
}

## _JOY_TRIGGER_LABELS maps a device type to the names it gives its triggers.
const _JOY_TRIGGER_LABELS := {
	StdInputDevice.DEVICE_TYPE_PS_4: _JOY_TRIGGER_LABELS_NUMBERED,
	StdInputDevice.DEVICE_TYPE_PS_5: _JOY_TRIGGER_LABELS_NUMBERED,
	StdInputDevice.DEVICE_TYPE_STEAM_DECK: _JOY_TRIGGER_LABELS_NUMBERED,
	StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_PAIR: _JOY_TRIGGER_LABELS_NINTENDO,
	StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_SINGLE: _JOY_TRIGGER_LABELS_NINTENDO,
	StdInputDevice.DEVICE_TYPE_SWITCH_PRO: _JOY_TRIGGER_LABELS_NINTENDO,
}

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

## glyph_sets defines the list of supported glyph icon sets for any device type.
##
## NOTE: Multiple sets can be provided for the same device type; this component will
## keep searching glyph sets until it finds a matching resource, returning the first it
## finds or `null` on no match.
@export var glyph_sets: Array[StdInputGlyphSet] = []

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_glyph(
	_device: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
	_target_size: Vector2,
) -> Texture2D:
	for glyph_set in glyph_sets:
		if not glyph_set.matches(device_type):
			continue

		var event := (
			Bindings
			. get_action_binding(
				scope,
				action_set,
				action,
				StdInputDevice.get_device_category(device_type),
				index,
			)
		)

		if not event:
			return null

		var texture := glyph_set.get_origin_glyph(event)
		if texture:
			return texture

	return null


func _get_action_origin_count(
	_device: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
) -> int:
	var category := StdInputDevice.get_device_category(device_type)

	# NOTE: A binding repeated at a later index is not another origin, so it ends the
	# count as an unbound index does; otherwise a cycling glyph would show it twice.
	var origins := PackedInt64Array()
	for index in StdInputDeviceActions.BindingIndex.values():
		var event := Bindings.get_action_binding(
			scope, action_set, action, category, index
		)
		if not event:
			break

		var origin := Origin.encode(event)
		if origin in origins:
			break

		origins.append(origin)

	return origins.size()


func _get_action_origin_label(
	_device: int,
	device_type: StdInputDevice.DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
	index: int,
) -> String:
	assert(
		device_type != StdInputDevice.DEVICE_TYPE_UNKNOWN,
		"invalid argument: unknown device type",
	)

	# NOTE: A touchscreen has no origins of its own to name.
	if device_type == StdInputDevice.DEVICE_TYPE_TOUCH:
		return ""

	var event := (
		Bindings
		. get_action_binding(
			scope,
			action_set,
			action,
			StdInputDevice.get_device_category(device_type),
			index,
		)
	)

	if device_type != StdInputDevice.DEVICE_TYPE_KEYBOARD:
		return _get_joypad_origin_label(device_type, event)

	if not event is InputEventKey:
		return ""

	var physical_keycode: Key = event.physical_keycode
	if physical_keycode == KEY_NONE:
		assert(false, "invalid input; missing keycodes")
		physical_keycode = event.keycode

	var keycode := (
		DisplayServer.keyboard_get_label_from_physical(physical_keycode)
		if _has_keyboard_label_support()
		else physical_keycode
	)

	if not OS.is_keycode_unicode(keycode):
		return OS.get_keycode_string(keycode)

	var label := char(keycode).strip_edges()
	if not label:
		return OS.get_keycode_string(keycode)

	return label


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_joypad_origin_label returns the name `device_type` gives the joypad origin of
## `event`, or an empty string if `event` isn't a joypad origin.
##
## NOTE: These are the platforms' own terms, so they aren't translated here. A caller
## with a catalogue can translate the returned name.
static func _get_joypad_origin_label(
	device_type: StdInputDevice.DeviceType,
	event: InputEvent,
) -> String:
	if event is InputEventJoypadButton:
		var buttons: Dictionary = _JOY_BUTTON_LABELS.get(device_type, {})
		return (
			buttons
			. get(
				event.button_index,
				_JOY_BUTTON_LABELS_DEFAULT.get(event.button_index, ""),
			)
		)

	if not event is InputEventJoypadMotion:
		return ""

	if event.axis in _JOY_AXIS_STICKS:
		var stick: Array = _JOY_AXIS_STICKS[event.axis]
		if is_zero_approx(event.axis_value):
			return stick[0]

		var direction: String = stick[1] if event.axis_value < 0.0 else stick[2]
		return "%s %s" % [stick[0], direction]

	var triggers: Dictionary = _JOY_TRIGGER_LABELS.get(
		device_type, _JOY_TRIGGER_LABELS_DEFAULT
	)
	return triggers.get(event.axis, "")


## _has_keyboard_label_support returns whether the display server can map a physical
## keycode to a localized key label.
##
## NOTE: The platform check covers web and mobile. The display server name additionally
## covers a headless server on a supported platform, where the call logs an error
## instead of returning a default.
static func _has_keyboard_label_support() -> bool:
	if DisplayServer.get_name() == &"headless":
		return false

	return (
		OS.has_feature(&"windows")
		or OS.has_feature(&"macos")
		or OS.has_feature(&"linuxbsd")
	)
