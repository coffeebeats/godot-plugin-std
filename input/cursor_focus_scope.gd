##
## std/input/cursor_focus_scope.gd
##
## StdInputCursorFocusScope is a node which confines focus to the `Control` at `control`
## by claiming it with the `StdInputCursor` while active. It's active while the control
## is visible in the tree, every `StdPanel` owning it or an ancestor is opening or open,
## and no screen covers it. A control holding a focus handler must hold an anchor, so
## focus has somewhere to land when the cursor hides.
##
## NOTE: Godot's neighbour search reaches every focusable control in the viewport, so
## without a scope a panel over a running scene lets focus leave it for what's behind.
##

class_name StdInputCursorFocusScope
extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## control is a path to the `Control` node to confine focus to.
@export var control: NodePath = NodePath("..")

## priority orders this scope's claim against the others which share its parent claim;
## see `StdInputCursor.claim_focus`.
@export var priority: int = 0

# -- INITIALIZATION ------------------------------------------------------------------ #

# gdlint:ignore=class-definitions-order
static var _logger := StdLogger.create("std/input/cursor_focus_scope")

## _scopes holds every scope in the tree, so a scope can find those nested in it.
static var _scopes: Array[StdInputCursorFocusScope] = []  # gdlint:ignore=class-definitions-order,max-line-length

var _claimed: bool = false
var _control: Control = null

## _covered is whether another screen covers the one holding this scope.
var _covered: bool = false

var _cursor: StdInputCursor = null

## _reported is whether the current claim's missing anchor was reported.
var _reported: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	_scopes.append(self)

	# NOTE: On a later entry, the panel owning the control may enter after this node.
	if is_node_ready():
		_sync.call_deferred()


func _exit_tree() -> void:
	_scopes.erase(self)

	if not _claimed:
		return

	_claimed = false

	# NOTE: At quit the cursor may be gone already, leaving no claim to release.
	if is_instance_valid(_cursor):
		_cursor.release_focus(_control)


func _notification(what: int) -> void:
	match what:
		StdScreenManager.NOTIFICATION_SCREEN_COVERED:
			_covered = true
			_sync()
		StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED:
			_covered = false
			_sync()
		StdPanel.NOTIFICATION_PANEL_PHASE_CHANGED:
			_sync()


func _ready() -> void:
	_control = get_node(control) as Control
	assert(_control is Control, "invalid config; missing control")

	_cursor = StdGroup.get_sole_member(StdInputCursor.GROUP_INPUT_CURSOR)
	assert(_cursor is StdInputCursor, "invalid state; missing input cursor")

	_control.visibility_changed.connect(_sync)
	_sync()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _check_anchor reports the control, once per claim, if it holds a focus handler but
## no anchor, which leaves focus nowhere to land when the cursor hides.
##
## NOTE: A handler counts only if its control is visible as the claim's frame ends and
## isn't under a nested scope's control, which confines focus to itself.
func _check_anchor() -> void:
	if _reported or not _claimed:
		return

	var nested := _scopes.filter(
		func(s: StdInputCursorFocusScope) -> bool:
			return is_instance_valid(s._control) and _control.is_ancestor_of(s._control)
	)

	var handled := false
	for node in _control.find_children("*", "", true, false):
		var handler := node as StdInputCursorFocusHandler
		if not handler:
			continue

		var target := handler.get_node_or_null(handler.control) as Control
		if not target or not target.is_visible_in_tree():
			continue

		var inner := nested.any(
			func(s: StdInputCursorFocusScope) -> bool:
				return s._control == target or s._control.is_ancestor_of(target)
		)
		if inner:
			continue

		if handler.use_as_anchor:
			return
		handled = true

	if not handled:
		return

	_reported = true
	_logger.warn(
		"Focus scope has no anchor to focus.", {&"control": _control.get_path()}
	)
	assert(false, "invalid config; missing focus anchor in: %s" % _control.get_path())


## _is_active returns whether the control should hold a claim.
func _is_active() -> bool:
	if not is_inside_tree() or _covered or not _control.is_visible_in_tree():
		return false

	return StdPanel.is_node_open(_control)


## _sync claims the control if this scope is active and releases it otherwise.
func _sync() -> void:
	# NOTE: Notifications can arrive before `_ready`, when there's nothing to claim yet.
	if not _cursor:
		return

	var active := _is_active()
	if active == _claimed:
		return

	_claimed = active
	if active:
		_cursor.claim_focus(_control, priority)

		# NOTE: Deferred, so an anchor set in the frame the scope claims still counts.
		_check_anchor.call_deferred()
	else:
		_reported = false
		_cursor.release_focus(_control)
