##
## std/input/cursor_focus_handler.gd
##
## StdInputCursorFocusHandler is a class which helps manage UI focus for a configured
## `Control` node. It will work with a `StdInputCursor` singleton node to grab or release
## focus depending on whether the UI navigation mode is cursor or focus-based.
##

class_name StdInputCursorFocusHandler
extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## focused is emitted when the target `Control` node gains focus.
signal focused

## unfocused is emitted when the target `Control` node loses focus.
signal unfocused

## hovered is emitted when the mouse cursor enters the target `Control` node.
signal hovered

## unhovered is emitted when the mouse cursor exits the target `Control` node.
signal unhovered

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
var _focused: bool = false
var _hovered: bool = false

@onready var _control: Control = get_node(control)

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_focused returns whether the target `Control` node currently has focus.
func is_focused() -> bool:
	return _focused


## is_hovered returns whether the target `Control` node is currently hovered.
func is_hovered() -> bool:
	return _hovered


## get_focus_target returns the last registered focus anchor that's visible in the scene
## tree. Note that this does _not_ account for hovered nodes - only those selected to be
## "anchors" in the scene.
##
## The `anchor` parameter is an optional node which, when specified, restricts the
## selected focus target to be a descendent of that node.
static func get_focus_target(ancestor: Control = null) -> Control:
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
		if (
			target.is_visible_in_tree()
			and (not ancestor or ancestor.is_ancestor_of(target))
		):
			return target

		i -= 1

	return null


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	_anchors.erase(self)


func _enter_tree() -> void:
	if use_as_anchor and not self in _anchors:
		_anchors.append(self)


func _notification(what) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if visible and _cursor is StdInputCursor:
				_cursor.report_focus_handler_visible(self)


func _ready() -> void:
	assert(_control is Control, "invalid state; missing Control node")

	_control_focus_mode = _control.focus_mode
	_control_mouse_filter = _control.mouse_filter

	Signals.connect_safe(_control.focus_entered, _on_control_focus_entered)
	Signals.connect_safe(_control.focus_exited, _on_control_focus_exited)
	Signals.connect_safe(_control.mouse_entered, _on_control_mouse_entered)
	Signals.connect_safe(_control.mouse_exited, _on_control_mouse_exited)

	_cursor = StdGroup.get_sole_member(StdInputCursor.GROUP_INPUT_CURSOR)
	assert(_cursor is StdInputCursor, "invalid state; missing input cursor")

	(
		Signals
		. connect_safe(
			_cursor.cursor_visibility_changed,
			_on_cursor_visibility_changed,
		)
	)
	(
		Signals
		. connect_safe(
			_cursor.focus_root_changed,
			_on_focus_root_changed,
		)
	)

	# Ensure the initial mouse filter state is set.
	_on_cursor_visibility_changed(_cursor.get_is_visible())

	# Broadcast that a new anchor handler has entered the scene. This ensures that when
	# a new scene is loaded the UI can seamlessly select a new focus target.
	if use_as_anchor and visible:
		# NOTE: Defer this call in case the rest of the scene hasn't finished loading.
		_cursor.report_focus_handler_visible.call_deferred(self)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_control_focus_entered() -> void:
	_focused = true
	focused.emit()


func _on_control_focus_exited() -> void:
	_focused = false
	unfocused.emit()


func _on_control_mouse_entered() -> void:
	if _control_focus_mode != FOCUS_NONE:
		_cursor.set_hovered(_control)

	_hovered = true
	hovered.emit()


func _on_control_mouse_exited() -> void:
	if _control_focus_mode != FOCUS_NONE:
		_cursor.unset_hovered(_control)

	_hovered = false
	unhovered.emit()


func _on_cursor_visibility_changed(is_cursor_visible: bool) -> void:
	# NOTE: In order to stop a hidden cursor from hovering a UI element, disable its
	# mouse filter property; see https://github.com/godotengine/godot/issues/56783.
	if not is_cursor_visible:
		_control.mouse_filter = MOUSE_FILTER_IGNORE
		_control.focus_mode = _control_focus_mode
	else:
		_control.mouse_filter = _control_mouse_filter
		_control.focus_mode = FOCUS_NONE


func _on_focus_root_changed(root: Control) -> void:
	# If there's a focus root and this control isn't under it, disable focus and mouse
	# interaction to prevent elements outside the root (e.g., behind a modal) from
	# receiving focus or hover.
	if root and not root.is_ancestor_of(_control):
		_control.mouse_filter = MOUSE_FILTER_IGNORE
		_control.focus_mode = FOCUS_NONE
		return

	_on_cursor_visibility_changed(_cursor.get_is_visible())
