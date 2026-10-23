##
## std/input/cursor.gd
##
## StdInputCursor is a class which manages the application cursor, specifically its
## visibility and confinement to the window. It also helps the application gracefully
## transition between "digital"/focus-based navigation and cursor navigation by keeping
## track of recently hovered UI elements and grabbing focus during mode transitions.
##
## Cursor visibility is tracked apart from the active input device; showing or hiding
## the cursor never activates a device, though the `StdInputSlot` may activate one from
## the same press. When the cursor hides with no control focused, focus goes to the
## pending target, else the hovered control, else the control last clicked while the
## cursor was visible, else the control focused before the cursor was revealed, else the
## highest-priority anchor. The first two take focus at once, so the press which hid the
## cursor acts on them; the others wait for the frame to end.
##
## While hidden, controls managed by a `StdInputCursorFocusHandler` ignore the mouse.
## The cursor doesn't consume mouse events itself, which would starve `_unhandled_input`
## of mouse-look, so a control without a handler still hovers and clicks while hidden.
##

class_name StdInputCursor
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## about_to_grab_focus is emitted whenever the specified node is about to grab focus.
## The `trigger` parameter is the input action name that caused the focus change, if one
## exists (i.e. it's only populated if an input action triggered the focus change).
signal about_to_grab_focus(node: Control, trigger: StringName)

## cursor_visibility_changed is emitted when the visibility of the application's cursor
## changes.
signal cursor_visibility_changed(visible: bool)

## focus_root_changed is emitted when the focus root changes. Note that `root` may be
## `null` if the root focus was cleared.
##
## NOTE: This will be called *before* `StdInputCursor` recomputes the target focus node,
## allowing observers to select a specific focus target instead.
signal focus_root_changed(root: Control)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const MotionFilter := preload("motion_filter.gd")
const Signals := preload("../event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_INPUT_CURSOR := &"std/input:cursor"

# -- CONFIGURATION ------------------------------------------------------------------- #

## confined_property is an optional settings property which, when set, decides whether
## the cursor is confined to the window in place of the active action sets' choice. A
## captured cursor stays captured either way.
@export var confined_property: StdSettingsPropertyBool = null

# -- INITIALIZATION ------------------------------------------------------------------ #

# gdlint:ignore=class-definitions-order
static var _logger := StdLogger.create("std/input/cursor")

var _cursor_captured: bool = false
var _cursor_confined: bool = false
var _cursor_visible: bool = false
var _deferred_focus: Control = null
var _deferred_focus_id: int = 0
var _focus_root: Control = null
var _focus_to_restore: Control = null
var _focus_version: int = 0
var _hide_actions := PackedStringArray()
var _hide_actions_if_hovered := PackedStringArray()
var _hide_delay: float = 0.0
var _hovered: Control = null
var _pending_focus: Control = null
var _pressed: Array[String] = []
var _reveal_motion := MotionFilter.new()
var _reveal_mouse_buttons: Array[MouseButton] = []
var _sets_confined: bool = false
var _time_since_mouse_motion: float = 0.0
var _was_cursor_visible: bool = false

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_hovered returns the control currently tracked as hovered, or null.
func get_hovered() -> Control:
	return _hovered


## get_is_confined returns whether the cursor is currently confined to the window. A
## captured cursor isn't confined.
func get_is_confined() -> bool:
	return _cursor_confined and not _cursor_captured


## get_is_visible returns whether the cursor is currently visible.
func get_is_visible() -> bool:
	return _cursor_visible


## get_reveal_mouse_buttons returns the mouse buttons which reveal the cursor under the
## current configuration.
func get_reveal_mouse_buttons() -> Array[MouseButton]:
	return _reveal_mouse_buttons.duplicate()


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
	_reveal_motion.clear()
	_on_properties_changed()


## report_clicked notifies the `StdInputCursor` that `control` was clicked. While the
## cursor is visible, the next hide returns focus to it rather than to the control
## focused before the cursor was revealed; while hidden, the click is ignored.
func report_clicked(control: Control) -> void:
	assert(control is Control, "missing argument")

	if not _cursor_visible:
		return

	_focus_to_restore = control


## report_focus_handler_visible is used to notify the `StdInputCursor` that a previously
## hidden focus handler is now visible. This serves as a trigger to re-evaluate focus if
## there isn't currently a focused node.
func report_focus_handler_visible(_handler: StdInputCursorFocusHandler) -> void:
	if not _cursor_visible:
		_update_focus()


## set_focus_root restricts UI focus to be under the scene subtree rooted at `root`. If
## set, current and future focus handlers will be ignored if they aren't descendants of
## `root`. Call this with `null` to unset the focus root.
func set_focus_root(root: Control = null) -> void:
	assert(
		root == null or root.is_visible_in_tree(),
		"invalid argument; root node isn't visible",
	)

	(
		_logger
		. debug(
			"Updating focus root.",
			{&"root": root.get_path() if root else ^"/root"},
		)
	)

	var changed := _focus_root != root
	_focus_root = root

	if changed:
		focus_root_changed.emit(root)

	if _pending_focus or (changed and not _cursor_visible):
		_update_focus()


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


## set_pending_focus registers a preferred focus target, consumed the next time focus is
## resolved. Each call overwrites the previous target, allowing consumers to override
## the screen manager's default. Returns whether a non-null target was set.
func set_pending_focus(target: Control) -> bool:
	_pending_focus = target
	return target != null


## show_cursor reveals the cursor and transitions to mouse-based navigation. If the
## cursor is already visible, then nothing happens.
##
## NOTE: This method doesn't change configuration, so there's no guarantee the cursor
## will remain visible.
func show_cursor() -> void:
	if _cursor_visible:
		return

	_cursor_visible = true
	_time_since_mouse_motion = 0.0
	_reveal_motion.clear()
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

	_logger.debug("Updating cursor configuration.")

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

	_reveal_motion.configure(action_sets)

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

	_sets_confined = action_sets.any(func(s): return s.cursor_confined)
	var confined := _resolve_confined()
	has_changed = has_changed or confined != _cursor_confined
	_cursor_confined = confined

	if has_changed:
		_on_properties_changed()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if not confined_property:
		return

	assert(
		confined_property.scope is StdSettingsScope,
		"invalid config; missing scope for property",
	)

	Signals.connect_safe(confined_property.value_changed, _on_confined_property_changed)

	# NOTE: A scope emits no value change as it loads, so the value is read on `loaded`.
	if not confined_property.scope.is_loaded:
		Signals.connect_safe(
			confined_property.scope.loaded, _on_confined_property_changed
		)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_INPUT_CURSOR).remove_member(self)

	if confined_property:
		Signals.disconnect_safe(
			confined_property.value_changed, _on_confined_property_changed
		)
		Signals.disconnect_safe(
			confined_property.scope.loaded, _on_confined_property_changed
		)


