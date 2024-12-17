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

# -- INITIALIZATION ------------------------------------------------------------------ #

var _cursor_captured: bool = false
var _cursor_confined: bool = false
var _cursor_visible: bool = true
var _hide_actions := PackedStringArray()
var _hide_delay: float = 0.0
var _hovered: Control = null
var _reveal_distance_minimum: Vector2 = Vector2.ZERO
var _reveal_mouse_buttons: Array[MouseButton] = []
var _time_since_mouse_motion: float = 0.0

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
func update_configuration(action_sets: Array[StdInputActionSet] = []) -> void:
	if not action_sets:
		return

	# First, determine cursor show/hide properties.

	_hide_delay = action_sets.reduce(
		func(d, s): return max(d, s.cursor_hide_delay), 0.0
	)

	_hide_actions = PackedStringArray()
	for action_set in action_sets:
		for action in action_set.cursor_hide_actions:
			# NOTE: This operation makes this O(n^2), but arrays should be small.
			if action not in _hide_actions:
				_hide_actions.append(action)

	_reveal_distance_minimum = action_sets.reduce(
		func(v, s): return v.max(s.cursor_reveal_distance_minimum), Vector2.ZERO
	)

	_reveal_mouse_buttons = []
	for action_set in action_sets:
		for button in action_set.cursor_reveal_mouse_buttons:
			# NOTE: This operation makes this O(n^2), but arrays should be small.
			if button not in _reveal_mouse_buttons:
				_reveal_mouse_buttons.append(button)

	# Then, determine cursor mode.

	var has_changed: bool = false

	var captured := action_sets.any(func(s): return s.cursor_captured)
	has_changed = has_changed or captured != _cursor_captured
	_cursor_captured = captured

	var confined := action_sets.any(func(s): return s.cursor_confined)
	has_changed = has_changed or confined != _cursor_confined
	_cursor_confined = confined

	if has_changed:
		_on_properties_changed()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_INPUT_CURSOR).remove_member(self)


func _input(event: InputEvent) -> void:
	if not _cursor_visible:
		if (
			(
				event is InputEventMouseMotion
				and event.relative > _reveal_distance_minimum
			)
			or (
				event is InputEventMouseButton
				and event.button_index in _reveal_mouse_buttons
			)
		):
			_cursor_visible = true
			_time_since_mouse_motion = 0.0
			_on_properties_changed()

		return

	# Mouse is currently visible - no need to check mouse motion.
	if event is InputEventMouseMotion:
		_time_since_mouse_motion = 0.0
		return
	
	# The cursor is not eligible to be hidden yet.
	if _time_since_mouse_motion < _hide_delay:
		return

	# Finally, check if any of the hide actions have just been pressed.
	for action in _hide_actions:
		if Input.is_action_just_pressed(action):
			_cursor_visible = false
			_on_properties_changed()


func _process(delta: float) -> void:
	if _cursor_visible:
		_time_since_mouse_motion += delta


func _ready() -> void:
	_hovered = null
	_time_since_mouse_motion = 0.0

	assert(StdGroup.is_empty(GROUP_INPUT_CURSOR), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_INPUT_CURSOR).add_member(self)

	# Trigger the initial state.
	_on_properties_changed()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_properties_changed() -> void:
	if _cursor_captured:
		_cursor_visible = false

		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)

	if _cursor_visible:
		if _cursor_captured:
			assert(false, "invalid state; found conflicting cursor state")
		elif not _cursor_confined:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CONFINED)

		get_viewport().gui_release_focus()
	else:
		if _cursor_captured:
			pass
		elif not _cursor_confined:
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

	cursor_visibility_changed.emit(_cursor_visible)
