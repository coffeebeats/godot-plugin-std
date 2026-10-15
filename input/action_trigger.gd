##
## std/input/action_trigger.gd
##
## StdInputActionTrigger is a node that raises an input action when a target
## `BaseButton` is pressed. Drop it as a child of a button or point it at one via the
## `target` export to give a bindable action a second way to be raised, as a close
## button raises `ui_cancel`, so that keys, clicks, and synthetic input share one
## handler. A button that stands in for no action connects `pressed` instead.
##
## NOTE: The action is pressed for exactly as long as the button is, in the button's
## own action mode: a release-mode button sends the press and release together, and a
## press-mode button holds the action until `button_up`, so a poller reads it as held.
##

class_name StdInputActionTrigger
extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## action is the input action to raise when the target button is pressed.
@export var action: StringName = &""

## target is a path to the `BaseButton` whose pressed signal will be listened to;
## defaults to the parent node.
@export var target: NodePath = NodePath("..")

## player_id is the player whose `StdInputSlot` must declare the action, in its loaded
## action set or an enabled layer. Debug builds check this on each press, since an
## `InputEventAction` matches by name whether or not any set binds the action.
@export var player_id: int = 1

# -- INITIALIZATION ------------------------------------------------------------------ #

var _button: BaseButton = null

## _held is whether a press was sent whose release waits on the button's `button_up`.
var _held: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	# NOTE: A button freed while held sends no `button_up`, so release here.
	_release()


func _ready() -> void:
	assert(action != &"", "invalid config; missing action")

	_button = get_node_or_null(target)
	assert(_button, "invalid config; target must be a BaseButton")

	Signals.connect_safe(_button.pressed, _on_pressed)
	Signals.connect_safe(_button.button_up, _on_button_up)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _is_action_declared returns whether `action` is in the loaded action set or an
## enabled layer of the player's input slot. A tree without a slot declares nothing,
## so the check passes there.
func _is_action_declared() -> bool:
	var slot := StdInputSlot.for_player(player_id)
	if not slot:
		return true

	var action_sets: Array[StdInputActionSet] = []
	var action_set := slot.actions.get_action_set(slot.device_id)
	if action_set:
		action_sets.append(action_set)
	action_sets.append_array(slot.list_action_set_layers())

	for candidate in action_sets:
		if action in candidate.list_action_names():
			return true

	return false


## _release sends the release of a held press, if any.
func _release() -> void:
	if not _held:
		return

	_held = false
	StdInputEvent.trigger_action(action, StdInputEvent.DEVICE_ID_SYNTHETIC, false)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_button_up() -> void:
	_release()


func _on_pressed() -> void:
	if not action:
		return

	assert(_is_action_declared(), "invalid config; action is not in an active set")

	StdInputEvent.trigger_action(action, StdInputEvent.DEVICE_ID_SYNTHETIC, true)

	# NOTE: Only a press-mode button is still down when `pressed` fires; a release-mode
	# button, or a `pressed` emitted by code, gets its release at once. Godot sends
	# `button_up` when a held button is released, hidden, or disabled.
	if _button.is_pressed():
		_held = true
	else:
		StdInputEvent.trigger_action(action, StdInputEvent.DEVICE_ID_SYNTHETIC, false)
