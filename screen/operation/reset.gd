##
## screen/operation/reset.gd
##
## Implements the reset operation for the screen manager. Tears down all screens and
## pushes a new base.
##

extends "operation.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Reset := preload("reset.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _instance: Node
var _screen: StdScreen
var _transition: StdScreenTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create constructs a reset operation.
static func create(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> RefCounted:
	var op = Reset.new()
	op._screen = screen
	op._instance = instance
	op._transition = transition
	return op


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _execute(manager: StdScreenManager, done: Callable) -> void:
	# Teardown all existing scenes in reverse order.
	for i in range(manager._stack.size() - 1, -1, -1):
		var s: StdScreen = manager._stack[i]
		var sc: Node = manager._scenes.get(s)
		if sc and is_instance_valid(sc):
			s.exiting.emit(sc)
			manager.screen_exiting.emit(s, sc)
			manager._teardown_scene(s, sc)
		s.popped.emit(null)

	manager._stack.clear()
	manager._scenes.clear()
	manager._focus.clear()
	manager._overlays.clear()
	manager._preloads.clear()

	var result: Array = manager._create_resolver(_screen, _instance)
	var resolver: Callable = result[0]
	var sync_scene: Node = result[1]

	var transition := manager._resolve_transition(_screen, _transition, &"push")

	_run_transition(
		manager,
		transition,
		&"push",
		null,
		sync_scene,
		func(scene: Node) -> void: manager._mount_scene(_screen, scene),
		Callable(),
		func() -> void:
			if _screen not in manager._stack:
				done.call()
				return
			var scene: Node = manager._scenes.get(_screen)
			_emit_entered(manager, _screen, scene)
			done.call(),
		resolver,
	)
