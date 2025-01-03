##
## std/input/cursor_focus_handler.gd
##
## StdInputCursorFocusHandler is a class which helps manage UI focus for a configured
## `Control` node. It will work with a `StdInputCursor` singleton node to grab or release
## focus depending on whether the UI navigation mode is cursor or focus-based.
##

class_name StdInputCursorFocusHandler
extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## control is a path to the `Control` node whose focus state will be managed.
@export var control: NodePath = NodePath("..")

## use_as_anchor determines whether the target `Control` node is eligible for focus if
## no better UI elements are eligible upon switching to focus-based navigation. In
## effect, the target node will be focus when the cursor is hidden.
@export var use_as_anchor: bool = false

# -- INITIALIZATION ------------------------------------------------------------------ #

# gdlint:ignore=class-definitions-order
static var _anchors: Array[StdInputCursorFocusHandler] = []

var _control_focus_mode: FocusMode = FOCUS_NONE
var _control_mouse_filter: MouseFilter = MOUSE_FILTER_IGNORE
var _cursor: StdInputCursor = null

@onready var _control: Control = get_node(control)

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_focus_target returns the last registered focus anchor that's visible in the scene
## tree. Note that this does _not_ account for hovered nodes - only those selected to be
## "anchors" in the scene.
static func get_focus_target() -> Control:
	if not _anchors:
		return null

	var i: int = len(_anchors) - 1
	while i >= 0:
		var anchor := _anchors[i]

		if not anchor is StdInputCursorFocusHandler:
			assert(false, "invalid state; wrong node type")
			continue

		if not anchor._control is Control:
			assert(false, "invalid state; invalid target node")
			continue

		var target := anchor._control
		if target.is_visible_in_tree():
			return target

		i -= 1

	return null


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	_anchors.erase(self)

	Signals.disconnect_safe(_control.mouse_entered, _on_Control_mouse_entered)
	Signals.disconnect_safe(_control.mouse_exited, _on_Control_mouse_exited)
	(
		Signals
		. disconnect_safe(
			_cursor.cursor_visibility_changed,
			_on_cursor_visibility_changed,
		)
	)


func _enter_tree() -> void:
	if use_as_anchor and not self in _anchors:
		_anchors.append(self)


func _ready() -> void:
	assert(_control is Control, "invalid state; missing Control node")

	_control_focus_mode = _control.focus_mode
	_control_mouse_filter = _control.mouse_filter

	Signals.connect_safe(_control.mouse_entered, _on_Control_mouse_entered)
	Signals.connect_safe(_control.mouse_exited, _on_Control_mouse_exited)

	_cursor = StdGroup.get_sole_member(StdInputCursor.GROUP_INPUT_CURSOR)
	assert(_cursor is StdInputCursor, "invalid state; missing input cursor")

	(
		Signals
		. connect_safe(
			_cursor.cursor_visibility_changed,
			_on_cursor_visibility_changed,
		)
	)

	# Ensure the initial mouse filter state is set.
	_on_cursor_visibility_changed(_cursor.get_is_visible())


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Control_mouse_entered() -> void:
	if _control_focus_mode != FOCUS_NONE:
		_cursor.set_hovered(_control)


func _on_Control_mouse_exited() -> void:
	if _control_focus_mode != FOCUS_NONE:
		_cursor.unset_hovered(_control)


func _on_cursor_visibility_changed(is_cursor_visible: bool) -> void:
	# NOTE: In order to stop a hidden cursor from hovering a UI element, disable its
	# mouse filter property; see https://github.com/godotengine/godot/issues/56783.
	if not is_cursor_visible:
		_control.mouse_filter = MOUSE_FILTER_IGNORE
		_control.focus_mode = _control_focus_mode
	else:
		_control.mouse_filter = _control_mouse_filter
		_control.focus_mode = FOCUS_NONE
