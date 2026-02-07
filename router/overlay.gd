##
## router/overlay.gd
##
## StdRouterOverlay is a wrapper node that handles input blocking and configurable close
## triggers for modal scenes.
##

class_name StdRouterOverlay
extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## backdrop_clicked is emitted when the overlay receives a mouse click matching the
## configured close mask.
signal backdrop_clicked(event: InputEventMouseButton)

## cancel_requested is emitted when the configured `close_action` input is pressed.
signal cancel_requested

# -- CONFIGURATION ------------------------------------------------------------------- #

## close_action is the input action that triggers a request to close the modal. If
## empty, no action will trigger the signal.
@export var close_action: StringName = &""

## click_to_close is a bitfield of `MouseButtonMask` values which, when the
## overlay is clicked with one of the matching mouse buttons, will emit
## `backdrop_clicked`. If this is left empty, then clicks cannot close the overlay.
##
## NOTE: This property is dependent on the overlay receiving input (i.e. the
## `mouse_filter` property must *not* be `MOUSE_FILTER_IGNORE`).
@export_flags("Left:1", "Right:2", "Middle:4", "Extra1:128", "Extra2:256")
var click_to_close: int = 0

# -- INITIALIZATION ------------------------------------------------------------------ #

## active controls whether this overlay responds to close action input. Managed by
## `StdRouterStage` to ensure only the topmost overlay processes input.
var active: bool = true

var _last_focus: Control = null
var _mouse_filter: MouseFilter = MOUSE_FILTER_STOP

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_last_focus returns the last focused control within this overlay, or null.
func get_last_focus() -> Control:
	if (
		_last_focus
		and is_instance_valid(_last_focus)
		and _last_focus.is_visible_in_tree()
		and _last_focus.focus_mode != Control.FOCUS_NONE
	):
		return _last_focus

	return null


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_mouse_filter = mouse_filter
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return
	if not is_node_ready():
		return

	mouse_filter = _mouse_filter if visible else MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return

	# Check if this mouse button is in the 'click_to_close' mask.
	var button_mask := 1 << (mb.button_index - 1) # Convert button index to mask.
	if click_to_close & button_mask:
		backdrop_clicked.emit(mb)


func _input(event: InputEvent) -> void:
	if not visible or not active:
		return

	if close_action.is_empty():
		return

	if event.is_action_pressed(close_action):
		get_viewport().set_input_as_handled()
		cancel_requested.emit()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_gui_focus_changed(node: Control) -> void:
	if node and is_ancestor_of(node):
		_last_focus = node
