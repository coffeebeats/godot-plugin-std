extends Resource
class_name InputAction

# -- DEFINITIONS --------------------------------------------------------------------- #

## INPUT_ACTION_TYPE_UNKNOWN is an unknown input action type.
const INPUT_ACTION_TYPE_UNKNOWN := Type.INPUT_ACTION_TYPE_UNKNOWN

## INPUT_ACTION_TYPE_JOYSTICK is an action type that accepts a range of values, rather than
## just an on/off state (typically bound to a joystick).
const INPUT_ACTION_TYPE_JOYSTICK := Type.INPUT_ACTION_TYPE_JOYSTICK

## INPUT_ACTION_TYPE_ANALOG_TRIGGER is an action type for joypad triggers which support
## an axis of values, rather than a simple on/off state.
const INPUT_ACTION_TYPE_ANALOG_TRIGGER := Type.INPUT_ACTION_TYPE_ANALOG_TRIGGER

## INPUT_ACTION_TYPE_BUTTON is an action type for digital actions (i.e. on/off) that are
## typically bound to buttons or keys.
const INPUT_ACTION_TYPE_BUTTON := Type.INPUT_ACTION_TYPE_BUTTON

## Type is an enumeration of types of input actions.
enum Type {
    INPUT_ACTION_TYPE_UNKNOWN = 0,
    INPUT_ACTION_TYPE_ANALOG_TRIGGER = 2,
    INPUT_ACTION_TYPE_JOYSTICK = 1,
    INPUT_ACTION_TYPE_BUTTON = 3,
}

# -- CONFIGURATION ------------------------------------------------------------------- #

## id is the unique identifier for the action.
@export var id: StringName = ""

## action_type is the type of action 'id' corresponds to.
@export var action_type: Type = INPUT_ACTION_TYPE_UNKNOWN
