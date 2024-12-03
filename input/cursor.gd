##
## std/input/cursor.gd
##
## InputCursor is a class which manages the application cursor, specifically its
## visibility and confinement to the window. It also helps the application gracefully
## transition between "digital"/focus-based navigation and cursor navigation by keeping
## track of recently hovered UI elements and grabbing focus during mode transitions.
##

class_name InputCursor
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_INPUT_CURSOR := "std/input:cursor"

# -- CONFIGURATION ------------------------------------------------------------------- #

## actions_hide_cursor is the list of actions which, when "just" triggered, will trigger
## the cursor to be hidden. Note that this doesn't guarantee that the cursor will be
## hidden, as the visibility is dependent on a number of factors.
@export var actions_hide_cursor := PackedStringArray()

@export_group("Cursor state")

## confined controls whether the cursor is confined to the application window.
@export var confined: bool = false:
	set(value):
		confined = (value as bool)
		_on_properties_changed()

## show_cursor controls whether the cursor is currently visible.
@export var show_cursor: bool = true:
	set(value):
		show_cursor = (value as bool)
		_on_properties_changed()

# -- INITIALIZATION ------------------------------------------------------------------ #

var _hovered: Control = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## set_hovered registers the provided `Control` node as the most recently hovered UI
## element. If the cursor is disabled, focus will transition directly to this node if
## eligible.
func set_hovered(control: Control) -> bool:
	assert(control is Control, "missing argument")

	if not control or control == _hovered:
		return false

	if control.focus_mode != Control.FOCUS_ALL:
		return false

	assert(_hovered == null, "duplicate hovered node registered")
	_hovered = control

	return true


## unset_hovered clears the specified `Control` node as the last hovered UI element. If
## the node is not actually the last hovered node, nothing happens.
func unset_hovered(control: Control) -> bool:
	assert(control is Control, "missing argument")

	if not control or control != _hovered:
		return false

	_hovered = null
	return true


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_INPUT_CURSOR).remove_member(self)


func _ready() -> void:
	assert(StdGroup.is_empty(GROUP_INPUT_CURSOR), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_INPUT_CURSOR).add_member(self)

	# Trigger the initial state.
	_on_properties_changed()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_properties_changed() -> void:
	if show_cursor:
		if not confined:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CONFINED)

		get_viewport().gui_release_focus()

	else:
		if not confined:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CONFINED_HIDDEN)

		_hovered.grab_focus()
		unset_hovered(_hovered)
