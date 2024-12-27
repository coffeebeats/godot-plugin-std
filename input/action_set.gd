##
## std/input/action_set.gd
##
## StdInputActionSet is a collection of input actions which, collectively, define
## available player actions during a section of the game.
##

class_name StdInputActionSet
extends Resource

# -- DEFINITIONS --------------------------------------------------------------------- #

## PropertyStatus is a type which represents a boolean value that can also be inherited.
## This allows distinguishing between `false` and "not set".
enum PropertyStatus {
	INHERIT = 0,
	ON = 1,
	OFF = 2,
}

const PROPERTY_STATUS_INHERIT := PropertyStatus.INHERIT
const PROPERTY_STATUS_ON := PropertyStatus.ON
const PROPERTY_STATUS_OFF := PropertyStatus.OFF

# -- CONFIGURATION ------------------------------------------------------------------- #

## name is the name of the identifier for the action set. It must be unique among all
## other action sets and action set layers.
@export var name: StringName

@export_group("Analog actions ")
@export_subgroup("1D ")

## actions_analog_1d is a list of input actions names which can be bound to 1D analog
## input origins (e.g. analog triggers).
@export var actions_analog_1d: Array[StringName] = []

@export_subgroup("2D ")

## actions_analog_2d is a list of input actions names which can be bound to 2D analog
## input origins (e.g. left/right joysticks).
@export var actions_analog_2d: Array[StringName] = []

@export_group("Digital actions ")

## actions_digital is a list of input actions names which can be bound to "digital"
## (i.e. on/off) input origins.
@export var actions_digital: Array[StringName] = []

@export_group("Cursor")

@export_subgroup("Mode")

## cursor_confined defines whether the cursor is confined to the game window.
##
## NOTE: This property will be true if the current action set or any activated action
## set layer enables it.
@export var cursor_confined: bool = false

## cursor_captured defines whether the cursor is captured.
##
## NOTE: This property will be true if the current action set or any activated action
## set layer enables it.
@export var cursor_captured: bool = false

## cursor_activates_kbm defines whether revealing the cursor will activate the keyboard
## and mouse input device (defaults to "off" / not enabled). This is likely desired for
## menu-based action sets, but should probably be disabled during gameplay due to the
## prevalence of gyro controls (which are simulated as mouse input).
##
## NOTE: This property will be true if the current action set or any activated action
## set layer enables it.
@export var cursor_activates_kbm: PropertyStatus = PROPERTY_STATUS_INHERIT

@export_subgroup("Hide")

## cursor_hide_actions is a list of actions which, when "just" triggered by a non-KBM
## device, will request the cursor to be hidden. Note that this doesn't guarantee that
## the cursor will be hidden, as the visibility is dependent on a number of factors.
##
## NOTE: Actions defined in layers will add to the total set of actions which will hide
## the cursor. As such, there's no need to include actions from parent layers.
##
## NOTE: This property will be ignored if `cursor_captured` is `true`.
@export var cursor_hide_actions: Array[StringName] = []

## cursor_hide_actions_if_hovered is a list of actions (like `cursor_hide_actions`)
## which will request the cursor to be hidden, but only if there's currently a node
## being hovered which is tracked by a `StdInputCursorFocusHandler`. This can be used to
## seamlessly "accept" mouse-hovered UI elements with a joypad.
##
## NOTE: Actions defined in layers will add to the total set of actions which will hide
## the cursor. As such, there's no need to include actions from parent layers.
##
## NOTE: This property will be ignored if `cursor_captured` is `true`.
@export var cursor_hide_actions_if_hovered: Array[StringName] = []

## cursor_hide_delay is a delay (in seconds) before the hiding the cursor after a
## request to hide it. During this delay, further mouse motion will cancel the hide
## effect. This can be used to limit rapid/distracting visibility changes when both
## mouse motion and the `cursor_hide_actions` are anticipated to be used together.
##
## NOTE: The maximum delay value across all active action sets and layers will be used.
@export var cursor_hide_delay: float = 0.0

@export_subgroup("Reveal")

## cursor_reveal_mouse_buttons is a list of mouse buttons which, when "just" pressed,
## will trigger the cursor to be shown. Note that this doesn't guarantee that the cursor
## will be shown, as the visibility is dependent on a number of factors.
##
## NOTE: Mouse buttons defined in layers will add to the total set of buttons which will
## reveal the cursor. As such, there's no need to include actions from parent layers.
##
## NOTE: This property will be ignored if `cursor_captured` is `true`.
@export var cursor_reveal_mouse_buttons: Array[MouseButton] = [
	MOUSE_BUTTON_LEFT,
	MOUSE_BUTTON_RIGHT,
]

## cursor_reveal_distance_minimum defines how much relative motion must be detected for
## the cursor to be considered "moving". This is used to filter out slight bumps to the
## cursor which should otherwise not reveal it.
##
## NOTE: The maximum reveal distance threshold value across all active action sets and
## layers will be used.
@export var cursor_reveal_distance_minimum: Vector2 = Vector2.ZERO

# NOTE: Unfortunately, due to Steam Input offering a far richer API for defining action
# sets, this abstraction must leak some Steam-related details.

@export_group("Steam ")

@export_subgroup("Actions ")

## action_absolute_mouse is the name of an "absolute mouse"-typed action which will be
## defined via the Steam Input API. That action should be converted into normal mouse
## mouse input via `Input.parse_input_event`.
##
## NOTE: This action must *not* be present in the `actions_analog_2d` array.
@export var action_absolute_mouse: StringName = ""

@export_subgroup("Version ")

## version_major is the major version of the action set. Changing this signals a break
## in compatibility with prior versions.
@export var version_major: int = 0

## version_minor is the minor version of the action set. Changing this signals a change
## which *is* compatible with prior versions.
@export var version_minor: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## list_action_names returns a list of all actions included in the action set. There is
## no guarantee on the order of returned items.
func list_action_names() -> PackedStringArray:
	var names := PackedStringArray()

	for action in actions_analog_1d:
		assert(action not in names, "invalid config; duplicate action")
		names.append(action)
	for action in actions_analog_2d:
		assert(action not in names, "invalid config; duplicate action")
		names.append(action)
	for action in actions_digital:
		assert(action not in names, "invalid config; duplicate action")
		names.append(action)
	if action_absolute_mouse:
		assert(action_absolute_mouse not in names, "invalid config; duplicate action")
		names.append(action_absolute_mouse)

	return names


## is_matching_event_origin returns whether the provided `InputEvent` is a valid type
## for the specified input action.
func is_matching_event_origin(action: StringName, event: InputEvent) -> bool:
	# Fast-track a high-throughput input event like mouse motion.
	if event is InputEventMouseMotion:
		return false

	if event is InputEventJoypadMotion:
		var axis: JoyAxis = event.axis

		if axis > JOY_AXIS_INVALID and axis < JOY_AXIS_TRIGGER_LEFT:
			return action in actions_analog_2d or action in actions_digital

		if axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT:
			return action in actions_analog_1d

	if (
		event is InputEventMouseButton
		or event is InputEventKey
		or event is InputEventJoypadButton
	):
		return action in actions_digital

	return false
