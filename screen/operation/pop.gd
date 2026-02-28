##
## screen/operation/pop.gd
##
## Implements the pop, pop_to, and pop_to_depth operations for the screen manager.
##

extends "operation.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Pop := preload("pop.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _depth: int
var _result: Variant
var _transition: StdScreenTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create constructs a pop operation to the given target depth.
static func create(
	depth: int,
	transition: StdScreenTransition = null,
	result: Variant = null,
) -> RefCounted:
	var op = Pop.new()
	op._depth = depth
	op._result = result
	op._transition = transition
	return op


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _execute(manager: StdScreenManager, done: Callable) -> void:
	# Pop intermediate screens instantly (no transition - industry standard).
	while manager._stack.size() > _depth + 1:
		@warning_ignore("confusable_local_declaration")
		var screen: StdScreen = manager._stack[-1]
		@warning_ignore("confusable_local_declaration")
		var scene: Node = manager._scenes[screen]

		screen.exiting.emit(scene)
		manager.screen_exiting.emit(screen, scene)
		manager._unmount_scene(screen, scene)
		screen.popped.emit(null)

	if manager._stack.size() <= _depth:
		done.call()
		return

	# Pop the last screen with optional transition.
	var screen: StdScreen = manager._stack[-1]
	var scene: Node = manager._scenes[screen]

	screen.exiting.emit(scene)
	manager.screen_exiting.emit(screen, scene)

	var transition := manager._resolve_transition(screen, _transition, &"pop")
	var result: Variant = _result

	_run_transition(
		manager,
		transition,
		&"pop",
		scene,
		null,
		Callable(),
		func() -> void:
			manager._unmount_scene(screen, scene)
			screen.popped.emit(result),
		done,
	)
