##
## screen/operation/operation.gd
##
## Base class for screen manager operations. Each operation encapsulates the logic for a
## single navigation action (e.g. push, pop, replace, or reset).
##

extends RefCounted

# -- INITIALIZATION ------------------------------------------------------------------ #

@warning_ignore("unused_private_class_variable")
static var _logger := StdLogger.create(&"std/screen/operation") # gdlint:ignore=class-definitions-order,max-line-length

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## execute runs the operation.
##
## NOTE: Subclasses *must* override this to implement the operation logic. Additionally,
## the provided `done` callback when the operation finishes.
func _execute(_manager: StdScreenManager, _done: Callable) -> void:
	_done.call()


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
