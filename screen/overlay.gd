##
## screen/overlay.gd
##
## StdScreenOverlay is a full-rect `Control` that wraps scene nodes to isolate input
## between stack layers. It blocks mouse events from reaching lower scenes, detects
## background clicks and close actions for close-to-dismiss, and, when topmost, consumes
## unhandled input its own subtree declined so lower overlays never see it.
##

class_name StdScreenOverlay
extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## background_clicked is emitted when a matching mouse button is pressed on the overlay
## background. The manager handles close propagation; the overlay only detects clicks.
signal background_clicked(event: InputEventMouseButton)

## close_action_pressed is emitted when unhandled input matches one of 'close_actions'.
## The manager handles the close; the overlay only detects the press.
signal close_action_pressed(event: InputEvent)

# -- INITIALIZATION ------------------------------------------------------------------ #

## click_to_close is the effective click-to-close mask (OR of all screens in this
## overlay). Set by the manager after each stack operation.
var click_to_close: int = 0

## close_actions are the input actions that request a close of the topmost screen. Set
## by the manager after each stack operation; only the current overlay carries any.
var close_actions: Array[StringName] = []

## consumes_unhandled_input marks unhandled input as handled once this overlay's scene
## and attachments have declined it. Set by the manager after each stack operation; only
## the topmost of two or more overlays consumes.
var consumes_unhandled_input: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _gui_input(event: InputEvent) -> void:
	if click_to_close == 0:
		return

	if not event is InputEventMouseButton:
		return

	var mb := event as InputEventMouseButton
	if not mb.is_pressed():
		return

	var button_mask := 1 << (mb.button_index - 1)
	if not (button_mask & click_to_close):
		return

	accept_event()
	background_clicked.emit(mb)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _unhandled_input(event: InputEvent) -> void:
	# NOTE: Children run before their parent, so this follows every node in this overlay
	# and precedes every node in the overlays below. A scene that handles a close action
	# itself therefore keeps it.
	for action in close_actions:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			close_action_pressed.emit(event)
			return

	if consumes_unhandled_input:
		get_viewport().set_input_as_handled()
