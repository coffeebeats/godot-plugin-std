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
var _transition: StdTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create constructs a push operation for the given screen.
static func create(
	screen: StdScreen,
	instance: Node = null,
	transition: StdTransition = null,
) -> RefCounted:
	var op = Push.new()
	op._screen = screen
	op._instance = instance
	op._transition = transition
	return op


func get_screen() -> StdScreen:
	return _screen


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _discard(manager: StdScreenManager) -> void:
	manager._free_unowned(_instance)


func _prepare(manager: StdScreenManager) -> Preparation:
	if _screen in manager._stack:
		return null

	return _prepare_screen(manager, _screen, _instance)


func _present(manager: StdScreenManager, done: Callable) -> void:
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

	if _fail_unloaded(manager, done):
		return

	var previous := manager._current_scene()
	var result: Array = manager._create_resolver(_screen, _instance, _preparation)
	var resolver: Callable = result[0]
	var sync_scene: Node = result[1]

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
		&"enter",
		previous,
		sync_scene,
		func(scene: Node) -> void:
			manager._mount_entering(_screen, scene, _preparation),
		Callable(),
		func() -> void:
			if _screen not in manager._stack:
				done.call()
				return
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
	for node: Node in manager._attachments.get(screen_prev, []):
		node.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
