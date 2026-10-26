##
## std/input/action_set.gd
##
## StdInputActionSet is a collection of input actions which, collectively, define
## available player actions during a section of the game.
##

@tool
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

## ANALOG_2D_DIRECTIONS are the suffixes of the four digital actions a 2D analog
## action's stick drives, in the order `Input.get_vector` takes them.
const ANALOG_2D_DIRECTIONS: Array[StringName] = [&"left", &"right", &"up", &"down"]

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

## actions_analog_2d is a list of 2D analog actions, each naming a stick which drives
## the four digital actions `<action>_left`, `<action>_right`, `<action>_up`, and
## `<action>_down`, which must also be listed in `actions_digital`. Godot binds,
## rebinds, and shows glyphs for those four as it does any digital action, and the game
## reads them with `Input.get_vector`. Steam defines the 2D action as one
## `joystick_move` action in their place: the four leave the manifest, the Steam actions
## component publishes them from the stick's axes, and a glyph for any of them shows
## the stick.
##
## NOTE: A name must not end in `_x` or `_y`; an axis is a pair of directions, not an
## action, since Godot clamps an action's strength to `[0, 1]`.
##
## NOTE: While Steam Input drives the stick, the four directions' `InputMap` deadzones
## are all but `0`, since Steam reports the stick past its configurator's deadzone.
@export var actions_analog_2d: Array[StringName] = []

@export_group("Digital actions ")

## actions_digital is a list of input actions names which can be bound to "digital"
## (i.e. on/off) input origins.
@export var actions_digital: Array[StringName] = []

@export_group("Cursor")

@export_subgroup("Mode")

## cursor_confined defines whether the cursor is confined to the game window.
##
## NOTE: The cursor is confined if the current action set or any activated action set
## layer enables it, unless `StdInputCursor.confined_property` is set.
@export var cursor_confined: bool = false

## cursor_captured defines whether the cursor is captured.
##
## NOTE: This property will be true if the current action set or any activated action
## set layer enables it.
@export var cursor_captured: bool = false

@export_subgroup("Hide")

## cursor_hide_actions is a list of actions which, when "just" triggered by any device,
## request the cursor to be hidden. Other factors, such as `cursor_hide_delay`, can
## still keep the cursor visible.
##
## NOTE: A key or mouse button press triggers an action only with exactly the action's
## modifiers, as Godot's GUI matches its focus actions, so Shift+Tab doesn't trigger an
## action bound to Tab alone.
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

## cursor_hide_delay is how long (in seconds) hide actions are ignored after the cursor
## is revealed or the mouse moves past `cursor_reveal_distance_minimum`. This limits
## rapid visibility changes when the mouse and the hide actions are used together.
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

## cursor_reveal_distance_minimum defines the distance, per axis in screen pixels, which
## mouse motion must exceed on at least one axis to reveal the cursor or, while it's
## visible, to restart `cursor_hide_delay`. The same threshold decides when
## `action_absolute_mouse` motion counts as joypad activity.
##
## NOTE: Godot merges each frame's motion into one event, so a per-event minimum scales
## with the frame rate. Pair a nonzero minimum with a `cursor_reveal_window`.
##
## NOTE: The maximum reveal distance threshold value across all active action sets and
## layers will be used.
@export var cursor_reveal_distance_minimum: Vector2 = Vector2.ZERO

## cursor_reveal_window is the duration (in seconds) over which signed mouse motion is
## summed before it's compared to `cursor_reveal_distance_minimum`, so the minimum acts
## as a speed of `minimum / window` pixels per second and back-and-forth jitter cancels.
##
## NOTE: Events arrive once per frame, so the window is quantized to whole frames. Use
## several frames at the lowest target frame rate (`0.1` or more).
##
## NOTE: The maximum window across all active action sets and layers will be used.
@export var cursor_reveal_window: float = 0.0

## cursor_click_activates_kbm defines whether a press of one of
## `cursor_reveal_mouse_buttons` activates the keyboard and mouse device even when no
## action binds that button (defaults to off). Mouse motion never activates the device.
##
## NOTE: Steam legacy bindings, and a Deck layout without touchscreen native support,
## send controller clicks as real mouse clicks; bind those clicks to actions instead.
##
## NOTE: The last of the action set and its active layers to set this property decides
## its value.
@export var cursor_click_activates_kbm: PropertyStatus = PROPERTY_STATUS_INHERIT

# NOTE: Unfortunately, due to Steam Input offering a far richer API for defining action
# sets, this abstraction must leak some Steam-related details.

@export_group("Steam ")

@export_subgroup("Actions ")

## action_absolute_mouse is the name of an "absolute mouse"-typed action which will be
## defined via the Steam Input API, so a trackpad or gyro drives the pointer. The Steam
## actions component moves the cursor by the action's deltas, or delivers them as mouse
## motion while the cursor is captured, and publishes the action as joypad activity for
## the `StdInputSlot` once its motion passes `cursor_reveal_distance_minimum`, summed
## over `cursor_reveal_window`.
##
## NOTE: A captured set which reads these deltas for aiming should set a non-zero
## `cursor_reveal_distance_minimum` too; otherwise an always-on gyro at rest switches
## glyphs to the controller while a mouse aims.
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


## get_analog_2d_action returns the 2D analog action whose stick drives the digital
## `action`, or an empty name when no stick does.
func get_analog_2d_action(action: StringName) -> StringName:
	for stick in actions_analog_2d:
		if action in list_analog_2d_actions(stick):
			return stick

	return &""


## list_action_names returns a list of all actions included in the action set. There is
## no guarantee on the order of returned items.
func list_action_names(include_absolute_mouse: bool = false) -> PackedStringArray:
	var names := PackedStringArray()

	for action in actions_analog_1d:
		assert(action not in names, "invalid config; duplicate action")
		names.append(action)
	for action in actions_analog_2d:
		assert(action not in names, "invalid config; duplicate action")
		assert(
			not (action.ends_with("_x") or action.ends_with("_y")),
			"invalid config; a 2D analog action names its stick, not an axis",
		)
		for direction in list_analog_2d_actions(action):
			assert(
				direction in actions_digital or _is_parent_action(direction),
				"invalid config; missing a stick's directional action",
			)
		names.append(action)
	for action in actions_digital:
		assert(action not in names, "invalid config; duplicate action")
		names.append(action)
	if include_absolute_mouse and action_absolute_mouse:
		assert(action_absolute_mouse not in names, "invalid config; duplicate action")
		names.append(action_absolute_mouse)

	return names


## list_analog_2d_actions returns the four digital actions the 2D analog `action`'s
## stick drives, in `ANALOG_2D_DIRECTIONS` order.
static func list_analog_2d_actions(action: StringName) -> Array[StringName]:
	var names: Array[StringName] = []

	for direction in ANALOG_2D_DIRECTIONS:
		names.append(StringName("%s_%s" % [action, direction]))

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


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _is_parent_action returns whether `action` is a digital action of the set this one is
## a layer of, so a layer can declare a stick whose directions its parent binds.
func _is_parent_action(action: StringName) -> bool:
	if not self is StdInputActionSetLayer or not self.parent:
		return false

	return action in self.parent.actions_digital
