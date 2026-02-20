##
## screen/pusher.gd
##
## StdScreenPusher is a node that pushes and pops a `StdScreen` in response to input
## actions.
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
@export var pop_actions: Array[StringName] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/screen/pusher")  # gdlint:ignore=class-definitions-order,max-line-length

var manager: StdScreenManager = null

var _is_current: bool = false
var _is_in_stack: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	assert(screen != null, "invalid config; missing 'screen'")

	Signals.disconnect_safe(screen.entering, _on_entering)
	Signals.disconnect_safe(screen.exited, _on_exited)
	Signals.disconnect_safe(screen.covered, _on_covered)
	Signals.disconnect_safe(screen.uncovered, _on_uncovered)


func _ready() -> void:
	assert(screen != null, "invalid config; missing 'screen'")

	manager = _find_manager()
	assert(manager is StdScreenManager, "invalid config; missing manager")

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

	_is_in_stack = manager.get_index_of(screen) >= 0
	_is_current = manager.is_current(screen)


func _unhandled_input(event: InputEvent) -> void:
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
		return get_node_or_null(manager_path)

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
