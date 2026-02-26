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

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create constructs a reset operation.
static func create(screen: StdScreen, instance: Node = null) -> RefCounted:
	var op = Reset.new()
	op._screen = screen
	op._instance = instance
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

	# Resolve the new base scene.
	var scene: Node = await (manager._resolve_scene(_screen, _instance))

	# Load preload dependencies.
	await manager._resolve_preloads(_screen)

	manager._mount_scene(_screen, scene)

	_screen.entered.emit(scene)
	manager.screen_entered.emit(_screen, scene)
	manager._restore_focus(scene)

	done.call()
