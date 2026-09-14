##
## std/input/action_trigger.gd
##
## StdInputActionTrigger is a node that triggers an input action when a target
## `BaseButton` is pressed. Drop it as a child of a button or point it at one via the
## target export to declaratively wire button presses to input actions without a script.
##

class_name StdInputActionTrigger
extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## action is the input action to trigger when the target button is pressed.
@export var action: StringName = &""

## target is a path to the `BaseButton` whose pressed signal will be listened to;
## defaults to the parent node.
@export var target: NodePath = NodePath("..")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(action != &"", "invalid config; missing action")

	var button: BaseButton = get_node_or_null(target)
	assert(button, "invalid config; target must be a BaseButton")

	Signals.connect_safe(button.pressed, _on_pressed)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_pressed() -> void:
	if action:
		StdInputEvent.trigger_action(action)
