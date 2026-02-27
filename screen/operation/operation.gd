##
## screen/operation/operation.gd
##
## Base class for screen manager operations. Each operation encapsulates the logic for a
## single navigation action (e.g. push, pop, replace, or reset).
##

extends RefCounted

# -- INITIALIZATION ------------------------------------------------------------------ #

@warning_ignore("unused_private_class_variable")
static var _logger := StdLogger.create(&"std/screen/operation")  # gdlint:ignore=class-definitions-order,max-line-length

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## execute runs the operation.
##
## NOTE: Subclasses *must* override this to implement the operation logic. Additionally,
## the provided `done` callback when the operation finishes.
func _execute(_manager: StdScreenManager, _done: Callable) -> void:
	_done.call()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _emit_entered emits the entered signal and restores focus on the given scene.
func _emit_entered(
	manager: StdScreenManager,
	screen: StdScreen,
	scene: Node,
) -> void:
	screen.entered.emit(scene)
	manager.screen_entered.emit(screen, scene)
	manager._restore_focus(scene)


## _run_transition sets up and dispatches a transition for the given operation method.
## When `transition` is null, a bare `StdScreenTransition` is used so that the default
## instant mount/unmount/swap behavior is applied without input-blocker overhead.
func _run_transition(
	manager: StdScreenManager,
	transition: StdScreenTransition,
	method: StringName,
	current_scene: Node,
	entering_scene: Node,
	mount_fn: Callable,
	unmount_fn: Callable,
	on_done: Callable,
	resolver: Callable = Callable(),
) -> void:
	if transition == null:
		transition = StdScreenTransition.new()
		transition.block_input = false

	var tx := transition.duplicate()

	var ctx := StdScreenTransitionContext.new(manager)
	ctx.current_scene = current_scene
	ctx.entering_scene = entering_scene
	ctx._mount_fn = mount_fn
	ctx._resolver = resolver
	ctx._unmount_fn = unmount_fn

	ctx.finished.connect(
		func() -> void:
			manager._active_transition = null
			manager._active_context = null

			if transition.block_input:
				manager._unblock_input()

			on_done.call(),
		CONNECT_ONE_SHOT,
	)

	if transition.block_input:
		manager._block_input()

	manager._active_transition = tx
	manager._active_context = ctx

	match method:
		&"push":
			tx.push(ctx)
		&"pop":
			tx.pop(ctx)
		&"replace":
			tx.replace(ctx)
