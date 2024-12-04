##
## std/input/cursor_hover_tracker.gd
##
## InputCursorHoverTracker is a class which broadcasts hover states for an associated
## `Control` node to an `InputCursor` singleton.
##

class_name InputCursorHoverTracker
extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## control is a path to the `Control` node whose hover status will be reported to the
## `InputCursor`.
@export var control: NodePath = NodePath("..")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _cursor: InputCursor = null

@onready var _control: Control = get_node(control)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if _control.mouse_entered.is_connected(_on_Control_mouse_entered):
		_control.mouse_entered.disconnect(_on_Control_mouse_entered)
	if _control.mouse_exited.is_connected(_on_Control_mouse_exited):
		_control.mouse_exited.disconnect(_on_Control_mouse_exited)


func _ready() -> void:
	assert(_control is Control, "invalid state; missing Control node")
	assert(
		_control.focus_mode == Control.FOCUS_ALL,
		"invalid config; target UI element cannot be focused",
	)

	var err := _control.mouse_entered.connect(_on_Control_mouse_entered)
	assert(err == OK, "failed to connect to signal")

	err = _control.mouse_exited.connect(_on_Control_mouse_exited)
	assert(err == OK, "failed to connect to signal")

	_cursor = StdGroup.get_sole_member(InputCursor.GROUP_INPUT_CURSOR)
	assert(_cursor is InputCursor, "invalid state; missing input cursor")


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Control_mouse_entered() -> void:
	_cursor.set_hovered(_control)


func _on_Control_mouse_exited() -> void:
	_cursor.unset_hovered(_control)
