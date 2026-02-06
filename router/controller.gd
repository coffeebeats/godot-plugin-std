##
## router/controller.gd
##
## StdRouterController is a base class for orchestrating route transitions during
## navigation. The controller coordinates when scenes are added/removed and when
## enter/exit transitions run.
##

class_name StdRouterController
extends Resource

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- SIGNALS ------------------------------------------------------------------------- #

## completed is emitted when the route navigation sequence is complete.
signal completed

# -- INITIALIZATION ------------------------------------------------------------------ #

var _cancelled: bool = false
var _parent: Node
var _scene_exit: Node
var _scene_enter: Node
var _transition_exit: StdRouteTransition
var _transition_enter: StdRouteTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## cancel stops the controller without emitting completed; all in progress transitions
## will be canceled.
func cancel() -> void:
	_cancelled = true

	if _transition_exit:
		Signals.disconnect_safe(
			_transition_exit.completed, _on_exit_transition_completed
		)
	if _transition_enter:
		Signals.disconnect_safe(
			_transition_enter.completed, _on_enter_transition_completed
		)

	if _transition_exit:
		_transition_exit.cancel()
	if _transition_enter:
		_transition_enter.cancel()


## start begins the route navigation sequence. Subclasses customize behavior by
## overriding `_start` and transition completion handlers.
func start(
	parent: Node,
	scene_exit: Node,
	scene_enter: Node,
	transition_exit: StdRouteTransition,
	transition_enter: StdRouteTransition,
) -> void:
	_parent = parent
	_scene_exit = scene_exit
	_scene_enter = scene_enter
	_transition_exit = transition_exit
	_transition_enter = transition_enter

	if _transition_exit:
		_transition_exit.completed.connect(
			_on_exit_transition_completed, CONNECT_ONE_SHOT
		)
	if _transition_enter:
		_transition_enter.completed.connect(
			_on_enter_transition_completed, CONNECT_ONE_SHOT
		)

	_start()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _start is the virtual entry point for subclasses. Override to customize behavior. The
## base implementation completes immediately without any transitions.
func _start() -> void:
	_done()


## _on_exit_transition_completed is called when exit transition finishes. Override to
## customize post-exit behavior.
func _on_exit_transition_completed() -> void:
	pass


## _on_enter_transition_completed is called when enter transition finishes. Override to
## customize post-enter behavior.
func _on_enter_transition_completed() -> void:
	pass


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _done signals that the controller has finished. Subclasses MUST call this when done.
func _done() -> void:
	if _cancelled:
		return

	completed.emit()


## _mount_scene adds the entering scene to the parent.
func _mount_scene() -> void:
	if _scene_enter and _parent:
		_parent.add_child(_scene_enter)


## _run_exit_transition starts the exit transition. Returns true if transition started.
func _run_exit_transition() -> bool:
	if _scene_exit and _transition_exit:
		_transition_exit.start(_scene_exit, false)
		return true

	return false


## _run_enter_transition starts the enter transition. Returns true if transition
## started.
func _run_enter_transition() -> bool:
	if _scene_enter and _transition_enter:
		_transition_enter.start(_scene_enter, true)
		return true

	return false


## _unmount_scene removes the exiting scene from the tree.
func _unmount_scene() -> void:
	if _scene_exit:
		_scene_exit.queue_free()
