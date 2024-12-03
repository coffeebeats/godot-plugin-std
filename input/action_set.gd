##
## std/input/action_set.gd
##
## `InputActionSet` is a collection of input actions which, collectively, define
## available player actions during a section of the game.
##

class_name InputActionSet
extends Resource

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

@export_group("Cursor ")

## confine_cursor defines whether the cursor is confined to the game window.
@export var confine_cursor: bool = false

@export_subgroup("Visibility ")

## actions_hide_cursor is the list of actions which, when "just" triggered, will trigger
## the cursor to be hidden. Note that this doesn't guarantee that the cursor will be
## hidden, as the visibility is dependent on a number of factors.
@export var actions_hide_cursor: Array[StringName] = []

## always_hide_cursor defines whether to always hide the cursor when this action set is
## active. Only one of `always_hide_cursor` and `always_show_cursor` may be `true`.
@export var always_hide_cursor: bool = false:
	set(value):
		always_hide_cursor = value
		always_show_cursor = not value

## always_show_cursor defines whether to always show the cursor when this action set is
## active. Only one of `always_hide_cursor` and `always_show_cursor` may be `true`.
@export var always_show_cursor: bool = false:
	set(value):
		always_show_cursor = value
		always_hide_cursor = not value

# NOTE: Unfortunately, due to Steam Input offering a far richer API for defining action
# sets, this abstraction must leak some Steam-related details.

@export_group("Steam ")

@export_subgroup("Actions ")

## action_absolute_mouse is the name of an "absolute mouse"-typed action which will be
## defined via the Steam Input API. That action should be converted into normal mouse
## mouse input via `Input.parse_input_event`.
@export var action_absolute_mouse: StringName = ""

@export_subgroup("Version ")

## version_major is the major version of the action set. Changing this signals a break
## in compatibility with prior versions.
@export var version_major: int = 0

## version_minor is the minor version of the action set. Changing this signals a change
## which *is* compatible with prior versions.
@export var version_minor: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_matching_event_origin returns whether the provided `InputEvent` is a valid type
## for the specified input action.
func is_matching_event_origin(action: StringName, event: InputEvent) -> bool:
	# Fast-track a high-throughput input event like mouse motion.
	if event is InputEventMouseMotion:
		return false

	if event is InputEventJoypadMotion:
		var axis: JoyAxis = event.axis

		if axis > JOY_AXIS_INVALID and axis < JOY_AXIS_TRIGGER_LEFT:
			return action in actions_analog_2d

		if axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT:
			return action in actions_analog_1d

	if (
		event is InputEventMouseButton
		or event is InputEventKey
		or event is InputEventJoypadButton
	):
		return action in actions_digital

	return false
