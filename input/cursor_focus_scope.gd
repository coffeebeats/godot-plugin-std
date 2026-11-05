##
## std/input/cursor_focus_scope.gd
##
## StdInputCursorFocusScope is a node which confines focus to the `Control` at `control`
## by claiming it with the `StdInputCursor` while active. It's active while the control
## is visible in the tree, every `StdPanel` owning it or an ancestor is opening or open,
## and no screen covers it.
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

var _claimed: bool = false
var _control: Control = null

## _covered is whether another screen covers the one holding this scope.
var _covered: bool = false

var _cursor: StdInputCursor = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	# NOTE: On a later entry, the panel owning the control may enter after this node.
	if is_node_ready():
		_sync.call_deferred()


func _exit_tree() -> void:
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
	else:
		_cursor.release_focus(_control)
