##
## std/input/cursor.gd
##
## StdInputCursor is a class which manages the application cursor, specifically its
## visibility and confinement to the window. It also helps the application gracefully
## transition between "digital"/focus-based navigation and cursor navigation by keeping
## track of recently hovered UI elements and grabbing focus during mode transitions.
##

class_name StdInputCursor
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## cursor_visibility_changed is emitted when the visibility of the application's cursor
## changes.
signal cursor_visibility_changed(visible: bool)

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_INPUT_CURSOR := &"std/input:cursor"

# -- CONFIGURATION ------------------------------------------------------------------- #

## actions_hide_cursor is the list of actions which, when "just" triggered, will trigger
## the cursor to be hidden. Note that this doesn't guarantee that the cursor will be
## hidden, as the visibility is dependent on a number of factors.
@export var actions_hide_cursor := PackedStringArray()

## minimum_reveal_distance defines how much relative motion must be detected for the
## cursor to be considered "moving". This is used to filter out slight bumps to the
## cursor which should otherwise not reveal it.
@export var minimum_reveal_distance: Vector2 = Vector2.ZERO

@export_group("Cursor state")

## confined controls whether the cursor is confined to the application window.
@export var confined: bool = false:
	set(value):
		var confined_prev := confined
		confined = (value as bool)

		if confined != confined_prev:
			_on_properties_changed()

## show_cursor controls whether the cursor is currently visible.
@export var show_cursor: bool = true:
	set(value):
		var show_cursor_prev := show_cursor
		show_cursor = (value as bool)

		if show_cursor != show_cursor_prev:
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


## update_configuration changes the cursor state and triggering actions based on the
## provided action set and action set layers.
func update_configuration(
	action_set: StdInputActionSet = null, layers: Array[StdInputActionSetLayer] = []
) -> void:
	if not action_set:
		return

	confined = (layers[-1].confine_cursor if layers else action_set.confine_cursor)

	var always_hide_cursor := (
		action_set.always_hide_cursor
		or layers.any(func(s): return s.always_hide_cursor)
	)
	var always_show_cursor := (
		action_set.always_show_cursor
		or layers.any(func(s): return s.always_show_cursor)
	)

	assert(
		(
			not (always_hide_cursor or always_show_cursor)
			or (always_hide_cursor != always_show_cursor)
		),
		"invalid state; conflicting cursor states"
	)

	actions_hide_cursor = PackedStringArray()

	if always_hide_cursor:
		show_cursor = false
		return

	if always_show_cursor:
		show_cursor = true
		return

	for action in action_set.actions_hide_cursor:
		# NOTE: This operation makes this O(n^2), but arrays should be small.
		if action not in actions_hide_cursor:
			actions_hide_cursor.append(action)

	for layer in layers:
		for action in layer.actions_hide_cursor:
			# NOTE: This operation makes this O(n^2), but arrays should be small.
			if action not in actions_hide_cursor:
				actions_hide_cursor.append(action)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_INPUT_CURSOR).remove_member(self)


func _input(event: InputEvent) -> void:
	if not show_cursor:
		if event is InputEventMouseMotion:
			if event.relative > minimum_reveal_distance:
				show_cursor = true

		return

	# Mouse is currently visible - no need to check mouse or keyboard events.
	if (
		event is InputEventMouseMotion
		or event is InputEventKey
		or event is InputEventMouseButton
	):
		return

	if not actions_hide_cursor:
		return

	if event is InputEventJoypadMotion and event.axis_value < 0.1:
		return

	for action in actions_hide_cursor:
		if Input.is_action_just_pressed(action):
			show_cursor = false
			break


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

		if _hovered:
			# NOTE: Don't use a deferred call so that the current input event applies
			# as if the previously-hovered node was already focused.
			_hovered.grab_focus()
			unset_hovered(_hovered)
		else:
			var focus_target := StdInputCursorFocusHandler.get_focus_target()
			if focus_target:
				# NOTE: Use a deferred call here so that the current input event gets
				# swallowed. That ensures the anchor is focused and not a potential
				# neighbor (depending on what input triggered the change).
				focus_target.call_deferred(&"grab_focus")

	cursor_visibility_changed.emit(show_cursor)
