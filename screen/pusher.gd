##
## screen/pusher.gd
##
## StdScreenPusher is a node that pushes and pops a `StdScreen` in response to input
## actions.
##
## A pusher tracks where its target screen sits in the stack, but only receives input
## while its host overlay is topmost: a screen pushed above it with `block_input_below`
## consumes unhandled input first. Which actions are bound is still the action set's
## job; loading one rebinds the whole `InputMap`, so an action the current screen omits
## reaches no pusher.
##
## A pusher must be able to find a `StdScreenManager` among its ancestors (or via
## 'manager_path'). Declare it as an attachment of the screen it should be active during
## (`StdScreen.attachment_scenes`). Placed directly in the manager's subtree it precedes
## every overlay, so it is starved of input whenever two or more overlays exist.
##
## When no manager is found the pusher disables itself, logging a warning; it wires
## itself up again on any later tree entry which does find one. This keeps a scene
## containing a pusher runnable on its own, without push/pop behavior.
##

class_name StdScreenPusher
extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## screen is the screen resource to push and pop.
@export var screen: StdScreen

## manager_path is an optional path to the `StdScreenManager`. When empty, the manager
## is discovered by walking ancestors.
@export var manager_path: NodePath = NodePath()

@export_group("Actions")

## push_actions are input actions that push the screen when it is not in the stack.
@export var push_actions: Array[StringName] = []

## pop_actions are input actions that pop the screen when it is the topmost screen.
##
## NOTE: Prefer `StdScreen.close_actions`, which needs no pusher scene and no placement.
## This remains for compatibility, and for screens that must close while the scene tree
## is paused, where the overlay does not process input but this node does.
@export var pop_actions: Array[StringName] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/screen/pusher")  # gdlint:ignore=class-definitions-order,max-line-length

var manager: StdScreenManager = null

var _is_current: bool = false
var _is_in_stack: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


# NOTE: Always-process so push/pop input still works while the scene tree is paused.
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	assert(screen != null, "invalid config; missing 'screen'")

	manager = _find_manager()
	if manager == null:
		_logger.warn("No screen manager found; pusher disabled.", {&"path": get_path()})

		_is_in_stack = false
		_is_current = false

		return

	Signals.connect_safe(screen.entering, _on_entering)
	Signals.connect_safe(screen.exited, _on_exited)
	Signals.connect_safe(screen.covered, _on_covered)
	Signals.connect_safe(screen.uncovered, _on_uncovered)

	for action in push_actions:
		if not InputMap.has_action(action):
			_logger.warn("Action not in InputMap.", {&"action": action})
	assert(push_actions.all(InputMap.has_action), "invalid state; missing actions")

	for action in pop_actions:
		if not InputMap.has_action(action):
			_logger.warn("Action not in InputMap.", {&"action": action})
	assert(pop_actions.all(InputMap.has_action), "invalid state; missing actions")

	_is_in_stack = false
	for i in range(manager.get_depth()):
		if manager.get_at(i) == screen:
			_is_in_stack = true
			break
	_is_current = manager.get_current_screen() == screen


func _exit_tree() -> void:
	assert(screen != null, "invalid config; missing 'screen'")

	Signals.disconnect_safe(screen.entering, _on_entering)
	Signals.disconnect_safe(screen.exited, _on_exited)
	Signals.disconnect_safe(screen.covered, _on_covered)
	Signals.disconnect_safe(screen.uncovered, _on_uncovered)


func _unhandled_input(event: InputEvent) -> void:
	# NOTE: Guard here rather than disabling input processing in `_enter_tree`;
	# `NOTIFICATION_READY` re-enables unhandled input for any script defining
	# `_unhandled_input`, which would undo `set_process_unhandled_input(false)`.
	if manager == null:
		return

	if not _is_in_stack:
		for action in push_actions:
			if event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				manager.push(screen)
				return

	if _is_current:
		for action in pop_actions:
			if event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				manager.pop()
				return


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _find_manager() -> StdScreenManager:
	if not manager_path.is_empty():
		return get_node_or_null(manager_path) as StdScreenManager

	var node := get_parent()
	while node:
		if node is StdScreenManager:
			return node
		node = node.get_parent()

	return null


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_covered(_scene: Node) -> void:
	_is_current = false


func _on_entering(_scene: Node) -> void:
	_is_in_stack = true
	_is_current = true


func _on_exited(_scene: Node) -> void:
	_is_in_stack = false
	_is_current = false


func _on_uncovered(_scene: Node) -> void:
	_is_current = true
