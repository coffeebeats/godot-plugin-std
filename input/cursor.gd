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

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_INPUT_CURSOR := &"std/input:cursor"

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create("std/input/cursor")

var _cursor_captured: bool = false
var _cursor_confined: bool = false
var _cursor_visible: bool = false
var _hide_actions := PackedStringArray()
var _hide_actions_if_hovered := PackedStringArray()
var _hide_delay: float = 0.0
var _hovered: Control = null
var _pressed: Array[String] = []
var _reveal_distance_minimum: Vector2 = Vector2.ZERO
var _reveal_mouse_buttons: Array[MouseButton] = []
var _time_since_mouse_motion: float = 0.0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_is_visible returns whether the cursor is currently visible.
func get_is_visible() -> bool:
	return _cursor_visible


## hide_cursor hides the cursor and transitions to focus-based navigation. If the cursor
## is already hidden, then nothing happens.
##
## NOTE: This method doesn't change configuration, so there's no guarantee the cursor
## will remain hidden.
func hide_cursor() -> void:
	if not _cursor_visible:
		return

	_cursor_visible = false
	_time_since_mouse_motion = 0.0
	_on_properties_changed()


## set_hovered registers the provided `Control` node as the most recently hovered UI
## element. If the cursor is disabled, focus will transition directly to this node if
## eligible.
func set_hovered(control: Control) -> bool:
	assert(control is Control, "missing argument")

	if not control or control == _hovered:
		return false

	assert(_hovered == null, "duplicate hovered node registered")
	_hovered = control

	return true


## show_cursor reveals the cursor and transitions to mouse-based navigation. If the
## cursor is already visible, then nothing happens.
##
## NOTE: This method doesn't change configuration, so there's no guarantee the cursor
## will remain visible.
func show_cursor() -> void:
	if _cursor_visible:
		return

	_cursor_visible = false
	_time_since_mouse_motion = 0.0
	_on_properties_changed()


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

	_logger.info("Updating cursor configuration.")

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

	_hide_actions_if_hovered = PackedStringArray()
	for action_set in action_sets:
		for action in action_set.cursor_hide_actions_if_hovered:
			# NOTE: This operation makes this O(n^2), but arrays should be small.
			if action not in _hide_actions_if_hovered:
				_hide_actions_if_hovered.append(action)

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
	Signals.disconnect_safe(get_viewport().gui_focus_changed, _on_gui_focus_changed)


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

	if _hovered:
		for action in _hide_actions_if_hovered:
			if not event.is_action_pressed(action):
				_pressed.erase(action)
				continue

			if action not in _pressed:
				_pressed.append(action)
				_cursor_visible = false
				_on_properties_changed()
				break

	for action in _hide_actions:
		if not event.is_action_pressed(action):
			_pressed.erase(action)
			continue

		if action not in _pressed:
			_pressed.append(action)
			_cursor_visible = false
			_on_properties_changed()
			break


func _process(delta: float) -> void:
	if _cursor_visible:
		_time_since_mouse_motion += delta

	for action in _pressed:
		if not Input.is_action_pressed(action):
			_pressed.erase(action)


func _ready() -> void:
	_hovered = null
	_time_since_mouse_motion = 0.0

	assert(StdGroup.is_empty(GROUP_INPUT_CURSOR), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_INPUT_CURSOR).add_member(self)

	_cursor_visible = (
		DisplayServer.mouse_get_mode()
		in [DisplayServer.MOUSE_MODE_VISIBLE, DisplayServer.MOUSE_MODE_CONFINED]
	)

	Signals.connect_safe(get_viewport().gui_focus_changed, _on_gui_focus_changed)

	# Trigger the initial state.
	_on_properties_changed()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_focus() -> void:
	if _cursor_visible:
		get_viewport().gui_release_focus()
		return

	if get_viewport().gui_get_focus_owner():
		return

	if _hovered:
		# NOTE: Don't use a deferred call so that the current input event applies
		# as if the previously-hovered node was already focused.
		_hovered.focus_mode = Control.FOCUS_ALL
		_hovered.grab_focus()
		unset_hovered(_hovered)
	else:
		var focus_target := StdInputCursorFocusHandler.get_focus_target()
		if focus_target:
			# NOTE: Use a deferred call here so that the current input event gets
			# swallowed. That ensures the anchor is focused and not a potential
			# neighbor (depending on what input triggered the change).
			focus_target.call_deferred(&"grab_focus")


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_gui_focus_changed(control: Control) -> void:
	control.focus_exited.connect(
		func(): call_deferred(&"_update_focus"), CONNECT_ONE_SHOT
	)


func _on_properties_changed(should_emit: bool = true) -> void:
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
	else:
		if _cursor_captured:
			pass
		elif not _cursor_confined:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CONFINED_HIDDEN)

	_update_focus()

	if should_emit:
		_logger.info("Cursor visibility changed.", {&"visible": _cursor_visible})
		cursor_visibility_changed.emit(_cursor_visible)
