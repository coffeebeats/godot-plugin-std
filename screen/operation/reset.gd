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

	manager._stack.clear()
	manager._scenes.clear()
	manager._focus.clear()
	manager._overlays.clear()
	manager._preloads.clear()

	_resolve_and_load(
		manager,
		_screen,
		_instance,
		_do_reset.bind(manager, done),
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _do_reset(
	scene: Node,
	manager: StdScreenManager,
	done: Callable,
) -> void:
	var transition := manager._resolve_transition(_screen, _transition, &"push")

	_run_transition(
		manager,
		transition,
		&"push",
		null,
		scene,
		func() -> void: manager._mount_scene(_screen, scene),
		Callable(),
		func() -> void:
			_emit_entered(manager, _screen, scene)
			done.call(),
	)
