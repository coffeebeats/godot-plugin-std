##
## screen/operation/operation.gd
##
## Base class for screen manager operations. Each operation encapsulates the logic for a
## single navigation action (e.g. push, pop, replace, or reset), in two steps the
## manager runs in turn, `_prepare` naming the loads it needs and `_present` changing
## the stack once they have ended.
##

extends RefCounted

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Preparation := preload("../manager/preparation.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

@warning_ignore("unused_private_class_variable")
static var _logger := StdLogger.create(&"std/screen/operation")  # gdlint:ignore=class-definitions-order,max-line-length

## _preparation is the preparation `_prepare` returned, which `_present` mounts from.
var _preparation: Preparation = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_screen returns the screen the operation opens, or null if it opens none.
func get_screen() -> StdScreen:
	return null


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _discard releases what the operation holds when the manager drops it unrun, as a
## teardown does.
##
## NOTE: Subclasses which take a scene instance override this to free it.
func _discard(_manager: StdScreenManager) -> void:
	pass


## _prepare validates the operation and returns the preparation it needs before it can
## present, or null if it needs none. It changes nothing on the stack.
##
## NOTE: Subclasses which open a screen override this.
func _prepare(_manager: StdScreenManager) -> Preparation:
	return null


## _present runs the operation once its preparation has ended.
##
## NOTE: Subclasses *must* override this to implement the operation logic, and call
## `_done` when the operation finishes.
func _present(_manager: StdScreenManager, _done: Callable) -> void:
	_done.call()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _emit_entered emits the entered signal for the given scene. If the scene is null
## (failed load), this is a no-op.
func _emit_entered(
	manager: StdScreenManager,
	screen: StdScreen,
	scene: Node,
) -> void:
	if scene == null:
		return

	screen.entered.emit(scene)
	manager.screen_entered.emit(screen, scene)


## _fail_unloaded reports, and completes the operation with the stack as it was, if the
## screen it opens couldn't load. It returns whether it did.
func _fail_unloaded(manager: StdScreenManager, done: Callable) -> bool:
	if _preparation == null or _preparation.get_error() == OK:
		return false

	manager._report_unloaded(get_screen())
	done.call()

	return true


## _finish_transition completes the running transition at once, as when a later call
## arrives before it ends. The transition clears what it animated, the change it hadn't
## made yet runs, and the operation finishes with its signals.
static func _finish_transition(
	transition: StdTransition, context: StdTransitionContext
) -> void:
	transition._stop()
	transition._context = null

	# NOTE: Each step is a no-op once made or when the operation has nothing to change,
	# so this unmounts what an exit or swap hadn't, then mounts what an enter or swap
	# hadn't.
	context.swap()
	context.done()


## _prepare_screen returns the preparation for opening `screen`, with `instance` if one
## was passed, its loads requested urgently.
func _prepare_screen(
	manager: StdScreenManager, screen: StdScreen, instance: Node
) -> Preparation:
	_preparation = manager._prepare_screen(screen, instance, true)
	return _preparation


## _run_transition sets up and dispatches a transition for the given operation method.
## When `transition` is null, a bare `StdTransition` is used so that the default instant
## mount/unmount/swap behavior is applied without input-blocker overhead.
func _run_transition(
	manager: StdScreenManager,
	transition: StdTransition,
	method: StringName,
	current_scene: Node,
	entering: Node,
	mount_fn: Callable,
	unmount_fn: Callable,
	on_done: Callable,
	resolver: Callable = Callable(),
) -> void:
	if transition == null:
		transition = StdTransition.new()
		transition.block_input = false

	var tx := transition.duplicate()

	var ctx := StdScreenTransitionContext.new(manager)
	ctx.current_scene = current_scene
	ctx.entering = entering
	ctx.exiting = null if method == &"enter" else current_scene
	ctx._mount_fn = mount_fn
	ctx._resolver = resolver
	ctx._unmount_fn = unmount_fn

	ctx.finished.connect(
		func() -> void:
			if manager._active_context == ctx:
				manager._active_transition = null
				manager._active_context = null

			if manager._cursor and manager._cursor.get_is_visible():
				manager._force_hover_recalculation.call_deferred()

			on_done.call(),
		CONNECT_ONE_SHOT,
	)

	manager._active_transition = tx
	manager._active_context = ctx

	match method:
		&"enter":
			tx.enter(ctx)
		&"exit":
			tx.exit(ctx)
		&"swap":
			tx.swap(ctx)