func _input(event: InputEvent) -> void:
	# NOTE: A hide action is tracked from its press whatever the cursor's state, so one
	# held across a reveal or the hide delay can't hide the cursor on its next event.
	var hide_action := _track_hide_actions(event)

	if not _cursor_visible:
		# NOTE: A captured cursor can't be revealed, and `_on_properties_changed`
		# would hide it again and re-emit its visibility, so reveal input is ignored.
		if _cursor_captured:
			return

		if (
			(
				event is InputEventMouseMotion
				and _reveal_motion.push(event.screen_relative)
			)
			or (
				event is InputEventMouseButton
				and event.pressed
				and event.button_index in _reveal_mouse_buttons
			)
		):
			_cursor_visible = true
			_time_since_mouse_motion = 0.0
			_reveal_motion.clear()
			_on_properties_changed()

		return

	# Mouse is currently visible, so motion past the minimum restarts the hide delay.
	if event is InputEventMouseMotion:
		if _reveal_motion.push(event.screen_relative):
			_time_since_mouse_motion = 0.0

		return

	# The cursor is not eligible to be hidden yet.
	if _time_since_mouse_motion < _hide_delay:
		return

	# Finally, hide the cursor if a hide action was just pressed.
	if hide_action:
		_cursor_visible = false
		_reveal_motion.clear()
		_on_properties_changed(hide_action)


func _process(delta: float) -> void:
	if _cursor_visible:
		_time_since_mouse_motion += delta

	for action in _pressed.duplicate():
		if not Input.is_action_pressed(action):
			_pressed.erase(action)


func _ready() -> void:
	_hovered = null
	_time_since_mouse_motion = 0.0

	assert(StdGroup.is_empty(GROUP_INPUT_CURSOR), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_INPUT_CURSOR).add_member(self)

	if confined_property:
		_cursor_confined = _resolve_confined()

	_cursor_visible = (
		DisplayServer.mouse_get_mode()
		in [DisplayServer.MOUSE_MODE_VISIBLE, DisplayServer.MOUSE_MODE_CONFINED]
	)

	Signals.connect_safe(get_viewport().gui_focus_changed, _on_gui_focus_changed)

	# Trigger the initial state.
	_on_properties_changed()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _deferred_grab_focus(id: int, trigger: StringName, make_focusable: bool) -> void:
	if id != _deferred_focus_id:
		return

	var target := _deferred_focus
	_deferred_focus = null

	if not is_instance_valid(target) or not target.is_inside_tree():
		return

	if make_focusable:
		target.focus_mode = Control.FOCUS_ALL

	about_to_grab_focus.emit(target, trigger)
	target.grab_focus()


func _deferred_update_focus(version: int) -> void:
	if version != _focus_version:
		return

	_update_focus()


func _grab_focus(target: Control, trigger: StringName) -> void:
	about_to_grab_focus.emit(target, trigger)
	target.focus_mode = Control.FOCUS_ALL
	target.grab_focus()


## _grab_focus_deferred focuses `target` at the end of the frame, after the event which
## hid the cursor has propagated, so a hide action which also navigates can't move focus
## off it. Until then `target` counts as focused, and a newer grab or focus change
## cancels this one.
##
## NOTE: Without `make_focusable`, the target's focus handler must restore its mode.
func _grab_focus_deferred(
	target: Control, trigger: StringName, make_focusable: bool
) -> void:
	_deferred_focus = target
	_deferred_focus_id += 1
	_deferred_grab_focus.call_deferred(_deferred_focus_id, trigger, make_focusable)


