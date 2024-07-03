extends Resource
class_name InputActionSet

## is is the unique identifier of the action set.
@export var id: StringName = ""

@export var analog_trigger_actions: Array[StringName] = []
@export var button_actions: Array[StringName] = []
@export var joystick_actions: Array[StringName] = []

func get_actions() -> Array[InputAction]:
    var actions: Array[InputAction] = []

    for name in analog_trigger_actions:
        var action := InputAction.new()
        action.id = name
        action.action_type = InputAction.INPUT_ACTION_TYPE_ANALOG_TRIGGER

        actions.append(action)

    for name in button_actions:
        var action := InputAction.new()
        action.id = name
        action.action_type = InputAction.INPUT_ACTION_TYPE_BUTTON

        actions.append(action)
    
    for name in joystick_actions:
        var action := InputAction.new()
        action.id = name
        action.action_type = InputAction.INPUT_ACTION_TYPE_JOYSTICK

        actions.append(action)

    return actions
