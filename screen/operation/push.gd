##
## screen/operation/push.gd
##
## Implements the push operation for the screen manager.
##

extends "operation.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Push := preload("push.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _instance: Node
var _screen: StdScreen
var _transition: StdScreenTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create constructs a push operation for the given screen.
static func create(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> RefCounted:
	var op = Push.new()
	op._screen = screen
	op._instance = instance
	op._transition = transition
	return op


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _execute(manager: StdScreenManager, done: Callable) -> void:
	# Validate: no duplicates in stack.
	if _screen in manager._stack:
		(
			_logger
			. warn(
				"Ignored; screen already in stack.",
				{&"op": &"push"},
			)
		)
		done.call()
		return

	var previous := manager._current_scene()
	var result: Array = manager._create_resolver(_screen, _instance)
	var resolver: Callable = result[0]
	var sync_scene: Node = result[1]

	manager._save_focus(previous)

	var transition := (
		manager
		. _resolve_transition(
			_screen,
			_transition,
			&"push",
		)
	)

	_run_transition(
		manager,
		transition,
		&"push",
		previous,
		sync_scene,
		func(scene: Node) -> void: manager._mount_scene(_screen, scene),
		Callable(),
		func() -> void:
			var scene: Node = manager._scenes.get(_screen)
			_emit_entered(manager, _screen, scene)
			_emit_covered(manager, previous)
			done.call(),
		resolver,
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _emit_covered emits the covered signal and notification on the previous scene.
func _emit_covered(manager: StdScreenManager, previous: Node) -> void:
	if not previous:
		return

	assert(
		manager._stack.size() >= 2,
		"invalid state; expected at least two screens",
	)

	var screen_prev: StdScreen = manager._stack[manager._stack.size() - 2]

	screen_prev.covered.emit(previous)
	manager.screen_covered.emit(screen_prev, previous)

	previous.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