func _resolve_confined() -> bool:
	if confined_property:
		return confined_property.get_value()

	return _sets_confined


## _track_hide_actions records every hide action `event` newly presses and returns the
## first which may hide the cursor now, checking the hovered-only actions first.
func _track_hide_actions(event: InputEvent) -> StringName:
	var trigger := &""

	for action in _hide_actions_if_hovered + _hide_actions:
		if not event.is_action_pressed(action) or action in _pressed:
			continue

		_pressed.append(action)

		if not trigger and (_hovered or action in _hide_actions):
			trigger = action

	return trigger


func _update_focus(trigger: StringName = &"") -> void:
	_focus_version += 1

	# Ensure the cached focus root is still valid.
	if _focus_root and not is_instance_valid(_focus_root):
		set_focus_root(null)

	# NOTE: The first hidden resolution consumes the control to restore, even when it
	# keeps the current focus, so a stale one can't resurface.
	var previous: Control = null
	if not _cursor_visible:
		previous = _focus_to_restore
		_focus_to_restore = null

	var deferred := _deferred_focus
	_deferred_focus = null

	# Keep current focus if it's valid and under the focus root.
	var current_focus := get_viewport().gui_get_focus_owner()
	if current_focus and (not _focus_root or _focus_root.is_ancestor_of(current_focus)):
		_pending_focus = null
		return

	# NOTE: A control whose grab is deferred to the end of the frame is kept as if it
	# had focus, since the resolution which picked it consumed the other candidates.
	if (
		not _cursor_visible
		and is_instance_valid(deferred)
		and deferred.is_visible_in_tree()
		and (not _focus_root or _focus_root.is_ancestor_of(deferred))
	):
		_deferred_focus = deferred
		_pending_focus = null
		return

	# Consume the pending focus target.
	var pending := _pending_focus
	_pending_focus = null
	if (
		pending
		and not _cursor_visible
		and is_instance_valid(pending)
		and pending.is_visible_in_tree()
		and not (pending is BaseButton and pending.disabled)
	):
		_grab_focus(pending, trigger)
		return

	# In mouse mode, release focus.
	if _cursor_visible:
		get_viewport().gui_release_focus()
		return

	# NOTE: If the focus root is queued for deletion, treat it as null to avoid
	# restricting the fallback search to a dying subtree. This is intentionally
	# separate from the validity check above — `set_focus_root(null)` would
	# prematurely re-enable controls still under the dying root.
	var root := (
		_focus_root
		if _focus_root and not _focus_root.is_queued_for_deletion()
		else null
	)

	# NOTE: Only use _hovered if it's under the focus root (or there is no
	# root). This handles the case where a modal opens over a hovered element —
	# the element remains hovered but shouldn't receive focus (Godot bug).
	if _hovered and (not root or root.is_ancestor_of(_hovered)):
		# NOTE: Focus is grabbed at once, so the press which hid the cursor acts on it.
		_grab_focus(_hovered, trigger)
		unset_hovered(_hovered)
		return

	if _hovered:
		unset_hovered(_hovered)

	# Return to the control to restore, if still eligible.
	if (
		previous
		and is_instance_valid(previous)
		and previous.is_visible_in_tree()
		and (not root or root.is_ancestor_of(previous))
		and not (previous is BaseButton and previous.disabled)
	):
		_grab_focus_deferred(previous, trigger, true)
		return

	# Fall back to the highest-priority anchor, whose focus handler restores its focus
	# mode on the cursor visibility signal before the deferred grab runs.
	var anchor := StdInputCursorFocusHandler.get_focus_target(root)
	if anchor:
		_grab_focus_deferred(anchor, trigger, false)
	elif current_focus:
		current_focus.release_focus()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_confined_property_changed(_value: Variant = null) -> void:
	var confined := _resolve_confined()
	if confined == _cursor_confined:
		return

	_cursor_confined = confined
	_on_properties_changed(&"", false)


func _on_gui_focus_changed(control: Control) -> void:
	_logger.debug("GUI focus changed.", {&"path": control.get_path()})

	_deferred_focus = null

	control.focus_exited.connect(
		func(): _deferred_update_focus.call_deferred(_focus_version),
		CONNECT_ONE_SHOT,
	)


func _on_properties_changed(
	trigger: StringName = &"",
	should_emit: bool = true,
) -> void:
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

	# Release stale focus on hidden-to-visible transitions, remembering it so the next
	# hide can return to it.
	if _cursor_visible and not _was_cursor_visible:
		var focused := get_viewport().gui_get_focus_owner()
		_focus_to_restore = focused if focused else _deferred_focus
		get_viewport().gui_release_focus()
	_was_cursor_visible = _cursor_visible

	_update_focus(trigger)

	if should_emit:
		(
			_logger
			. debug(
				"Cursor visibility changed.",
				{&"trigger": trigger, &"visible": _cursor_visible},
			)
		)

		cursor_visibility_changed.emit(_cursor_visible)
