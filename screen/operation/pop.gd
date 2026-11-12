##
## screen/operation/pop.gd
##
## Implements the pop and pop_to operations for the screen manager.
##

extends "operation.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Pop := preload("pop.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _depth: int
var _result: Variant

## _screens are the screens the pop removes, bottom first, or empty if it pops to
## the screen `_target`.
var _screens: Array[StdScreen] = []

## _target is the screen the pop leaves on top, or null if it pops `_screens`.
var _target: StdScreen

var _transition: StdTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create_to constructs a pop operation that removes every screen above `target`. It
## removes nothing unless `target` is still in the stack when it presents.
static func create_to(
	target: StdScreen,
	transition: StdTransition = null,
	result: Variant = null,
) -> RefCounted:
	assert(target != null, "invalid argument: missing target")

	var op = Pop.new()
	op._result = result
	op._target = target
	op._transition = transition
	return op


## create_top constructs a pop operation that removes `screens`, bottom first, the
## topmost screens when it was called. It removes nothing unless they are still the
## topmost screens when it presents.
static func create_top(
	screens: Array[StdScreen],
	transition: StdTransition = null,
	result: Variant = null,
) -> RefCounted:
	assert(not screens.is_empty(), "invalid argument: missing screens")

	var op = Pop.new()
	op._result = result
	op._screens = screens
	op._transition = transition
	return op


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _present(manager: StdScreenManager, done: Callable) -> void:
	# NOTE: The manager has completed any operation whose transition was running, so no
	# screen is leaving, but one may have mounted above the screens asked, or they may
	# have left, since the pop was called.
	if _target != null:
		var idx := manager._stack.find(_target)
		if idx < 0:
			_logger.debug("Ignored; screen no longer in stack.", {&"op": &"pop"})
			done.call()
			return

		_depth = idx + 1

	if not _screens.is_empty():
		var depth := manager._stack.size() - _screens.size()
		if depth < 1 or manager._stack.slice(depth) != _screens:
			_logger.debug("Ignored; screen no longer on top.", {&"op": &"pop"})
			done.call()
			return

		_depth = depth

	# Pop intermediate screens instantly (no transition - industry standard).
	while manager._stack.size() > _depth + 1:
		@warning_ignore("confusable_local_declaration")
		var screen: StdScreen = manager._stack[-1]
		@warning_ignore("confusable_local_declaration")
		var scene: Node = manager._scenes.get(screen)

		if scene == null:
			manager._discard_screen(screen)
			continue

		screen.exiting.emit(scene)
		manager.screen_exiting.emit(screen, scene)
		manager._unmount_scene(screen, scene)
		screen.popped.emit(null)

	if manager._stack.size() <= _depth:
		done.call()
		return

	# Pop the last screen with optional transition.
	var screen: StdScreen = manager._stack[-1]
	var scene: Node = manager._scenes.get(screen)

	if scene == null:
		manager._discard_screen(screen)
		manager._update_stack_state()
		done.call()
		return

	screen.exiting.emit(scene)
	manager.screen_exiting.emit(screen, scene)
	manager._play_screen_sound(screen.sound_exit)

	var transition := manager._resolve_transition(screen, _transition, &"pop")
	var result: Variant = _result

	_run_transition(
		manager,
		transition,
		&"exit",
		scene,
		null,
		Callable(),
		func() -> void:
			manager._unmount_scene(screen, scene)
			screen.popped.emit(result),
		done,
	)
