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

@export_group("Properties")

## confined_property is a settings property which controls whether the cursor should be
## confined to the application window.
@export var confined_property: StdSettingsPropertyBool = null

## visible_property is a settings property which controls whether the cursor should be
## visible.
@export var visible_property: StdSettingsPropertyBool = null

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
	StdGroup.with_id(GROUP_INPUT_CURSOR).add_member(self)

	if not confined_property.changed.is_connected(_on_properties_changed):
		confined_property.changed.connect(_on_properties_changed)
	if not visible_property.changed.is_connected(_on_properties_changed):
		visible_property.changed.connect(_on_properties_changed)

	# Trigger the initial state.
	_on_properties_changed()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_properties_changed() -> void:
	var is_confined := get_confined()
	var is_visible := get_visible()

	if is_visible:
		if not is_confined:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CONFINED)

		get_viewport().gui_release_focus()

	else:
		if not is_confined:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CONFINED_HIDDEN)

		_hovered.grab_focus()
		unset_hovered(_hovered)


# -- SETTERS/GETTERS ----------------------------------------------------------------- #


## get_confined returns whether the cursor should (currently) be confined to the window.
func get_confined() -> bool:
	assert(
		confined_property is StdSettingsPropertyBool,
		"invalid config; missing settings property",
	)

	return confined_property.get_value()


## get_visible returns whether the cursor should (currently) be visible.
func get_visible() -> bool:
	assert(
		confined_property is StdSettingsPropertyBool,
		"invalid config; missing settings property",
	)

	return confined_property.get_value()
