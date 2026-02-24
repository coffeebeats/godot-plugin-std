##
## screen/manager/controller.gd
##
## Manages transition lifecycle for the screen manager. Tracks the active transition and
## handles interruption via stop_all.
##

extends RefCounted

# -- INITIALIZATION ------------------------------------------------------------------ #

## _active_context is the context for the current in-flight transition.
var _active_context: StdScreenTransitionContext = null

## _active_transition is the current in-flight transition (duplicated from the resource).
var _active_transition: StdScreenTransition = null

## _cancel_cleanup is a callable that runs when the transition is stopped, ensuring
## the stack reaches a consistent state (e.g. performing pending mount/unmount).
var _cancel_cleanup: Callable = Callable()

## _manager is the Node used to create StdScreenTransitionContext instances.
var _manager: Node

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(manager: Node) -> void:
	_manager = manager


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## clear resets all tracked state without stopping or cleaning up the active transition.
## Called by `_on_done` callbacks after the transition has already completed.
func clear() -> void:
	_active_transition = null
	_active_context = null
	_cancel_cleanup = Callable()


## run starts a transition with the given context. The transition is duplicated to avoid
## mutating the original resource.
func run(
	transition: StdScreenTransition,
	context: StdScreenTransitionContext,
	is_enter: bool,
	cancel_cleanup: Callable = Callable(),
) -> void:
	var tx := transition.duplicate()
	_active_transition = tx
	_active_context = context
	_cancel_cleanup = cancel_cleanup

	if is_enter:
		tx.enter(context)
	else:
		tx.exit(context)


## stop_all stops the in-flight transition. When `force_reset` is true, the transition
## is always reset and `cancel_cleanup` is skipped (the caller handles all teardowns).
func stop_all(force_reset: bool = false) -> void:
	if _active_transition == null:
		return

	var transition := _active_transition
	var context := _active_context
	var cleanup := _cancel_cleanup

	# Clear state before calling stop/reset to prevent reentrant issues.
	_active_transition = null
	_active_context = null
	_cancel_cleanup = Callable()

	# Clear callbacks to prevent stale invocations after stop/reset. Invalidating
	# _mount_fn also prevents deferred mounts when a scene finishes loading after
	# the transition has been abandoned (the _resolve_scene_then callback checks
	# this before setting entering_scene).
	if context:
		context._on_done = Callable()
		context._mount_fn = Callable()
		context._remove_blocker()

	if force_reset or transition.reset_on_interrupt:
		transition.reset()
	else:
		transition.stop()

	# Free entering scenes that were never mounted (prevents orphan on
	# teardown/reset when cancel_cleanup is skipped).
	if (
		force_reset
		and context
		and not context._did_mount
		and is_instance_valid(context.entering_scene)
	):
		context.entering_scene.queue_free()

	# Run cancel_cleanup to ensure stack consistency (unless force-resetting, where
	# the caller handles all teardowns itself).
	if not force_reset and cleanup.is_valid():
		cleanup.call()
